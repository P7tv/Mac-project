import Foundation
import CoreGraphics

public struct PerceptualHasher: Sendable {
    /// Computes a 64-bit difference hash (dHash) from a CGImage
    public static func computeDHash(image: CGImage) -> UInt64 {
        let width = 9
        let height = 8

        var rawPixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: &rawPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        for y in 0..<height {
            for x in 0..<8 {
                let left = rawPixels[y * width + x]
                let right = rawPixels[y * width + x + 1]
                if left > right {
                    let bitPosition = y * 8 + x
                    hash |= (1 << bitPosition)
                }
            }
        }

        return hash
    }

    /// Computes the Hamming distance (number of differing bits) between two hashes
    public static func hammingDistance(hash1: UInt64, hash2: UInt64) -> Int {
        return (hash1 ^ hash2).nonzeroBitCount
    }

    /// Returns true if two images are perceptually significantly different
    public static func isDifferent(hash1: UInt64, hash2: UInt64, threshold: Int = 4) -> Bool {
        return hammingDistance(hash1: hash1, hash2: hash2) > threshold
    }
}
