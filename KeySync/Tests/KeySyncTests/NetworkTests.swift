import XCTest
import Network
@testable import KeySyncCore

final class NetworkTests: XCTestCase {
    var server: KeySyncServer!
    let testPort: UInt16 = 6069

    override func setUp() {
        super.setUp()
        server = KeySyncServer(port: testPort)
    }

    override func tearDown() {
        server.stop()
        super.tearDown()
    }

    func testServerStartupAndClientConnection() async throws {
        try server.start()
        XCTAssertTrue(server.isRunning)

        let connectExp = expectation(description: "Client connects to server")
        server.onClientConnected = { connected in
            if connected { connectExp.fulfill() }
        }

        // Connect simulated client
        let host = NWEndpoint.Host("127.0.0.1")
        let port = NWEndpoint.Port(rawValue: testPort)!
        let clientConn = NWConnection(host: host, port: port, using: .tcp)
        clientConn.start(queue: .global())

        await fulfillment(of: [connectExp], timeout: 5.0)
        XCTAssertTrue(server.isClientConnected)

        clientConn.cancel()
    }
}
