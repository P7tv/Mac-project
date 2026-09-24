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

        var scale: CGFloat
        var compressionQuality: Double

        if settings.mode == .targetSize {
            let perPageBudget = settings.targetSizeBytes / Int64(pageCount)
            if perPageBudget >= 250_000 {
                scale = 1.4
                compressionQuality = 0.75
            } else if perPageBudget >= 120_000 {
                scale = 1.0
                compressionQuality = 0.55
            } else if perPageBudget >= 60_000 {
                scale = 0.8
                compressionQuality = 0.40
            } else {
                scale = 0.55
                compressionQuality = 0.25
            }
        } else {
            if let userScale = settings.resizePreset.scaleFactor {
                scale = CGFloat(userScale) * 1.5
            } else {
                scale = 1.5
            }
            compressionQuality = max(0.2, min(1.0, settings.quality))
        }

        var compressedPDF = renderPages(sourcePDF: sourcePDF, pageCount: pageCount, scale: scale, quality: compressionQuality)

        // If in target size mode and result exceeds target, run a second fine-tuning pass
        if settings.mode == .targetSize,
           let data = compressedPDF.dataRepresentation(),
           Int64(data.count) > settings.targetSizeBytes {
            let ratio = max(0.3, sqrt(Double(settings.targetSizeBytes) / Double(data.count)) * 0.90)
            let adjustedScale = max(0.4, scale * CGFloat(ratio))
            let adjustedQuality = max(0.15, compressionQuality * ratio)
            compressedPDF = renderPages(sourcePDF: sourcePDF, pageCount: pageCount, scale: adjustedScale, quality: adjustedQuality)
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

    private static func renderPages(
        sourcePDF: PDFDocument,
        pageCount: Int,
        scale: CGFloat,
        quality: Double
    ) -> PDFDocument {
        let compressedPDF = PDFDocument()
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        for i in 0..<pageCount {
            guard let page = sourcePDF.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let pixelWidth = max(80, Int(bounds.width * scale))
            let pixelHeight = max(80, Int(bounds.height * scale))

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

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            context.scaleBy(x: scale, y: scale)

            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            page.draw(with: .mediaBox, to: context)
            NSGraphicsContext.restoreGraphicsState()

            guard let cgImage = context.makeImage() else { continue }

            let jpgData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                jpgData as CFMutableData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                continue
            }

            let destinationProperties: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: max(0.1, min(1.0, quality))
            ]
            CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { continue }

            if let compressedImage = NSImage(data: jpgData as Data),
               let newPage = PDFPage(image: compressedImage) {
                compressedPDF.insert(newPage, at: compressedPDF.pageCount)
            }
        }

        return compressedPDF
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
