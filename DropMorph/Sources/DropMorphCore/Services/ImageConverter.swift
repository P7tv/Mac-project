import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ImageConverterError: LocalizedError {
    case invalidSource(URL)
    case cannotCreateDestination(URL)
    case finalizeFailed(URL)
    case imageExtractionFailed
    case webpToolNotFound
    case externalProcessFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSource(let url):
            return "Unable to read image data from: \(url.lastPathComponent)"
        case .cannotCreateDestination(let url):
            return "Unable to create output file at: \(url.path)"
        case .finalizeFailed(let url):
            return "Failed to finalize image write to: \(url.lastPathComponent)"
        case .imageExtractionFailed:
            return "Failed to extract image frame from source"
        case .webpToolNotFound:
            return "WebP encoder (cwebp) not found. Please install via 'brew install webp' or choose HEIC/JPEG."
        case .externalProcessFailed(let msg):
            return "Conversion process failed: \(msg)"
        }
    }
}

public struct ImageConverter: Sendable {
    public static func convert(
        inputURL: URL,
        settings: ConversionSettings,
        targetOutputURL: URL? = nil
    ) throws -> URL {
        // 1. If WebP is requested and cwebp is available, handle via cwebp with an intermediate PNG
        if settings.targetFormat == .webp {
            return try convertToWebP(inputURL: inputURL, settings: settings, targetOutputURL: targetOutputURL)
        }

        // 2. Native ImageIO Conversion (JPEG, PNG, HEIC, TIFF, ICNS)
        guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw ImageConverterError.invalidSource(inputURL)
        }

        guard let sourceProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let originalWidth = sourceProperties[kCGImagePropertyPixelWidth] as? CGFloat,
              let originalHeight = sourceProperties[kCGImagePropertyPixelHeight] as? CGFloat else {
            throw ImageConverterError.imageExtractionFailed
        }

        // Calculate target dimensions
        var maxPixelDimension: CGFloat? = nil
        if let scale = settings.resizePreset.scaleFactor, scale < 1.0 {
            let maxDim = max(originalWidth, originalHeight) * CGFloat(scale)
            maxPixelDimension = max(16, maxDim)
        } else if let maxDim = settings.resizePreset.maxDimension {
            maxPixelDimension = min(max(originalWidth, originalHeight), maxDim)
        }

        // Extract CGImage (with downsampling if requested)
        let cgImage: CGImage
        if let maxDim = maxPixelDimension {
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxDim)
            ]
            guard let thumb = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) else {
                throw ImageConverterError.imageExtractionFailed
            }
            cgImage = thumb
        } else {
            guard let full = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw ImageConverterError.imageExtractionFailed
            }
            cgImage = full
        }

        // Output destination
        let finalOutputURL: URL
        if let target = targetOutputURL {
            finalOutputURL = target
        } else {
            finalOutputURL = destinationURL(for: inputURL, format: settings.targetFormat, customFolder: settings.customOutputFolder)
        }

        let parentDir = finalOutputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: finalOutputURL)

        guard let destination = CGImageDestinationCreateWithURL(
            finalOutputURL as CFURL,
            settings.targetFormat.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageConverterError.cannotCreateDestination(finalOutputURL)
        }

        var destinationProperties: [CFString: Any] = [:]
        if settings.targetFormat == .jpeg || settings.targetFormat == .heic {
            destinationProperties[kCGImageDestinationLossyCompressionQuality] = settings.quality
        }

        if !settings.stripMetadata {
            if let exif = sourceProperties[kCGImagePropertyExifDictionary] {
                destinationProperties[kCGImagePropertyExifDictionary] = exif
            }
            if let tiff = sourceProperties[kCGImagePropertyTIFFDictionary] {
                destinationProperties[kCGImagePropertyTIFFDictionary] = tiff
            }
        }

        CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageConverterError.finalizeFailed(finalOutputURL)
        }

        return finalOutputURL
    }

    private static func convertToWebP(
        inputURL: URL,
        settings: ConversionSettings,
        targetOutputURL: URL?
    ) throws -> URL {
        guard let cwebpBinary = findCwebpBinary() else {
            throw ImageConverterError.webpToolNotFound
        }

        let finalOutputURL: URL
        if let target = targetOutputURL {
            finalOutputURL = target
        } else {
            finalOutputURL = destinationURL(for: inputURL, format: .webp, customFolder: settings.customOutputFolder)
        }

        let parentDir = finalOutputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: finalOutputURL)

        // Step A: Prepare intermediate PNG with downsampling/resizing
        var intermediateSettings = settings
        intermediateSettings.targetFormat = .png
        let tempPNGURL = parentDir.appendingPathComponent(".temp_\(UUID().uuidString).png")
        defer {
            try? FileManager.default.removeItem(at: tempPNGURL)
        }

        _ = try convert(inputURL: inputURL, settings: intermediateSettings, targetOutputURL: tempPNGURL)

        // Step B: Run cwebp
        let qualityInt = max(1, min(100, Int(round(settings.quality * 100))))
        var arguments = ["-q", "\(qualityInt)", tempPNGURL.path, "-o", finalOutputURL.path]
        if settings.stripMetadata {
            arguments.append("-metadata")
            arguments.append("none")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cwebpBinary)
        process.arguments = arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? "cwebp exited with code \(process.terminationStatus)"
                throw ImageConverterError.externalProcessFailed(errStr)
            }
        } catch {
            throw ImageConverterError.externalProcessFailed(error.localizedDescription)
        }

        guard FileManager.default.fileExists(atPath: finalOutputURL.path) else {
            throw ImageConverterError.finalizeFailed(finalOutputURL)
        }

        return finalOutputURL
    }

    public static func findCwebpBinary() -> String? {
        let candidatePaths = [
            "/opt/homebrew/bin/cwebp",
            "/usr/local/bin/cwebp",
            "/Users/panpan/anaconda3/bin/cwebp",
            "/usr/bin/cwebp"
        ]
        for path in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try 'which cwebp'
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["cwebp"]
        let pipe = Pipe()
        process.standardOutput = pipe
        if (try? process.run()) != nil {
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty, FileManager.default.isExecutableFile(atPath: output) {
                    return output
                }
            }
        }
        return nil
    }

    public static func destinationURL(for inputURL: URL, format: OutputFormat, customFolder: URL? = nil) -> URL {
        let baseDir: URL
        if let custom = customFolder {
            baseDir = custom
        } else {
            let parent = inputURL.deletingLastPathComponent()
            if FileManager.default.isWritableFile(atPath: parent.path) {
                baseDir = parent
            } else {
                baseDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? parent
            }
        }

        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let targetExtension = format.fileExtension

        var targetURL = baseDir.appendingPathComponent("\(baseName)_converted.\(targetExtension)")
        var counter = 1
        while FileManager.default.fileExists(atPath: targetURL.path) {
            targetURL = baseDir.appendingPathComponent("\(baseName)_converted_\(counter).\(targetExtension)")
            counter += 1
        }
        return targetURL
    }
}
