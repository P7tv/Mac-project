import Foundation
import AppKit
import PDFKit
import CoreGraphics
import UniformTypeIdentifiers

public enum PDFCompressorError: LocalizedError {
    case invalidPDFDocument
    case noPagesFound
    case compressionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPDFDocument:
            return "Unable to open PDF document for compression."
        case .noPagesFound:
            return "PDF document contains no pages."
        case .compressionFailed(let reason):
            return "PDF compression failed: \(reason)"
        }
    }
}

public struct PDFCompressor: Sendable {
    public static func compressPDF(
        inputURL: URL,
        settings: ConversionSettings,
        targetOutputURL: URL? = nil
    ) throws -> URL {
        guard let sourcePDF = PDFDocument(url: inputURL) else {
            throw PDFCompressorError.invalidPDFDocument
        }

        let pageCount = sourcePDF.pageCount
        guard pageCount > 0 else {
            throw PDFCompressorError.noPagesFound
        }

        let compressedPDF = PDFDocument()
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Determine resolution scale based on quality setting (default 1.5x - 2.0x for crisp screen reading)
        let scale: CGFloat
        if let userScale = settings.resizePreset.scaleFactor {
            scale = CGFloat(userScale) * 1.5
        } else {
            scale = 1.5
        }

        for i in 0..<pageCount {
            guard let page = sourcePDF.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let pixelWidth = max(100, Int(bounds.width * scale))
            let pixelHeight = max(100, Int(bounds.height * scale))

            guard let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                continue
            }

            // White background
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            context.scaleBy(x: scale, y: scale)

            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            page.draw(with: .mediaBox, to: context)
            NSGraphicsContext.restoreGraphicsState()

            guard let cgImage = context.makeImage() else { continue }

            // Re-compress page via JPEG lossy compression
            let jpgData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                jpgData as CFMutableData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                continue
            }

            let compressionQuality = max(0.2, min(1.0, settings.quality))
            let destinationProperties: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: compressionQuality
            ]
            CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { continue }

            if let compressedImage = NSImage(data: jpgData as Data),
               let newPage = PDFPage(image: compressedImage) {
                compressedPDF.insert(newPage, at: compressedPDF.pageCount)
            }
        }

        guard compressedPDF.pageCount > 0 else {
            throw PDFCompressorError.compressionFailed("Could not process any pages.")
        }

        let finalOutputURL: URL
        if let target = targetOutputURL {
            finalOutputURL = target
        } else {
            finalOutputURL = destinationURL(for: inputURL, customFolder: settings.customOutputFolder)
        }

        let parentDir = finalOutputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: finalOutputURL)

        guard compressedPDF.write(to: finalOutputURL) else {
            throw PDFCompressorError.compressionFailed("Failed to write compressed PDF to disk.")
        }

        return finalOutputURL
    }

    public static func destinationURL(for inputURL: URL, customFolder: URL? = nil) -> URL {
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
        var targetURL = baseDir.appendingPathComponent("\(baseName)_compressed.pdf")
        var counter = 1
        while FileManager.default.fileExists(atPath: targetURL.path) {
            targetURL = baseDir.appendingPathComponent("\(baseName)_compressed_\(counter).pdf")
            counter += 1
        }
        return targetURL
    }
}
