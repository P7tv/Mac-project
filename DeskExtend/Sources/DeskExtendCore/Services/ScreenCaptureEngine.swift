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
        config.queueDepth = 3

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
    }

    public func updateQuality(_ quality: Double) {
        queue.async { [weak self] in
            self?.quality = min(0.95, max(0.4, quality))
        }
    }

    // SCStreamOutput protocol
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard self.stream === stream else { return }
        stopCapture()
        onCaptureError?(error)
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, isStreaming, self.stream === stream,
              sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue else { return }
        // ScreenCaptureKit already enforces minimumFrameInterval. A second
        // wall-clock limiter drops valid frames when callbacks arrive with jitter.

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
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
