import XCTest
@testable import SweepSpaceCore

final class EngineTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("SweepSpaceTests_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testDiskSpaceCalculatorReturnsValidNumbers() {
        let info = DiskSpaceCalculator.currentDiskSpace()
        XCTAssertGreaterThan(info.totalCapacityBytes, 0)
        XCTAssertGreaterThan(info.freeCapacityBytes, 0)
        XCTAssertLessThanOrEqual(info.usedPercentage, 1.0)
    }

    func testScanRuleCatalogRules() {
        let rules = ScanRuleCatalog.defaultRules
        XCTAssertGreaterThan(rules.count, 5)
        XCTAssertTrue(rules.contains { $0.category == .systemAndAppCache })
        XCTAssertTrue(rules.contains { $0.category == .developerJunk })
        XCTAssertTrue(rules.contains { $0.category == .trashAndLeftovers })
    }

    func testDiskScanEngineDirectoryMetrics() throws {
        let subfolder = tempDirectory.appendingPathComponent("dummy_cache", isDirectory: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)

        let file1 = subfolder.appendingPathComponent("file1.dat")
        let file2 = subfolder.appendingPathComponent("file2.dat")

        let data1 = Data(repeating: 0x41, count: 1024 * 100) // 100 KB
        let data2 = Data(repeating: 0x42, count: 1024 * 200) // 200 KB
        try data1.write(to: file1)
        try data2.write(to: file2)

        let engine = DiskScanEngine()
        let metrics = engine.calculateDirectoryMetrics(for: subfolder)

        XCTAssertEqual(metrics.size, 1024 * 300)
        XCTAssertEqual(metrics.count, 2)
    }

    func testDiskCleanerSafetyWhitelist() {
        XCTAssertFalse(DiskCleaner.isSafeToDelete(url: URL(fileURLWithPath: "/")))
        XCTAssertFalse(DiskCleaner.isSafeToDelete(url: URL(fileURLWithPath: "/System")))
        XCTAssertFalse(DiskCleaner.isSafeToDelete(url: URL(fileURLWithPath: "/Library")))
        XCTAssertFalse(DiskCleaner.isSafeToDelete(url: URL(fileURLWithPath: "/Applications")))
        XCTAssertFalse(DiskCleaner.isSafeToDelete(url: URL(fileURLWithPath: "/Users")))

        let safeTemp = tempDirectory.appendingPathComponent("test.tmp")
        XCTAssertTrue(DiskCleaner.isSafeToDelete(url: safeTemp))
    }

    func testDiskCleanerExecution() async throws {
        let testFile = tempDirectory.appendingPathComponent("clean_me.dat")
        let testData = Data(repeating: 0x55, count: 1024 * 50) // 50 KB
        try testData.write(to: testFile)

        let item = CleanableItem(
            name: "clean_me.dat",
            path: testFile,
            sizeBytes: 1024 * 50,
            category: .systemAndAppCache
        )

        let result = await DiskCleaner.clean(items: [item], useTrash: false)
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.cleanedBytes, 1024 * 50)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))
    }

    func testProjectDependenciesScanning() async throws {
        // Create mock project structure: /tmp/MyTestProject/node_modules/mock.js
        let projectDir = tempDirectory.appendingPathComponent("MyTestProject/node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let mockFile = projectDir.appendingPathComponent("bundle.js")
        let data = Data(repeating: 0x99, count: 1024 * 1024 * 2) // 2 MB
        try data.write(to: mockFile)

        let engine = DiskScanEngine()
        let discovered = await engine.scanProjectDependencies(roots: [tempDirectory], maxDepth: 4)

        XCTAssertTrue(discovered.contains { $0.name.contains("node_modules") })
        XCTAssertTrue(discovered.contains { $0.name.contains("MyTestProject") })
        XCTAssertGreaterThanOrEqual(discovered.first?.sizeBytes ?? 0, 1024 * 1024 * 2)
    }
}
