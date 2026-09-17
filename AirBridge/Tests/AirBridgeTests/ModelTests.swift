import XCTest
@testable import AirBridgeCore

final class ModelTests: XCTestCase {
    func testClipboardItemTextCreationAndHash() throws {
        let text = "Hello from Mac to Windows!"
        let item1 = ClipboardItem(type: .text, content: text)
        let item2 = ClipboardItem(type: .text, content: text)

        XCTAssertEqual(item1.hash, item2.hash)
        XCTAssertEqual(item1.type, .text)
        XCTAssertEqual(item1.content, text)
        XCTAssertEqual(item1.previewText, text)
    }

    func testClipboardItemSerialization() throws {
        let item = ClipboardItem(type: .url, content: "https://apple.com")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)

        XCTAssertEqual(item.id, decoded.id)
        XCTAssertEqual(item.hash, decoded.hash)
        XCTAssertEqual(item.content, decoded.content)
        XCTAssertEqual(item.type, decoded.type)
    }

    func testDeviceSessionAuthorization() throws {
        var session = DeviceSession(
            deviceName: "Panpan-PC",
            deviceType: "Windows",
            ipAddress: "192.168.1.50"
        )

        XCTAssertFalse(session.isAuthorized)
        session.isAuthorized = true
        XCTAssertTrue(session.isAuthorized)

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(DeviceSession.self, from: data)
        XCTAssertEqual(decoded.deviceName, "Panpan-PC")
        XCTAssertTrue(decoded.isAuthorized)
    }
}
