import XCTest
@testable import RarPeekCore

final class ArchiveEngineTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("RarPeekTests_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func createSampleArchive() throws -> URL {
        let file1 = tempDirectory.appendingPathComponent("hello.txt")
        let file2 = tempDirectory.appendingPathComponent("subfolder/data.json")
        try FileManager.default.createDirectory(at: file2.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        try "Hello World from RarPeek!".write(to: file1, atomically: true, encoding: .utf8)
        try "{\"app\": \"RarPeek\", \"status\": \"ok\"}".write(to: file2, atomically: true, encoding: .utf8)

        let archiveURL = tempDirectory.appendingPathComponent("sample.zip")

        // Use system zip command to create sample archive
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        proc.arguments = ["-r", archiveURL.path, "hello.txt", "subfolder"]
        proc.currentDirectoryURL = tempDirectory
        try proc.run()
        proc.waitUntilExit()

        XCTAssertEqual(proc.terminationStatus, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
        return archiveURL
    }

    func testInspectArchive() async throws {
        let archiveURL = try createSampleArchive()

        let info = try await ArchiveEngine.inspectArchive(url: archiveURL)

        XCTAssertEqual(info.archiveName, "sample.zip")
        XCTAssertGreaterThanOrEqual(info.entries.count, 2)
        XCTAssertTrue(info.entries.contains { $0.name == "hello.txt" })
        XCTAssertTrue(info.entries.contains { $0.name == "data.json" })
    }

    func testExtractAllArchive() async throws {
        let archiveURL = try createSampleArchive()
        let extractDir = tempDirectory.appendingPathComponent("extracted_all")

        let options = ExtractionOptions(targetFolder: extractDir, createContainingFolder: false)
        let resultURL = try await ArchiveEngine.extractArchive(url: archiveURL, options: options)

        XCTAssertTrue(FileManager.default.fileExists(atPath: resultURL.path))
        let helloFile = resultURL.appendingPathComponent("hello.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: helloFile.path))

        let content = try String(contentsOf: helloFile, encoding: .utf8)
        XCTAssertEqual(content, "Hello World from RarPeek!")
    }

    func testExtractSelectedArchive() async throws {
        let archiveURL = try createSampleArchive()
        let info = try await ArchiveEngine.inspectArchive(url: archiveURL)

        guard let helloEntry = info.entries.first(where: { $0.name == "hello.txt" }) else {
            XCTFail("hello.txt not found in archive")
            return
        }

        let extractDir = tempDirectory.appendingPathComponent("extracted_selected")
        let options = ExtractionOptions(
            targetFolder: extractDir,
            selectedIndexes: [helloEntry.index],
            createContainingFolder: false
        )

        let resultURL = try await ArchiveEngine.extractArchive(url: archiveURL, options: options)
        let helloFile = resultURL.appendingPathComponent("hello.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: helloFile.path))
    }
}
