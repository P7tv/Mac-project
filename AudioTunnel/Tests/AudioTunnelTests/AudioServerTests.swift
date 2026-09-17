import XCTest
@testable import AudioTunnelCore

final class AudioServerTests: XCTestCase {
    func testServerHTTPResponse() async throws {
        let testPort: UInt16 = 7171
        let server = AudioStreamServer(port: testPort)
        try server.start()

        defer {
            server.stop()
        }

        // Give the listener 200ms to bind
        try await Task.sleep(nanoseconds: 200_000_000)

        // Test GET /
        guard let url = URL(string: "http://127.0.0.1:\(testPort)/") else {
            XCTFail("Invalid URL")
            return
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 200)

        let html = String(data: data, encoding: .utf8)
        XCTAssertNotNil(html)
        XCTAssertTrue(html?.contains("AudioTunnel") == true)

        // Test GET /api/status
        guard let statusUrl = URL(string: "http://127.0.0.1:\(testPort)/api/status") else {
            XCTFail("Invalid status URL")
            return
        }

        let (statusData, statusResp) = try await URLSession.shared.data(from: statusUrl)
        let httpStatusResp = statusResp as? HTTPURLResponse
        XCTAssertEqual(httpStatusResp?.statusCode, 200)

        let jsonStr = String(data: statusData, encoding: .utf8)
        XCTAssertNotNil(jsonStr)
        XCTAssertTrue(jsonStr?.contains("streaming") == true)
    }
}
