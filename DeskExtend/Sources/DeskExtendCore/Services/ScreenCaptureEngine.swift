import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import ImageIO
import UniformTypeIdentifiers
import AppKit

public final class ScreenCaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.deskextend.screencapture", qos: .userInteractive)
    private var onFrameCallback: (@Sendable (Data, NSImage?) -> Void)?
    private var isStreaming = false
    private var quality: Double = 0.75
    private var lastFrameTime: CFAbsoluteTime = 0
    private var minInterval: Double = 1.0 / 60.0

    public override init() {
        super.init()
    }

    public static func hasScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    public static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    public func startCapture(
        displayID: CGDirectDisplayID,
        fps: Int = 60,
        quality: Double = 0.75,
        onFrame: @escaping @Sendable (Data, NSImage?) -> Void
    ) async throws {
        stopCapture()

        self.quality = quality
        self.minInterval = 1.0 / Double(max(1, fps))
        self.onFrameCallback = onFrame
        self.isStreaming = true

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            print("[ScreenCaptureEngine] Permission or shareable content error: \(error.localizedDescription)")
            // Start fallback heartbeat generator if permission not granted
            startFallbackGenerator(displayID: displayID, fps: fps)
            return
        }

        // Find matching display
        guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            startFallbackGenerator(displayID: displayID, fps: fps)
            return
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
        try await scStream.startCapture()

        self.stream = scStream
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

    // SCStreamOutput protocol
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, isStreaming else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard (now - lastFrameTime) >= minInterval else { return }
        lastFrameTime = now

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

        let previewImage = NSImage(cgImage: cgImage, size: NSSize(width: width / 4, height: height / 4))
        onFrameCallback?(jpegData as Data, previewImage)
    }

    private func startFallbackGenerator(displayID: CGDirectDisplayID, fps: Int) {
        // Generates an informative placeholder frame when permission is needed
        Task.detached { [weak self] in
            let interval = UInt64(1_000_000_000 / Double(fps))
            while let self = self, self.isStreaming {
                let data = self.renderPlaceholderFrame()
                let preview = NSImage(data: data)
                self.onFrameCallback?(data, preview)
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func renderPlaceholderFrame() -> Data {
        let width = 1280
        let height = 720
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

        // Background gradient
        ctx.setFillColor(CGColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Grid lines
        ctx.setStrokeColor(CGColor(red: 0.15, green: 0.20, blue: 0.30, alpha: 0.5))
        ctx.setLineWidth(1)
        for x in stride(from: 0, to: width, by: 80) {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: height))
        }
        for y in stride(from: 0, to: height, by: 80) {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: width, y: y))
        }
        ctx.strokePath()

        let cgImage = ctx.makeImage()!
        let jpgData = NSMutableData()
        let dest = CGImageDestinationCreateWithData(jpgData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
        return jpgData as Data
    }
}
