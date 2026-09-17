import Foundation
import Network
import CryptoKit

public final class StreamServer: @unchecked Sendable {
    private var listener: NWListener?
    private let port: UInt16
    private var connections: [UUID: NWConnection] = [:]
    private var webSocketConnections: Set<UUID> = []
    private let queue = DispatchQueue(label: "com.deskextend.streamserver", qos: .userInteractive)
    private let lock = NSLock()

    public private(set) var isRunning = false
    public var onClientCountChanged: ((Int) -> Void)?

    public init(port: UInt16 = 8080) {
        self.port = port
    }

    public var connectedClientsCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return webSocketConnections.count
    }

    public func start() throws {
        guard !isRunning else { return }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "StreamServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }

        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[StreamServer] HTTP/WebSocket Server listening on port \(self?.port ?? 8080)")
            case .failed(let error):
                print("[StreamServer] Listener failed with error: \(error)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] newConnection in
            self?.handleNewConnection(newConnection)
        }

        listener.start(queue: queue)
        isRunning = true
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        isRunning = false
        listener?.cancel()
        listener = nil

        for (_, conn) in connections {
            conn.cancel()
        }
        connections.removeAll()
        webSocketConnections.removeAll()
        onClientCountChanged?(0)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionID = UUID()

        lock.lock()
        connections[connectionID] = connection
        lock.unlock()

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveLoop(connection: connection, id: connectionID)
            case .failed, .cancelled:
                self?.removeConnection(id: connectionID)
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func removeConnection(id: UUID) {
        lock.lock()
        connections.removeValue(forKey: id)
        let wasWebSocket = webSocketConnections.remove(id) != nil
        let count = webSocketConnections.count
        lock.unlock()

        if wasWebSocket {
            DispatchQueue.main.async { [weak self] in
                self?.onClientCountChanged?(count)
            }
        }
    }

    private func receiveLoop(connection: NWConnection, id: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let data = content, !data.isEmpty {
                self.handleIncomingData(data, connection: connection, id: id)
            }

            if isComplete || error != nil {
                self.removeConnection(id: id)
            } else {
                self.receiveLoop(connection: connection, id: id)
            }
        }
    }

    private func handleIncomingData(_ data: Data, connection: NWConnection, id: UUID) {
        guard let requestString = String(data: data, encoding: .utf8) else { return }

        // Check for WebSocket Upgrade
        if requestString.contains("Upgrade: websocket") || requestString.contains("upgrade: websocket") {
            handleWebSocketHandshake(requestString: requestString, connection: connection, id: id)
            return
        }

        // Standard HTTP GET Request
        if requestString.hasPrefix("GET ") {
            let htmlData = Data(WebReceiver.htmlContent.utf8)
            let responseHeaders = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html; charset=utf-8\r
            Content-Length: \(htmlData.count)\r
            Connection: close\r
            Access-Control-Allow-Origin: *\r
            \r\n
            """
            var responseData = Data(responseHeaders.utf8)
            responseData.append(htmlData)

            connection.send(content: responseData, completion: .contentProcessed { [weak self] _ in
                // Keep connection alive or close after HTTP
                self?.removeConnection(id: id)
            })
        }
    }

    private func handleWebSocketHandshake(requestString: String, connection: NWConnection, id: UUID) {
        // Find Sec-WebSocket-Key
        guard let keyLine = requestString.components(separatedBy: "\r\n").first(where: {
            $0.lowercased().hasPrefix("sec-websocket-key:")
        }) else {
            return
        }

        let key = keyLine.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data((key + magic).utf8))
        let acceptKey = Data(digest).base64EncodedString()

        let handshakeResponse = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r\n
        """

        connection.send(content: Data(handshakeResponse.utf8), completion: .contentProcessed { [weak self] error in
            guard let self = self, error == nil else { return }
            self.lock.lock()
            self.webSocketConnections.insert(id)
            let count = self.webSocketConnections.count
            self.lock.unlock()

            print("[StreamServer] Client upgraded to WebSocket: \(id). Total clients: \(count)")
            DispatchQueue.main.async {
                self.onClientCountChanged?(count)
            }
        })
    }

    public func broadcastFrame(imageData: Data) {
        lock.lock()
        let clientIDs = Array(webSocketConnections)
        lock.unlock()

        guard !clientIDs.isEmpty else { return }

        // Construct RFC 6455 Binary Frame (Opcode 0x82)
        let frameHeader = makeWebSocketBinaryHeader(payloadLength: imageData.count)
        var packet = frameHeader
        packet.append(imageData)

        for id in clientIDs {
            lock.lock()
            let conn = connections[id]
            lock.unlock()

            conn?.send(content: packet, completion: .contentProcessed { _ in })
        }
    }

    private func makeWebSocketBinaryHeader(payloadLength: Int) -> Data {
        var header = Data()
        header.append(0x82) // FIN (1) + Opcode (2: binary)

        if payloadLength < 126 {
            header.append(UInt8(payloadLength))
        } else if payloadLength <= 65535 {
            header.append(126)
            var len16 = UInt16(payloadLength).bigEndian
            withUnsafeBytes(of: &len16) { header.append(contentsOf: $0) }
        } else {
            header.append(127)
            var len64 = UInt64(payloadLength).bigEndian
            withUnsafeBytes(of: &len64) { header.append(contentsOf: $0) }
        }
        return header
    }

    deinit {
        stop()
    }
}
