import XCTest
import CoreGraphics
import UniformTypeIdentifiers
@testable import DropMorphCore

final class EngineTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func createTestImage(width: Int = 200, height: Int = 200, format: String = "png") -> URL {
        let fileURL = tempDirectory.appendingPathComponent("test_\(UUID().uuidString).\(format)")
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!

        // Draw colored rectangle
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: 20, y: 20, width: width - 40, height: height - 40))

        let cgImage = context.makeImage()!
        let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)

        return fileURL
    }

    private func createComplexTestImage(width: Int = 1000, height: Int = 1000) -> URL {
        let fileURL = tempDirectory.appendingPathComponent("complex_\(UUID().uuidString).png")
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!

        // Draw intricate grid with high entropy
        for x in stride(from: 0, to: width, by: 10) {
            for y in stride(from: 0, to: height, by: 10) {
                let r = CGFloat((x * 17) % 256) / 255.0
                let g = CGFloat((y * 31) % 256) / 255.0
                let b = CGFloat(((x + y) * 13) % 256) / 255.0
                context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1.0))
                context.fill(CGRect(x: x, y: y, width: 10, height: 10))
            }
        }

        let cgImage = context.makeImage()!
        let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)

        return fileURL
    }

    func testConversionSettingsTargetSizeMode() {
        var settings = ConversionSettings()
        XCTAssertEqual(settings.mode, .quality)
        XCTAssertEqual(settings.targetSizeMB, 2.0)
        XCTAssertEqual(settings.targetSizeBytes, 2 * 1024 * 1024)
        
        settings.mode = .targetSize
        settings.targetSizeMB = 0.5
        XCTAssertEqual(settings.targetSizeBytes, Int64(0.5 * 1024 * 1024))
    }

    func testImageTargetSizeCompressionJPEG() throws {
        let inputURL = createComplexTestImage(width: 800, height: 800)
        let targetMB = 0.08 // 80 KB
        let settings = ConversionSettings(targetFormat: .jpeg, mode: .targetSize, targetSizeMB: targetMB)

        let outputURL = try ImageConverter.convert(inputURL: inputURL, settings: settings)
        let fileSize = (try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

        XCTAssertTrue(fileSize > 0)
        XCTAssertLessThanOrEqual(fileSize, settings.targetSizeBytes + 2048)
    }

    func testImageTargetSizeCompressionWebP() throws {
        let inputURL = createComplexTestImage(width: 800, height: 800)
        let targetMB = 0.1 // 100 KB
        let settings = ConversionSettings(targetFormat: .webp, mode: .targetSize, targetSizeMB: targetMB)

        let outputURL = try ImageConverter.convert(inputURL: inputURL, settings: settings)
        let fileSize = (try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

        XCTAssertTrue(fileSize > 0)
        XCTAssertLessThanOrEqual(fileSize, settings.targetSizeBytes + 4096)
    }

    func testConvertPNGToWebP() throws {
        let inputURL = createTestImage(width: 400, height: 400, format: "png")
        let settings = ConversionSettings(targetFormat: .webp, quality: 0.8)

        let outputURL = try ImageConverter.convert(inputURL: inputURL, settings: settings)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(outputURL.pathExtension.lowercased(), "webp")
        
        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil) else {
            XCTFail("Failed to read converted WebP image")
            return
        }
        XCTAssertGreaterThan(CGImageSourceGetCount(source), 0)
    }

    func testConvertPNGToHEIC() throws {
        let inputURL = createTestImage(width: 400, height: 400, format: "png")
        let settings = ConversionSettings(targetFormat: .heic, quality: 0.75)

        let outputURL = try ImageConverter.convert(inputURL: inputURL, settings: settings)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(outputURL.pathExtension.lowercased(), "heic")

        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil) else {
            XCTFail("Failed to read converted HEIC image")
            return
        }
        XCTAssertGreaterThan(CGImageSourceGetCount(source), 0)
    }

    func testConvertJPEGWithDownsample() throws {
        let inputURL = createTestImage(width: 800, height: 800, format: "png")
        let settings = ConversionSettings(targetFormat: .jpeg, quality: 0.7, resizePreset: .fifty)

        let outputURL = try ImageConverter.convert(inputURL: inputURL, settings: settings)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(outputURL.pathExtension.lowercased(), "jpg")

        guard let source = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat else {
            XCTFail("Failed to read properties of converted JPEG")
            return
        }

        // Width should be downscaled around 400px (50% of 800px)
        XCTAssertEqual(width, 400, accuracy: 5)
    }

    func testMergeImagesToPDF() throws {
        let img1 = createTestImage(width: 300, height: 300)
        let img2 = createTestImage(width: 300, height: 300)
        let outputPDF = tempDirectory.appendingPathComponent("merged.pdf")

        let resultURL = try PDFMerger.mergeToPDF(imageURLs: [img1, img2], outputURL: outputPDF)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
        XCTAssertEqual(resultURL.pathExtension.lowercased(), "pdf")

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: resultURL.path)[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(fileSize, 0)
    }

    func testConvertSVGToPNG() throws {
        let svgContent = """
        <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">
          <rect width="200" height="200" fill="#2563eb"/>
          <circle cx="100" cy="100" r="60" fill="#facc15"/>
        </svg>
        """
        let svgURL = tempDirectory.appendingPathComponent("test_vector.svg")
        try svgContent.write(to: svgURL, atomically: true, encoding: .utf8)

        let settings = ConversionSettings(targetFormat: .png)
        let outputURL = try ImageConverter.convert(inputURL: svgURL, settings: settings)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(outputURL.pathExtension.lowercased(), "png")
        let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(size, 0)
    }

    func testExtractPDFPagesToImages() throws {
        // First create a 2-page PDF
        let img1 = createTestImage(width: 200, height: 200)
        let img2 = createTestImage(width: 200, height: 200)
        let pdfURL = tempDirectory.appendingPathComponent("document.pdf")
        _ = try PDFMerger.mergeToPDF(imageURLs: [img1, img2], outputURL: pdfURL)

        // Now extract pages
        let extracted = try PDFExtractor.extractPages(pdfURL: pdfURL, format: .png, outputDirectory: tempDirectory)
        XCTAssertEqual(extracted.count, 2)
        for pageURL in extracted {
            XCTAssertTrue(FileManager.default.fileExists(atPath: pageURL.path))
            XCTAssertEqual(pageURL.pathExtension.lowercased(), "png")
        }
    }

    func testCompressPDF() throws {
        let img1 = createTestImage(width: 400, height: 400)
        let img2 = createTestImage(width: 400, height: 400)
        let originalPDF = tempDirectory.appendingPathComponent("to_compress.pdf")
        _ = try PDFMerger.mergeToPDF(imageURLs: [img1, img2], outputURL: originalPDF)

        let settings = ConversionSettings(targetFormat: .pdf, quality: 0.6)
        let compressedURL = try PDFCompressor.compressPDF(inputURL: originalPDF, settings: settings)

        XCTAssertTrue(FileManager.default.fileExists(atPath: compressedURL.path))
        XCTAssertEqual(compressedURL.pathExtension.lowercased(), "pdf")
        let size = (try? FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(size, 0)
    }

    func testPDFTargetSizeCompression() throws {
        let page1 = createComplexTestImage(width: 600, height: 600)
        let page2 = createComplexTestImage(width: 600, height: 600)
        let originalPDF = tempDirectory.appendingPathComponent("multi_page.pdf")
        _ = try PDFMerger.mergeToPDF(imageURLs: [page1, page2], outputURL: originalPDF, quality: 1.0)

        let targetMB = 0.12 // 120 KB
        let settings = ConversionSettings(targetFormat: .pdf, mode: .targetSize, targetSizeMB: targetMB)

        let compressedURL = try PDFCompressor.compressPDF(inputURL: originalPDF, settings: settings)
        let size = (try? FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? Int64) ?? 0

        XCTAssertTrue(size > 0)
        XCTAssertLessThanOrEqual(size, settings.targetSizeBytes + 4096)
    }

    func testVideoTargetBitrateBudgeting() {
        let duration: Double = 60.0 // 1 minute video
        let targetMB = 10.0 // 10 MB
        let targetBytes = Int64(targetMB * 1024 * 1024)

        let budget = VideoConverter.calculateTargetBitrate(durationSeconds: duration, targetSizeBytes: targetBytes)

        XCTAssertGreaterThan(budget.videoBitrate, 500_000)
        XCTAssertLessThanOrEqual(budget.videoBitrate, 2_000_000)
        XCTAssertEqual(budget.audioBitrate, 96_000)
        XCTAssertEqual(budget.targetResolution.width, 1280)
        XCTAssertEqual(budget.targetResolution.height, 720)
    }
}
