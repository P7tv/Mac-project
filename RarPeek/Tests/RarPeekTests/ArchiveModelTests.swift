import XCTest
@testable import RarPeekCore

final class ArchiveModelTests: XCTestCase {
    func testArchiveEntryFormatting() {
        let entry = ArchiveEntry(
            index: 0,
            path: "Documents/Work/Report.pdf",
            uncompressedSize: 2_097_152, // 2 MB
            compressedSize: 1_048_576,   // 1 MB
            isDirectory: false,
            isEncrypted: false,
            modificationDate: Date()
        )

        XCTAssertEqual(entry.name, "Report.pdf")
        XCTAssertEqual(entry.directoryPath, "Documents/Work")
        XCTAssertTrue(entry.formattedSize.contains("MB"))
        XCTAssertEqual(entry.compressionRatio, 50)
        XCTAssertFalse(entry.isEncrypted)
        XCTAssertFalse(entry.isDirectory)
    }

    func testArchiveInfoAggregation() {
        let entry1 = ArchiveEntry(
            index: 0,
            path: "file1.txt",
            uncompressedSize: 1000,
            compressedSize: 500,
            isDirectory: false,
            isEncrypted: false
        )
        let entry2 = ArchiveEntry(
            index: 1,
            path: "secure.zip",
            uncompressedSize: 2000,
            compressedSize: 1500,
            isDirectory: false,
            isEncrypted: true
        )

        let info = ArchiveInfo(
            fileURL: URL(fileURLWithPath: "/path/to/archive.rar"),
            formatName: "RAR5",
            entries: [entry1, entry2]
        )

        XCTAssertEqual(info.formatName, "RAR5")
        XCTAssertEqual(info.totalEntries, 2)
        XCTAssertEqual(info.totalUncompressedBytes, 3000)
        XCTAssertTrue(info.isEncrypted)
        XCTAssertEqual(info.archiveName, "archive.rar")
    }

    func testExtractionOptions() {
        let target = URL(fileURLWithPath: "/tmp/extracted")
        let options = ExtractionOptions(targetFolder: target, password: "SecretPassword")

        XCTAssertEqual(options.targetFolder.path, "/tmp/extracted")
        XCTAssertEqual(options.password, "SecretPassword")
        XCTAssertEqual(options.overwritePolicy, .rename)
    }
}
