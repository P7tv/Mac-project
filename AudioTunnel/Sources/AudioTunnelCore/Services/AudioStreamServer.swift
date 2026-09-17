import Foundation
import Network
import CommonCrypto

public protocol AudioStreamServerDelegate: AnyObject, Sendable {
    func audioStreamServer(didUpdateListeners count: Int)
}

public final class AudioStreamServer: @unchecked Sendable {
    public let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.audiotunnel.server", qos: .userInteractive)

    private let lock = NSLock()
    private var clients: [UUID: NWConnection] = [:]
    private var wsClients: Set<UUID> = []
    private var rawClients: Set<UUID> = []

    public weak var delegate: AudioStreamServerDelegate?
    public var currentModeName: String = "System Audio"

    public var connectedClientsCount: Int {
        lock.withLock { clients.count }
    }

    public init(port: UInt16 = 7070) {
        self.port = port
    }

    public func start() throws {
        stop()

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.serviceClass = .interactiveVideo

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "AudioTunnel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }

        let listener = try NWListener(using: params, on: nwPort)
        listener.service = NWListener.Service(name: "AudioTunnel", type: "_audiotunnel._tcp")

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[AudioTunnel] Server listening on port \(nwPort)")
            case .failed(let err):
                print("[AudioTunnel] Server failed: \(err)")
            case .cancelled:
                print("[AudioTunnel] Server stopped.")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        lock.withLock {
            for (_, conn) in clients {
                conn.cancel()
            }
            clients.removeAll()
            wsClients.removeAll()
            rawClients.removeAll()
        }

        listener?.cancel()
        listener = nil
        notifyListenersCountChanged()
    }

    // MARK: - Broadcast Audio
    public func broadcast(pcm16Data: Data) {
        let (activeWs, activeRaw) = lock.withLock { () -> ([NWConnection], [NWConnection]) in
            var wsList: [NWConnection] = []
            var rawList: [NWConnection] = []
            for id in wsClients {
                if let conn = clients[id] { wsList.append(conn) }
            }
            for id in rawClients {
                if let conn = clients[id] { rawList.append(conn) }
            }
            return (wsList, rawList)
        }

        if activeWs.isEmpty && activeRaw.isEmpty { return }

        // 1. Send to WebSocket browsers (RFC 6455 Binary Frame)
        if !activeWs.isEmpty {
            let wsFrame = AudioPacket.encodeWebSocketBinaryFrame(payload: pcm16Data)
            for conn in activeWs {
                conn.send(content: wsFrame, isComplete: false, completion: .idempotent)
            }
        }

        // 2. Send to Raw TCP Clients (AudioPacket binary header + pcm payload)
        if !activeRaw.isEmpty {
            let packet = AudioPacket(
                sequence: 0,
                timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
                sampleRate: 48000,
                channels: 2,
                format: 1,
                pcmData: pcm16Data
            )
            let serialized = packet.serialize()
            for conn in activeRaw {
                conn.send(content: serialized, isComplete: false, completion: .idempotent)
            }
        }
    }

    // MARK: - Connection Handling
    private func handleNewConnection(_ connection: NWConnection) {
        let connectionId = UUID()
        connection.start(queue: queue)

        lock.withLock {
            clients[connectionId] = connection
        }
        notifyListenersCountChanged()

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                self?.removeConnection(connectionId)
            default:
                break
            }
        }

        receiveHTTPOrData(connectionId: connectionId, connection: connection)
    }

    private func removeConnection(_ connectionId: UUID) {
        lock.withLock {
            clients.removeValue(forKey: connectionId)
            wsClients.remove(connectionId)
            rawClients.remove(connectionId)
        }
        notifyListenersCountChanged()
    }

    private func notifyListenersCountChanged() {
        let count = lock.withLock { clients.count }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.audioStreamServer(didUpdateListeners: count)
        }
    }

    private func receiveHTTPOrData(connectionId: UUID, connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("[AudioTunnel] Connection error: \(error)")
                self.removeConnection(connectionId)
                return
            }

            if let data = data, !data.isEmpty {
                self.handleIncomingData(connectionId: connectionId, connection: connection, data: data)
            }

            if isComplete {
                self.removeConnection(connectionId)
            } else {
                // If not converted to pure audio sender, continue listening for requests or ping/pongs
                self.receiveHTTPOrData(connectionId: connectionId, connection: connection)
            }
        }
    }

    private func handleIncomingData(connectionId: UUID, connection: NWConnection, data: Data) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            // Raw binary stream request or native client
            _ = lock.withLock { rawClients.insert(connectionId) }
            return
        }

        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first, !firstLine.isEmpty else { return }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return }

        let method = String(parts[0])
        let path = String(parts[1])

        // WebSocket Upgrade Check
        if requestString.contains("Upgrade: websocket") || requestString.contains("upgrade: websocket") {
            handleWebSocketHandshake(connectionId: connectionId, connection: connection, lines: lines)
            return
        }

        // Standard HTTP Routes
        if method == "GET" {
            if path == "/" || path == "/index.html" {
                sendHTTPResponse(
                    connection: connection,
                    status: "200 OK",
                    contentType: "text/html; charset=utf-8",
                    body: Data(WebAudioPlayer.htmlContent.utf8)
                )
            } else if path == "/api/status" {
                let statusJson = """
                {
                    "status": "streaming",
                    "mode": "\(currentModeName)",
                    "listeners": \(connectedClientsCount),
                    "sampleRate": 48000,
                    "channels": 2
                }
                """
                sendHTTPResponse(
                    connection: connection,
                    status: "200 OK",
                    contentType: "application/json",
                    body: Data(statusJson.utf8)
                )
            } else {
                let notFound = "Not Found"
                sendHTTPResponse(
                    connection: connection,
                    status: "404 Not Found",
                    contentType: "text/plain",
                    body: Data(notFound.utf8)
                )
            }
        }
    }

    private func handleWebSocketHandshake(connectionId: UUID, connection: NWConnection, lines: [String]) {
        var secWebSocketKey: String?

        for line in lines {
            if line.lowercased().starts(with: "sec-websocket-key:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    secWebSocketKey = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }

        guard let key = secWebSocketKey else {
            connection.cancel()
            return
        }

        // Magic GUID specified in RFC 6455
        let magicString = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let acceptKey = computeSHA1Base64(magicString)

        let handshakeResponse = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r

        """

        connection.send(content: Data(handshakeResponse.utf8), completion: .contentProcessed { [weak self] error in
            if error == nil {
                _ = self?.lock.withLock {
                    self?.wsClients.insert(connectionId)
                }
            }
        })
    }

    private func sendHTTPResponse(connection: NWConnection, status: String, contentType: String, body: Data) {
        let headers = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r

        """
        var responseData = Data(headers.utf8)
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func computeSHA1Base64(_ input: String) -> String {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }
}
