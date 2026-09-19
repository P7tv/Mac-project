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

    func testFileUploadToDownloads() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        server.customDownloadDirectory = tempDir
        try server.start()

        let fileReceivedExp = expectation(description: "Server receives uploaded file")
        final class ResultBox: @unchecked Sendable {
            var filename: String = ""
            var url: URL?
        }
        let box = ResultBox()

        server.onFileReceived = { filename, url in
            box.filename = filename
            box.url = url
            fileReceivedExp.fulfill()
        }

        let uploadURL = URL(string: "http://127.0.0.1:\(testPort)/api/upload")!
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileContent = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01, 0x02, 0x03, 0xFF]) // PNG signature + dummy bytes
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"cyber_report.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(fileContent)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (respData, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTPURLResponse")
            return
        }

        XCTAssertEqual(httpResponse.statusCode, 200)
        let json = (try? JSONSerialization.jsonObject(with: respData)) as? [String: Any]
        XCTAssertEqual(json?["status"] as? String, "ok")
        XCTAssertEqual(json?["filename"] as? String, "cyber_report.png")

        await fulfillment(of: [fileReceivedExp], timeout: 5.0)
        XCTAssertEqual(box.filename, "cyber_report.png")
        guard let savedURL = box.url else {
            XCTFail("Saved URL is nil")
            return
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        let savedData = try Data(contentsOf: savedURL)
        XCTAssertEqual(savedData, fileContent)
    }

    func testFileUploadDuplicateNames() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        server.customDownloadDirectory = tempDir
        try server.start()

        let existingFile = tempDir.appendingPathComponent("document.pdf")
        try Data("Original".utf8).write(to: existingFile)

        let uploadURL = URL(string: "http://127.0.0.1:\(testPort)/api/upload")!
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"

        let boundary = "Boundary-123"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let newContent = Data("New Uploaded Document".utf8)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"document.pdf\"\r\n\r\n".data(using: .utf8)!)
        body.append(newContent)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (respData, response) = try await URLSession.shared.data(for: req)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)

        let json = (try? JSONSerialization.jsonObject(with: respData)) as? [String: Any]
        XCTAssertEqual(json?["filename"] as? String, "document (1).pdf")

        let newFileURL = tempDir.appendingPathComponent("document (1).pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFileURL.path))
        XCTAssertEqual(try Data(contentsOf: newFileURL), newContent)
        XCTAssertEqual(try String(contentsOf: existingFile, encoding: .utf8), "Original")
    }

    func testFileUploadRawBinaryWithHeader() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        server.customDownloadDirectory = tempDir
        try server.start()

        let uploadURL = URL(string: "http://127.0.0.1:\(testPort)/api/upload")!
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.setValue("binary_notes.txt", forHTTPHeaderField: "X-Filename")
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let rawBytes = Data("Direct binary stream file payload".utf8)
        req.httpBody = rawBytes

        let (respData, response) = try await URLSession.shared.data(for: req)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)

        let json = (try? JSONSerialization.jsonObject(with: respData)) as? [String: Any]
        XCTAssertEqual(json?["filename"] as? String, "binary_notes.txt")

        let savedURL = tempDir.appendingPathComponent("binary_notes.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertEqual(try Data(contentsOf: savedURL), rawBytes)
    }
}
