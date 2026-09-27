import XCTest
@testable import RarPeekCore

final class PasswordRecoveryEngineTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("RarPeekRecoveryTests_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func createEncryptedArchive(password: String) throws -> URL {
        let textFile = tempDirectory.appendingPathComponent("secret.txt")
        try "Confidential Information".write(to: textFile, atomically: true, encoding: .utf8)
        let archiveURL = tempDirectory.appendingPathComponent("encrypted.zip")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        proc.arguments = ["-e", "-P", password, archiveURL.path, "secret.txt"]
        proc.currentDirectoryURL = tempDirectory
        try proc.run()
        proc.waitUntilExit()

        XCTAssertEqual(proc.terminationStatus, 0)
        return archiveURL
    }

    func testVerifyPasswordCorrectAndIncorrect() async throws {
        let archiveURL = try createEncryptedArchive(password: "magic123")
        let engine = PasswordRecoveryEngine()

        let correctResult = await engine.verifyPassword(password: "magic123", archiveURL: archiveURL)
        XCTAssertEqual(correctResult, .valid)

        let wrongResult = await engine.verifyPassword(password: "wrongpass", archiveURL: archiveURL)
        XCTAssertEqual(wrongResult, .invalid)
    }

    func testCustomWordlistRecovery() async throws {
        let archiveURL = try createEncryptedArchive(password: "secretpass")
        let engine = PasswordRecoveryEngine()

        let candidates = ["1234", "admin", "secretpass", "password"]
        let progressBox = ProgressBox()

        let found = await engine.runRecovery(
            archiveURL: archiveURL,
            strategy: .customList(candidates),
            onProgress: { progress in
                Task {
                    await progressBox.add(progress)
                }
            }
        )

        XCTAssertEqual(found, "secretpass")
        let count = await progressBox.count
        XCTAssertGreaterThan(count, 0)
    }

    func testNumericPinRecovery() async throws {
        let archiveURL = try createEncryptedArchive(password: "0007")
        let engine = PasswordRecoveryEngine()

        let found = await engine.runRecovery(
            archiveURL: archiveURL,
            strategy: .numericPin(length: 4),
            onProgress: nil
        )

        XCTAssertEqual(found, "0007")
    }
}

private actor ProgressBox {
    private(set) var items: [RecoveryProgress] = []
    func add(_ item: RecoveryProgress) {
        items.append(item)
    }
    var count: Int {
        items.count
    }
}
