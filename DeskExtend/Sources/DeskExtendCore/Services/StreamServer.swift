import Foundation
import Network
import CryptoKit

public final class StreamServer: @unchecked Sendable {
    private var listener: NWListener?
    private let port: UInt16
    private var connections: [UUID: NWConnection] = [:]
    private var webSocketConnections: Set<UUID> = []
    private var framePacers: [UUID: FramePacer] = [:]
    private var receiverParsers: [UUID: ReceiverControlParser] = [:]
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

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 2
        let params = NWParameters(tls: nil, tcp: tcp)
        params.allowLocalEndpointReuse = true
        params.serviceClass = .responsiveData

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
        framePacers.removeAll()
        receiverParsers.removeAll()
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
        framePacers.removeValue(forKey: id)
        receiverParsers.removeValue(forKey: id)
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
        lock.lock()
        let isWebSocket = webSocketConnections.contains(id)
        lock.unlock()
        if isWebSocket {
            handleReceiverControl(data, connection: connection, id: id)
            return
        }
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
        let protocols = requestString.components(separatedBy: "\r\n")
            .first { $0.lowercased().hasPrefix("sec-websocket-protocol:") }?
            .split(separator: ":", maxSplits: 1).last?
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        let requiresAck = protocols.contains("deskextend-v1")
        let protocolHeader = requiresAck ? "Sec-WebSocket-Protocol: deskextend-v1\r\n" : ""

        let handshakeResponse = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(acceptKey)\r\n\(protocolHeader)\r\n"

        connection.send(content: Data(handshakeResponse.utf8), completion: .contentProcessed { [weak self] error in
            guard let self = self, error == nil else { return }
            self.lock.lock()
            guard self.connections[id] === connection else {
                self.lock.unlock()
                return
            }
            self.webSocketConnections.insert(id)
            self.framePacers[id] = FramePacer(requiresAcknowledgement: requiresAck)
            self.receiverParsers[id] = ReceiverControlParser()
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
            let ready = framePacers[id]?.offer(packet)
            lock.unlock()
            if let ready { sendFrame(ready, to: id) }
        }
    }

    private func sendFrame(_ packet: Data, to id: UUID) {
        lock.lock()
        let connection = connections[id]
        lock.unlock()
        connection?.send(content: packet, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil {
                connection?.cancel()
                self.removeConnection(id: id)
                return
            }
            self.lock.lock()
            let next = self.framePacers[id]?.sent()
            self.lock.unlock()
            if let next { self.sendFrame(next, to: id) }
        })
    }

    private func handleReceiverControl(_ data: Data, connection: NWConnection, id: UUID) {
        let messages: [ReceiverControlParser.Message]
        lock.lock()
        do {
            messages = try receiverParsers[id]?.append(data) ?? []
            lock.unlock()
        } catch {
            lock.unlock()
            connection.cancel()
            removeConnection(id: id)
            return
        }
        for message in messages {
            switch message.opcode {
            case 2 where message.payload == Data([1]):
                lock.lock()
                let next = framePacers[id]?.acknowledge()
                lock.unlock()
                if let next { sendFrame(next, to: id) }
            case 8:
                connection.cancel()
                removeConnection(id: id)
            case 9:
                var pong = Data([0x8A, UInt8(message.payload.count)])
                pong.append(message.payload)
                connection.send(content: pong, completion: .contentProcessed { _ in })
            default:
                break
            }
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
