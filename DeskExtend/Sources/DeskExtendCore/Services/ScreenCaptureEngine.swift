import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import ImageIO
import UniformTypeIdentifiers
import AppKit

public enum ScreenCaptureError: LocalizedError {
    case permissionRequired
    case displayUnavailable(CGDirectDisplayID)
    case invalidFrameRate

    public var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "กรุณาเปิดสิทธิ์ DeskExtend ใน System Settings → Privacy & Security → Screen & System Audio Recording แล้วปิดและเปิดแอปใหม่"
        case .displayUnavailable(let id):
            return "ไม่พบจอ DeskExtend (Display ID: \(id)) สำหรับจับภาพ กรุณาลองเริ่มใหม่"
        case .invalidFrameRate:
            return "Frame rate must be between 1 and 120 FPS."
        }
    }
}

public final class ScreenCaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.deskextend.screencapture", qos: .userInteractive)
    private var onFrameCallback: (@Sendable (Data, NSImage?) -> Void)?
    private var isStreaming = false
    private var quality: Double = 0.75
    private var lastPreviewTime: CFAbsoluteTime = 0
    private var activeDisplayID: CGDirectDisplayID?
    private var activeFPS: Int = 60
    private var isProcessingFrame = false
    private let processingLock = NSLock()
    private static let sharedColorSpace = CGColorSpaceCreateDeviceRGB()
    public var onCaptureError: (@Sendable (Error) -> Void)?

    public override init() {
        super.init()
    }

    public static func hasScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    public static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    public static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    public func startCapture(
        displayID: CGDirectDisplayID,
        fps: Int = 60,
        quality: Double = 0.75,
        onFrame: @escaping @Sendable (Data, NSImage?) -> Void
    ) async throws {
        stopCapture()

        guard (1...120).contains(fps) else { throw ScreenCaptureError.invalidFrameRate }
        guard Self.hasScreenRecordingPermission() else { throw ScreenCaptureError.permissionRequired }

        self.quality = quality
        self.lastPreviewTime = 0
        self.activeDisplayID = displayID
        self.activeFPS = fps

        var targetDisplay: SCDisplay?
        for attempt in 1...6 {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if let matched = content.displays.first(where: { $0.displayID == displayID }) {
                targetDisplay = matched
                print("[ScreenCaptureEngine] Matched virtual display ID: \(displayID) on attempt \(attempt)")
                break
            }
            if attempt < 6 { try await Task.sleep(nanoseconds: 200_000_000) }
        }

        guard let scDisplay = targetDisplay else {
            throw ScreenCaptureError.displayUnavailable(displayID)
        }

        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = scDisplay.width
        config.height = scDisplay.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(fps))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.queueDepth = 6

        let scStream = SCStream(filter: filter, configuration: config, delegate: self)
        try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        self.onFrameCallback = onFrame
        self.isStreaming = true
        self.stream = scStream
        do {
            try await scStream.startCapture()
        } catch {
            stopCapture()
            throw error
        }
        print("[ScreenCaptureEngine] ScreenCaptureKit started successfully on displayID: \(scDisplay.displayID)")
    }

    public func stopCapture() {
        isStreaming = false
        if let s = stream {
            s.stopCapture { _ in }
            self.stream = nil
        }
        onFrameCallback = nil
        processingLock.lock()
        isProcessingFrame = false
        processingLock.unlock()
    }

    public func updateQuality(_ quality: Double) {
        queue.async { [weak self] in
            self?.quality = min(0.95, max(0.4, quality))
        }
    }

    // SCStreamOutput protocol
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard self.stream === stream else { return }
        let nsError = error as NSError
        print("[ScreenCaptureEngine] Stream stopped with error: \(error.localizedDescription) (code: \(nsError.code))")

        // Seamless auto-recovery for recoverable system errors:
        // -3821: SCStreamError.systemStopped (daemon pressure or transient stop)
        // -3808: SCStreamError.streamAlreadyStopped
        // -3801: SCStreamError.userDeclined / transient display reconfiguration
        if isStreaming, let displayID = activeDisplayID, (nsError.code == -3821 || nsError.code == -3808 || nsError.code == -3801) {
            print("[ScreenCaptureEngine] Attempting seamless stream recovery in 300ms...")
            queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.isStreaming else { return }
                Task {
                    do {
                        try await self.restartCapture(displayID: displayID)
                        print("[ScreenCaptureEngine] Seamless stream recovery successful on displayID: \(displayID)!")
                    } catch {
                        print("[ScreenCaptureEngine] Stream recovery failed: \(error)")
                        self.stopCapture()
                        self.onCaptureError?(error)
                    }
                }
            }
            return
        }

        stopCapture()
        onCaptureError?(error)
    }

    private func restartCapture(displayID: CGDirectDisplayID) async throws {
        if let s = stream {
            try? await s.stopCapture()
            self.stream = nil
        }
        try await Task.sleep(nanoseconds: 150_000_000)
        guard isStreaming, let callback = onFrameCallback else { return }
        try await startCapture(
            displayID: displayID,
            fps: activeFPS,
            quality: quality,
            onFrame: callback
        )
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, isStreaming, self.stream === stream,
              sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue else { return }

        // Drop intermediate captured frames if previous frame is still encoding
        // to prevent ScreenCaptureKit queue saturation and -3821 daemon kill.
        processingLock.lock()
        if isProcessingFrame {
            processingLock.unlock()
            return
        }
        isProcessingFrame = true
        processingLock.unlock()

        defer {
            processingLock.lock()
            isProcessingFrame = false
            processingLock.unlock()
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }

        let colorSpace = Self.sharedColorSpace
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let cgImage = context.makeImage() else {
            return
        }

        // Compress to JPEG for high-speed network transmission
        let jpegData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(jpegData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return }

        let now = CFAbsoluteTimeGetCurrent()
        var previewImage: NSImage?
        if now - lastPreviewTime >= 0.2 {
            lastPreviewTime = now
            previewImage = NSImage(cgImage: cgImage, size: NSSize(width: width / 4, height: height / 4))
        }
        onFrameCallback?(jpegData as Data, previewImage)
    }
}
