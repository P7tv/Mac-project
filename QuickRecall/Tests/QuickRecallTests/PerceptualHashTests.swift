import XCTest
import CoreGraphics
@testable import QuickRecallCore

final class PerceptualHashTests: XCTestCase {
    private func createSolidImage(width: Int, height: Int, isWhite: Bool) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.setFillColor(isWhite ? CGColor(gray: 1.0, alpha: 1.0) : CGColor(gray: 0.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    func testHammingDistance() {
        let hashA: UInt64 = 0b10101010
        let hashB: UInt64 = 0b10101010
        XCTAssertEqual(PerceptualHasher.hammingDistance(hash1: hashA, hash2: hashB), 0)

        let hashC: UInt64 = 0b10101111 // 2 bits different from hashA
        XCTAssertEqual(PerceptualHasher.hammingDistance(hash1: hashA, hash2: hashC), 2)
    }

    func testIdenticalImagesProduceZeroDistance() {
        guard let img1 = createSolidImage(width: 50, height: 50, isWhite: true),
              let img2 = createSolidImage(width: 50, height: 50, isWhite: true) else {
            XCTFail("Failed to create test images")
            return
        }

        let hash1 = PerceptualHasher.computeDHash(image: img1)
        let hash2 = PerceptualHasher.computeDHash(image: img2)

        XCTAssertEqual(hash1, hash2)
        XCTAssertFalse(PerceptualHasher.isDifferent(hash1: hash1, hash2: hash2, threshold: 4))
    }
}
