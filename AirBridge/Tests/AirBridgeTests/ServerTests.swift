import XCTest
import Foundation
@testable import AirBridgeCore

final class ServerTests: XCTestCase {
    var server: AirBridgeServer!
    let testPort: UInt16 = 5059

    override func setUp() {
        super.setUp()
        server = AirBridgeServer(port: testPort)
    }

    override func tearDown() {
        server.stop()
        super.tearDown()
    }

    func testMobileWebPortalDelivery() async throws {
        try server.start()
        XCTAssertTrue(server.isRunning)

        let url = URL(string: "http://127.0.0.1:\(testPort)/")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTP")
            return
        }

        XCTAssertEqual(httpResponse.statusCode, 200)
        let html = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(html.contains("AirBridge — Universal Clipboard"))
        XCTAssertTrue(html.contains("Device Pairing"))
    }

    func testPairingAPI() async throws {
        try server.start()
        let pin = server.securityManager.currentPIN

        let url = URL(string: "http://127.0.0.1:\(testPort)/api/pair")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 1. Successful pairing
        let validBody = "{\"pin\":\"\(pin)\",\"deviceName\":\"TestPhone\",\"deviceType\":\"Mobile\"}"
        req.httpBody = Data(validBody.utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        XCTAssertEqual(json?["authorized"] as? Bool, true)
        XCTAssertFalse((json?["token"] as? String ?? "").isEmpty)

        // 2. Failed pairing with invalid PIN
        let invalidBody = "{\"pin\":\"0000_wrong\",\"deviceName\":\"TestPhone\",\"deviceType\":\"Mobile\"}"
        req.httpBody = Data(invalidBody.utf8)

        let (failData, _) = try await URLSession.shared.data(for: req)
        let failJson = (try? JSONSerialization.jsonObject(with: failData)) as? [String: Any]
        XCTAssertEqual(failJson?["authorized"] as? Bool, false)
    }

    func testWebSocketClipboardBroadcast() async throws {
        try server.start()

        let connectExp = expectation(description: "Client connects")
        server.onClientCountChanged = { count in
            if count == 1 { connectExp.fulfill() }
        }

        let wsURL = URL(string: "ws://127.0.0.1:\(testPort)/ws")!
        let wsTask = URLSession.shared.webSocketTask(with: wsURL)
        wsTask.resume()

        await fulfillment(of: [connectExp], timeout: 5.0)
        XCTAssertEqual(server.connectedClientsCount, 1)

        let receiveExp = expectation(description: "Receive clipboard item over WS")
        let testItem = ClipboardItem(type: .text, content: "Mac to Mobile Sync 100%")

        wsTask.receive { result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg,
                   let data = text.data(using: .utf8),
                   let item = try? JSONDecoder().decode(ClipboardItem.self, from: data) {
                    XCTAssertEqual(item.content, testItem.content)
                    receiveExp.fulfill()
                }
            case .failure(let err):
                XCTFail("WS receive failed: \(err)")
            }
        }

        // Broadcast from server
        server.broadcastClipboardItem(item: testItem)

        await fulfillment(of: [receiveExp], timeout: 5.0)
        wsTask.cancel(with: .normalClosure, reason: nil)
    }
}
