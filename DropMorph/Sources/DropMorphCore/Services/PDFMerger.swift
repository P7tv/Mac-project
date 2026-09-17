import Foundation
import AppKit
import PDFKit

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
    public static func mergeToPDF(imageURLs: [URL], outputURL: URL) throws -> URL {
        let pdfDocument = PDFDocument()
        var addedCount = 0

        for url in imageURLs {
            guard let nsImage = NSImage(contentsOf: url) else { continue }
            if let pdfPage = PDFPage(image: nsImage) {
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
