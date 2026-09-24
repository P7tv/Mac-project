import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

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

        // 2. If input is SVG vector, render via AppKit vector pipeline
        if inputURL.pathExtension.lowercased() == "svg",
           let nsImage = NSImage(contentsOf: inputURL) {
            let baseSize = nsImage.size
            let scale: CGFloat = 2.0
            let targetSize = CGSize(width: max(512, baseSize.width * scale), height: max(512, baseSize.height * scale))
            if let cgImage = renderSVGToCGImage(nsImage: nsImage, size: targetSize) {
                return try saveCGImage(cgImage: cgImage, inputURL: inputURL, sourceProperties: nil, settings: settings, targetOutputURL: targetOutputURL)
            }
        }

        // 3. Native ImageIO Conversion (JPEG, PNG, HEIC, TIFF, ICNS, ICO, Camera RAW: CR2/CR3/NEF/ARW/DNG/RAF/ORF)
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

        // Extract CGImage (with hardware downsampling if requested)
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

        return try saveCGImage(cgImage: cgImage, inputURL: inputURL, sourceProperties: sourceProperties, settings: settings, targetOutputURL: targetOutputURL)
    }

    private static func saveCGImage(
        cgImage: CGImage,
        inputURL: URL,
        sourceProperties: [CFString: Any]?,
        settings: ConversionSettings,
        targetOutputURL: URL?
    ) throws -> URL {
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

        var effectiveImage = cgImage
        var effectiveQuality: Double? = (settings.targetFormat == .jpeg || settings.targetFormat == .heic) ? settings.quality : nil

        if settings.mode == .targetSize {
            let optimized = optimizeForTargetSize(
                cgImage: cgImage,
                format: settings.targetFormat,
                targetBytes: settings.targetSizeBytes,
                stripMetadata: settings.stripMetadata,
                sourceProperties: sourceProperties
            )
            effectiveImage = optimized.image
            effectiveQuality = optimized.quality
        }

        var destinationProperties: [CFString: Any] = [:]
        if let q = effectiveQuality {
            destinationProperties[kCGImageDestinationLossyCompressionQuality] = q
        }

        if !settings.stripMetadata, let props = sourceProperties {
            if let exif = props[kCGImagePropertyExifDictionary] {
                destinationProperties[kCGImagePropertyExifDictionary] = exif
            }
            if let tiff = props[kCGImagePropertyTIFFDictionary] {
                destinationProperties[kCGImagePropertyTIFFDictionary] = tiff
            }
        }

        CGImageDestinationAddImage(destination, effectiveImage, destinationProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageConverterError.finalizeFailed(finalOutputURL)
        }

        return finalOutputURL
    }

    private static func resizeCGImage(_ image: CGImage, targetWidth: Int, targetHeight: Int) -> CGImage? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()
    }

    private static func encodeInMemory(
        cgImage: CGImage,
        format: OutputFormat,
        quality: Double?,
        stripMetadata: Bool,
        sourceProperties: [CFString: Any]?
    ) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, format.utType.identifier as CFString, 1, nil) else {
            return nil
        }
        var props: [CFString: Any] = [:]
        if let q = quality, (format == .jpeg || format == .heic) {
            props[kCGImageDestinationLossyCompressionQuality] = q
        }
        if !stripMetadata, let src = sourceProperties {
            if let exif = src[kCGImagePropertyExifDictionary] {
                props[kCGImagePropertyExifDictionary] = exif
            }
            if let tiff = src[kCGImagePropertyTIFFDictionary] {
                props[kCGImagePropertyTIFFDictionary] = tiff
            }
        }
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private static func optimizeForTargetSize(
        cgImage: CGImage,
        format: OutputFormat,
        targetBytes: Int64,
        stripMetadata: Bool,
        sourceProperties: [CFString: Any]?
    ) -> (image: CGImage, quality: Double?) {
        let isLossy = (format == .jpeg || format == .heic)

        if !isLossy {
            var current = cgImage
            var iterations = 0
            while iterations < 5 {
                guard let data = encodeInMemory(cgImage: current, format: format, quality: nil, stripMetadata: stripMetadata, sourceProperties: sourceProperties) else { break }
                if Int64(data.count) <= targetBytes { break }
                let ratio = sqrt(Double(targetBytes) / Double(data.count)) * 0.92
                let newW = max(16, Int(CGFloat(current.width) * CGFloat(ratio)))
                let newH = max(16, Int(CGFloat(current.height) * CGFloat(ratio)))
                guard let resized = resizeCGImage(current, targetWidth: newW, targetHeight: newH) else { break }
                current = resized
                iterations += 1
            }
            return (current, nil)
        }

        // Lossy format (JPEG, HEIC)
        // 1. Check if high quality (0.92) is already <= targetBytes
        if let highData = encodeInMemory(cgImage: cgImage, format: format, quality: 0.92, stripMetadata: stripMetadata, sourceProperties: sourceProperties),
           Int64(highData.count) <= targetBytes {
            return (cgImage, 0.92)
        }

        // 2. Binary search on quality in [0.05, 0.90]
        var low: Double = 0.05
        var high: Double = 0.90
        var bestQuality: Double = 0.05
        var fitsWithinTarget = false

        for _ in 0..<5 {
            let mid = (low + high) / 2.0
            if let data = encodeInMemory(cgImage: cgImage, format: format, quality: mid, stripMetadata: stripMetadata, sourceProperties: sourceProperties) {
                if Int64(data.count) <= targetBytes {
                    bestQuality = mid
                    fitsWithinTarget = true
                    low = mid + 0.01
                } else {
                    high = mid - 0.01
                }
            }
        }

        if fitsWithinTarget {
            return (cgImage, bestQuality)
        }

        // 3. Fallback: Even at lowest quality (0.05), file exceeds targetBytes. Downscale dimensions.
        var current = cgImage
        let currentQ = 0.65
        var iterations = 0
        while iterations < 4 {
            guard let data = encodeInMemory(cgImage: current, format: format, quality: currentQ, stripMetadata: stripMetadata, sourceProperties: sourceProperties) else { break }
            if Int64(data.count) <= targetBytes {
                return (current, currentQ)
            }
            let ratio = max(0.15, sqrt(Double(targetBytes) / Double(data.count)) * 0.90)
            let newW = max(16, Int(CGFloat(current.width) * CGFloat(ratio)))
            let newH = max(16, Int(CGFloat(current.height) * CGFloat(ratio)))
            guard let resized = resizeCGImage(current, targetWidth: newW, targetHeight: newH) else { break }
            current = resized
            iterations += 1
        }

        return (current, currentQ)
    }

    private static func renderSVGToCGImage(nsImage: NSImage, size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = Int(size.width)
        let height = Int(size.height)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        nsImage.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        return context.makeImage()
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

        // Step A: Prepare intermediate PNG
        var intermediateSettings = settings
        intermediateSettings.targetFormat = .png
        let tempPNGURL = parentDir.appendingPathComponent(".temp_\(UUID().uuidString).png")
        defer {
            try? FileManager.default.removeItem(at: tempPNGURL)
        }

        _ = try convert(inputURL: inputURL, settings: intermediateSettings, targetOutputURL: tempPNGURL)

        // Step B: Run cwebp
        var arguments: [String] = []
        if settings.mode == .targetSize {
            arguments = ["-size", "\(settings.targetSizeBytes)", tempPNGURL.path, "-o", finalOutputURL.path]
        } else {
            let qualityInt = max(1, min(100, Int(round(settings.quality * 100))))
            arguments = ["-q", "\(qualityInt)", tempPNGURL.path, "-o", finalOutputURL.path]
        }
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
