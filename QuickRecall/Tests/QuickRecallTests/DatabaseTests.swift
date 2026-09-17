import XCTest
@testable import QuickRecallCore

final class DatabaseTests: XCTestCase {
    var db: RecallDatabase!
    var tempDbPath: String!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempDbPath = tempDir.appendingPathComponent("test_recall_\(UUID().uuidString).sqlite3").path
        db = RecallDatabase(databasePath: tempDbPath)
    }

    override func tearDown() {
        db = nil
        try? FileManager.default.removeItem(atPath: tempDbPath)
        super.tearDown()
    }

    func testInsertAndCount() {
        XCTAssertEqual(db.count(), 0)

        let record1 = RecallRecord(
            appName: "Xcode",
            windowTitle: "Project.swift",
            extractedText: "func testFeature() { print(\"Hello World\") }",
            thumbnailPath: "/tmp/thumb1.jpg"
        )
        db.insert(record: record1)
        XCTAssertEqual(db.count(), 1)

        let record2 = RecallRecord(
            appName: "Safari",
            windowTitle: "Pantip",
            extractedText: "สวัสดีครับ มีคำถามเกี่ยวกับ Apple Silicon M-series",
            thumbnailPath: "/tmp/thumb2.jpg"
        )
        db.insert(record: record2)
        XCTAssertEqual(db.count(), 2)
    }

    func testFTS5SearchThaiAndEnglish() {
        let record1 = RecallRecord(
            appName: "VS Code",
            windowTitle: "main.py",
            extractedText: "import tensorflow as tf\nmodel = tf.keras.Sequential()",
            thumbnailPath: "/tmp/thumb1.jpg"
        )
        let record2 = RecallRecord(
            appName: "Line",
            windowTitle: "Chat with Boss",
            extractedText: "ส่งสรุปรายงานประจำสัปดาห์เรียบร้อยแล้วครับ ขอบคุณครับ",
            thumbnailPath: "/tmp/thumb2.jpg"
        )

        db.insert(record: record1)
        db.insert(record: record2)

        // 1. Search English keyword
        let resultsEng = db.search(query: "tensorflow")
        XCTAssertEqual(resultsEng.count, 1)
        XCTAssertEqual(resultsEng.first?.appName, "VS Code")

        // 2. Search Thai keyword
        let resultsThai = db.search(query: "สรุปรายงาน")
        XCTAssertEqual(resultsThai.count, 1)
        XCTAssertEqual(resultsThai.first?.appName, "Line")

        // 3. Search non-existent keyword
        let resultsNone = db.search(query: "unobtainium")
        XCTAssertEqual(resultsNone.count, 0)
    }

    func testRecentRecords() {
        for i in 1...5 {
            let record = RecallRecord(
                appName: "App\(i)",
                extractedText: "Content \(i)",
                thumbnailPath: "/tmp/thumb\(i).jpg"
            )
            db.insert(record: record)
        }

        let recents = db.recentRecords(limit: 3)
        XCTAssertEqual(recents.count, 3)
    }

    func testPruneAndClear() {
        let oldRecord = RecallRecord(
            timestamp: Date(timeIntervalSinceNow: -10 * 86400), // 10 days ago
            appName: "OldApp",
            extractedText: "Old data",
            thumbnailPath: "/tmp/old.jpg"
        )
        let newRecord = RecallRecord(
            timestamp: Date(),
            appName: "NewApp",
            extractedText: "Fresh data",
            thumbnailPath: "/tmp/new.jpg"
        )

        db.insert(record: oldRecord)
        db.insert(record: newRecord)
        XCTAssertEqual(db.count(), 2)

        // Prune older than 7 days
        db.prune(olderThan: 7)
        XCTAssertEqual(db.count(), 1)
        let remaining = db.recentRecords()
        XCTAssertEqual(remaining.first?.appName, "NewApp")

        // Clear all
        db.clearAll()
        XCTAssertEqual(db.count(), 0)
    }
}
