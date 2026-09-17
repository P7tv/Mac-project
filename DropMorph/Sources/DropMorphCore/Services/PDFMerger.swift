import Foundation
import AppKit
import PDFKit
import CoreGraphics
import UniformTypeIdentifiers

public enum PDFMergerError: LocalizedError {
    case noValidImages
    case cannotWritePDF(URL)

    public var errorDescription: String? {
        switch self {
        case .noValidImages:
            return "No valid images could be loaded to generate the PDF."
        case .cannotWritePDF(let url):
            return "Failed to write PDF file to: \(url.path)"
        }
    }
}

public struct PDFMerger: Sendable {
    public static func mergeToPDF(
        imageURLs: [URL],
        outputURL: URL,
        quality: Double = 0.8
    ) throws -> URL {
        let pdfDocument = PDFDocument()
        var addedCount = 0

        for url in imageURLs {
            guard let nsImage = NSImage(contentsOf: url) else { continue }
            
            // Re-compress image to JPEG before embedding into PDF to prevent massive PDF file sizes
            if let tiffData = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: quality)]),
               let compressedImage = NSImage(data: jpegData),
               let pdfPage = PDFPage(image: compressedImage) {
                pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
                addedCount += 1
            } else if let pdfPage = PDFPage(image: nsImage) {
                pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
                addedCount += 1
            }
        }

        guard addedCount > 0 else {
            throw PDFMergerError.noValidImages
        }

        let parentDir = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: outputURL)

        guard pdfDocument.write(to: outputURL) else {
            throw PDFMergerError.cannotWritePDF(outputURL)
        }

        return outputURL
    }
}
