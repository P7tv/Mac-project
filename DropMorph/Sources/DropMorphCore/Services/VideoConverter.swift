import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

public enum VideoConverterError: LocalizedError {
    case invalidVideoAsset
    case exportSessionCreationFailed
    case exportFailed(String)
    case noFramesExtracted

    public var errorDescription: String? {
        switch self {
        case .invalidVideoAsset:
            return "Unable to load video file."
        case .exportSessionCreationFailed:
            return "Unable to create audio export session."
        case .exportFailed(let reason):
            return "Video conversion failed: \(reason)"
        case .noFramesExtracted:
            return "Could not extract video frames."
        }
    }
}

public struct VideoConverter: Sendable {
    public static func convertToGIF(
        videoURL: URL,
        outputURL: URL,
        fps: Double = 10,
        maxDimension: CGFloat = 480
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let durationSeconds: Double
        do {
            let duration = try await asset.load(.duration)
            durationSeconds = CMTimeGetSeconds(duration)
        } catch {
            throw VideoConverterError.invalidVideoAsset
        }

        // Limit duration to max 30 seconds for GIF performance
        let effectiveDuration = min(durationSeconds, 30.0)
        let frameInterval = 1.0 / fps
        var times: [NSValue] = []

        var currentTime = 0.0
        while currentTime < effectiveDuration {
            let cmTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            times.append(NSValue(time: cmTime))
            currentTime += frameInterval
        }

        guard !times.isEmpty else {
            throw VideoConverterError.noFramesExtracted
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        var frames: [CGImage] = []
        for timeVal in times {
            let cmTime = timeVal.timeValue
            if let (image, _) = try? await generator.image(at: cmTime) {
                frames.append(image)
            }
        }

        guard !frames.isEmpty else {
            throw VideoConverterError.noFramesExtracted
        }

        let parentDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: outputURL)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw VideoConverterError.exportFailed("Cannot create GIF destination")
        }

        // Loop forever
        let fileProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        let frameProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameInterval
            ]
        ]

        for frame in frames {
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw VideoConverterError.exportFailed("GIF finalization failed")
        }

        return outputURL
    }

    public static func extractAudio(videoURL: URL, outputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw VideoConverterError.exportSessionCreationFailed
        }

        let parentDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: outputURL)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if let error = exportSession.error {
            throw VideoConverterError.exportFailed(error.localizedDescription)
        }

        guard exportSession.status == .completed else {
            throw VideoConverterError.exportFailed("Export finished with status \(exportSession.status.rawValue)")
        }

        return outputURL
    }

    public static func extractPosterFrame(videoURL: URL) async -> CGImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)
        return try? await generator.image(at: .zero).image
    }
}
