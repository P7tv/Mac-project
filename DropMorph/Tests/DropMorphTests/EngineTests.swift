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
}
