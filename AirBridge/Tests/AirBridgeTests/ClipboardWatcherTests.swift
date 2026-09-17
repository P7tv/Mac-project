import XCTest
import AppKit
@testable import AirBridgeCore

@MainActor
final class ClipboardWatcherTests: XCTestCase {
    func testClipboardWatcherReadAndWrite() async throws {
        let watcher = ClipboardWatcher()
        let testString = "AirBridge Test Sync \(UUID().uuidString)"
        let testItem = ClipboardItem(type: .text, content: testString)

        watcher.copyToPasteboard(item: testItem)
        try await Task.sleep(nanoseconds: 100_000_000)

        let readItem = watcher.readCurrentPasteboard()
        XCTAssertNotNil(readItem)
        XCTAssertEqual(readItem?.content, testString)
        XCTAssertEqual(readItem?.type, .text)
    }

    func testDeduplicationPreventsRebroadcast() async throws {
        let watcher = ClipboardWatcher()
        let text = "Unique deduplication test string"
        let item = ClipboardItem(type: .text, content: text)

        watcher.copyToPasteboard(item: item)
        try await Task.sleep(nanoseconds: 50_000_000)

        let expectationFired = expectation(description: "Should not fire")
        expectationFired.isInverted = true

        watcher.onNewItem = { _ in
            expectationFired.fulfill()
        }

        watcher.checkPasteboard()
        await fulfillment(of: [expectationFired], timeout: 0.2)
    }
}
