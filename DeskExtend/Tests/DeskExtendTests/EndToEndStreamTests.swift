import XCTest
import Foundation
@testable import DeskExtendCore

final class EndToEndStreamTests: XCTestCase {
    var server: StreamServer!
    let testPort: UInt16 = 8089

    override func setUp() {
        super.setUp()
        server = StreamServer(port: testPort)
    }

    override func tearDown() {
        server.stop()
        super.tearDown()
    }

    func testServerHTTPDelivery() async throws {
        try server.start()
        XCTAssertTrue(server.isRunning)

        let url = URL(string: "http://127.0.0.1:\(testPort)/")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }

        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertEqual(httpResponse.value(forHTTPHeaderField: "Content-Type"), "text/html; charset=utf-8")

        let html = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(html.contains("DeskExtend - Secondary Display"), "HTML must contain page title")
        XCTAssertTrue(html.contains("<canvas id=\"screen\">"), "HTML must contain screen canvas")
        XCTAssertTrue(html.contains("createImageBitmap"), "HTML must contain WebCodecs/ImageBitmap hardware renderer")
    }

    func testServerWebSocketStreaming() async throws {
        try server.start()

        let frameExpectation = self.expectation(description: "WebSocket receives frame")
        let clientCountExpectation = self.expectation(description: "Server registers client connection")

        server.onClientCountChanged = { count in
            if count == 1 {
                clientCountExpectation.fulfill()
            }
        }

        let wsURL = URL(string: "ws://127.0.0.1:\(testPort)/stream")!
        let wsTask = URLSession.shared.webSocketTask(with: wsURL)
        wsTask.resume()

        await fulfillment(of: [clientCountExpectation], timeout: 5.0)
        XCTAssertEqual(server.connectedClientsCount, 1)

        // Broadcast a synthetic frame
        let testPayload = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]) // JPEG header bytes
        server.broadcastFrame(imageData: testPayload)

        wsTask.receive { result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let receivedData):
                    XCTAssertEqual(receivedData, testPayload, "Received binary payload must match broadcasted JPEG")
                    frameExpectation.fulfill()
                case .string(let text):
                    XCTFail("Unexpected text message received: \(text)")
                @unknown default:
                    break
                }
            case .failure(let error):
                XCTFail("WebSocket receive failed: \(error)")
            }
        }

        await fulfillment(of: [frameExpectation], timeout: 5.0)
        wsTask.cancel(with: .normalClosure, reason: nil)
    }

    func testStreamHighThroughputBenchmark() async throws {
        try server.start()

        let connectedExp = self.expectation(description: "Client connects")
        server.onClientCountChanged = { count in
            if count == 1 { connectedExp.fulfill() }
        }

        let wsURL = URL(string: "ws://127.0.0.1:\(testPort)/stream")!
        let wsTask = URLSession.shared.webSocketTask(with: wsURL)
        wsTask.resume()

        await fulfillment(of: [connectedExp], timeout: 5.0)

        let totalFrames = 60
        let frameExpectation = self.expectation(description: "All frames received")
        frameExpectation.expectedFulfillmentCount = totalFrames

        // Synthetic 1080p JPEG dummy frame (~32 KB)
        var tempFrame = Data(repeating: 0xAB, count: 32768)
        tempFrame[0] = 0xFF; tempFrame[1] = 0xD8 // SOI
        tempFrame[tempFrame.count - 2] = 0xFF; tempFrame[tempFrame.count - 1] = 0xD9 // EOI
        let dummyFrame = tempFrame
        let expectedSize = dummyFrame.count

        let startTime = CFAbsoluteTimeGetCurrent()

        let receiveTask = Task {
            for _ in 0..<totalFrames {
                do {
                    let msg = try await wsTask.receive()
                    if case .data(let data) = msg {
                        XCTAssertEqual(data.count, expectedSize)
                        frameExpectation.fulfill()
                    }
                } catch {
                    XCTFail("Receive error: \(error)")
                    break
                }
            }
        }

        // Send 60 frames rapidly
        for _ in 0..<totalFrames {
            server.broadcastFrame(imageData: dummyFrame)
            try await Task.sleep(nanoseconds: 2_000_000) // 2ms interval
        }

        await fulfillment(of: [frameExpectation], timeout: 10.0)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let fps = Double(totalFrames) / elapsed
        let mbps = (Double(totalFrames * expectedSize * 8) / elapsed) / 1_000_000.0

        print(String(format: "\n[Benchmark] Streamed %d frames in %.3f s | %.1f FPS | %.2f Mbps throughput\n", totalFrames, elapsed, fps, mbps))

        receiveTask.cancel()
        wsTask.cancel(with: .normalClosure, reason: nil)
    }

    func testNetworkInterfaceHelper() {
        let addresses = NetworkInterfaceHelper.getLocalIPAddresses(port: 8080)
        XCTAssertFalse(addresses.isEmpty, "Must detect at least one local address")

        let hasLocalhost = addresses.contains { $0.ip == "127.0.0.1" }
        XCTAssertTrue(hasLocalhost, "Must contain localhost address")

        for addr in addresses {
            XCTAssertTrue(addr.urlString.contains(":\(addr.port)"))
        }
    }
}

