import XCTest
@testable import SweepSpaceCore

final class ModelTests: XCTestCase {
    func testCleaningCategoryProperties() {
        XCTAssertEqual(CleaningCategory.allCases.count, 4)
        XCTAssertTrue(CleaningCategory.systemAndAppCache.isSafeByDefault)
        XCTAssertTrue(CleaningCategory.developerJunk.isSafeByDefault)
        XCTAssertFalse(CleaningCategory.largeAndOldFiles.isSafeByDefault)
        XCTAssertTrue(CleaningCategory.trashAndLeftovers.isSafeByDefault)
    }

    func testLargeFileTypeClassification() {
        XCTAssertEqual(LargeFileType.classify(extension: "mov"), .video)
        XCTAssertEqual(LargeFileType.classify(extension: "MP4"), .video)
        XCTAssertEqual(LargeFileType.classify(extension: "zip"), .archive)
        XCTAssertEqual(LargeFileType.classify(extension: "dmg"), .diskImage)
        XCTAssertEqual(LargeFileType.classify(extension: "pdf"), .other)
    }

    func testCleanableItemFormatting() {
        let dummyURL = URL(fileURLWithPath: "/tmp/sample.log")
        let item = CleanableItem(
            name: "sample.log",
            path: dummyURL,
            sizeBytes: 1024 * 1024 * 50, // 50 MB
            category: .systemAndAppCache
        )

        XCTAssertFalse(item.formattedSize.isEmpty)
        XCTAssertEqual(item.name, "sample.log")
        XCTAssertEqual(item.category, .systemAndAppCache)
    }

    func testDiskSpaceInfoCalculations() {
        let total: Int64 = 1_000_000_000_000 // 1 TB
        let free: Int64 = 300_000_000_000    // 300 GB
        let recoverable: Int64 = 50_000_000_000 // 50 GB

        let info = DiskSpaceInfo(
            totalCapacityBytes: total,
            freeCapacityBytes: free,
            recoverableBytes: recoverable
        )

        XCTAssertEqual(info.usedCapacityBytes, 700_000_000_000)
        XCTAssertEqual(info.usedPercentage, 0.7, accuracy: 0.001)
        XCTAssertEqual(info.recoverablePercentage, 0.05, accuracy: 0.001)
        XCTAssertFalse(info.formattedTotal.isEmpty)
        XCTAssertFalse(info.formattedFree.isEmpty)
        XCTAssertFalse(info.formattedUsed.isEmpty)
        XCTAssertFalse(info.formattedRecoverable.isEmpty)
    }
}
