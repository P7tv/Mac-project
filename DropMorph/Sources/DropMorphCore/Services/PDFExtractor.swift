import Foundation
import AppKit
import PDFKit
import CoreGraphics
import UniformTypeIdentifiers

public enum PDFExtractorError: LocalizedError {
    case invalidPDFDocument
    case noPagesFound
    case pageRenderFailed(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidPDFDocument:
            return "Unable to open PDF document."
        case .noPagesFound:
            return "PDF document has no pages."
        case .pageRenderFailed(let page):
            return "Failed to render page \(page) to image."
        }
    }
}

public struct PDFExtractor: Sendable {
    public static func extractPages(
        pdfURL: URL,
        format: OutputFormat = .png,
        outputDirectory: URL? = nil
    ) throws -> [URL] {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw PDFExtractorError.invalidPDFDocument
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw PDFExtractorError.noPagesFound
        }

        let baseDir = outputDirectory ?? pdfURL.deletingLastPathComponent()
        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        var exportedURLs: [URL] = []

        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0 // High DPI (Retina 2x)
            let pixelWidth = Int(pageRect.width * scale)
            let pixelHeight = Int(pageRect.height * scale)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

            // Fill white background
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

            context.scaleBy(x: scale, y: scale)

            // Draw PDF page into graphics context
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            page.draw(with: .mediaBox, to: context)
            NSGraphicsContext.restoreGraphicsState()

            guard let cgImage = context.makeImage() else {
                continue
            }

            let ext = format.fileExtension
            let pageURL = baseDir.appendingPathComponent("\(baseName)_page_\(i + 1).\(ext)")
            try? FileManager.default.removeItem(at: pageURL)

            guard let destination = CGImageDestinationCreateWithURL(
                pageURL as CFURL,
                format.utType.identifier as CFString,
                1,
                nil
            ) else {
                continue
            }

            CGImageDestinationAddImage(destination, cgImage, nil)
            if CGImageDestinationFinalize(destination) {
                exportedURLs.append(pageURL)
            }
        }

        guard !exportedURLs.isEmpty else {
            throw PDFExtractorError.pageRenderFailed(1)
        }

        return exportedURLs
    }
}
