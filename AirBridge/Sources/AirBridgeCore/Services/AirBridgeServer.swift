import Foundation
import Network
import CryptoKit

public final class AirBridgeServer: @unchecked Sendable {
    private var listener: NWListener?
    public let port: UInt16
    public let securityManager: SecurityManager

    private var connections: [UUID: NWConnection] = [:]
    private var webSocketConnections: [UUID: NWConnection] = [:]
    private var connectionTokens: [UUID: String] = [:]
    private var connectionBuffers: [UUID: Data] = [:]
    private let queue = DispatchQueue(label: "com.airbridge.server", qos: .userInteractive)
    private let lock = NSLock()

    public private(set) var isRunning = false
    public var latestItem: ClipboardItem?
    public var onClientPushedItem: (@Sendable (ClipboardItem) -> Void)?
    public var onClientCountChanged: (@Sendable (Int) -> Void)?
    public var onFileReceived: (@Sendable (String, URL) -> Void)?
    public var customDownloadDirectory: URL? = nil

    public init(port: UInt16 = 5050, securityManager: SecurityManager = SecurityManager()) {
        self.port = port
        self.securityManager = securityManager
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
        let params = NWParameters(tls: nil, tcp: tcp)
        params.allowLocalEndpointReuse = true

        // Advertise over Bonjour (mDNS)
        params.serviceClass = .responsiveData
        let bonjourDesc = NWListener.Service(name: "AirBridge on Mac", type: "_airbridge._tcp")
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "AirBridgeServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }

        let listener = try NWListener(using: params, on: nwPort)
        listener.service = bonjourDesc
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[AirBridgeServer] Server listening on port \(self?.port ?? 5050)")
            case .failed(let err):
                print("[AirBridgeServer] Listener failed: \(err)")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] conn in
            self?.handleNewConnection(conn)
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
        connectionTokens.removeAll()
        connectionBuffers.removeAll()
        onClientCountChanged?(0)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionID = UUID()

        lock.lock()
        connections[connectionID] = connection
        connectionBuffers[connectionID] = Data()
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
        let wasWebSocket = webSocketConnections.removeValue(forKey: id) != nil
        connectionTokens.removeValue(forKey: id)
        connectionBuffers.removeValue(forKey: id)
        let count = webSocketConnections.count
        lock.unlock()

        if wasWebSocket {
            DispatchQueue.main.async { [weak self] in
                self?.onClientCountChanged?(count)
            }
        }
    }

    private func receiveLoop(connection: NWConnection, id: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
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
        let isWebSocket = webSocketConnections[id] != nil
        if isWebSocket {
            lock.unlock()
            handleWebSocketMessage(data, connection: connection, id: id)
            return
        }

        connectionBuffers[id, default: Data()].append(data)
        guard let accumulated = connectionBuffers[id] else {
            lock.unlock()
            return
        }
        lock.unlock()

        // Locate HTTP header boundary without decoding binary body as UTF-8
        let crlfCrlf = Data([13, 10, 13, 10])
        let lfLf = Data([10, 10])
        let headerDelimiterRange: Range<Data.Index>
        if let r = accumulated.range(of: crlfCrlf) {
            headerDelimiterRange = r
        } else if let r = accumulated.range(of: lfLf) {
            headerDelimiterRange = r
        } else {
            // Still waiting for complete headers
            return
        }

        let headerData = accumulated[accumulated.startIndex..<headerDelimiterRange.lowerBound]
        guard let headersPart = String(data: headerData, encoding: .utf8) ?? String(data: headerData, encoding: .ascii) else {
            return
        }

        // WebSocket Upgrade
        if headersPart.lowercased().contains("upgrade: websocket") {
            lock.lock()
            connectionBuffers.removeValue(forKey: id)
            lock.unlock()
            handleWebSocketHandshake(requestString: headersPart, connection: connection, id: id)
            return
        }

        var expectedContentLength = 0
        var contentType = ""
        var authorizationHeader = ""
        var xFilenameHeader: String? = nil

        for line in headersPart.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    expectedContentLength = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                }
            } else if lower.hasPrefix("content-type:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    contentType = parts[1].trimmingCharacters(in: .whitespaces)
                }
            } else if lower.hasPrefix("authorization:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let val = parts[1].trimmingCharacters(in: .whitespaces)
                    if val.lowercased().hasPrefix("bearer ") {
                        authorizationHeader = String(val.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                    } else {
                        authorizationHeader = val
                    }
                }
            } else if lower.hasPrefix("x-filename:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let rawName = parts[1].trimmingCharacters(in: .whitespaces)
                    xFilenameHeader = rawName.removingPercentEncoding ?? rawName
                }
            }
        }

        let bodyStartIndex = headerDelimiterRange.upperBound
        let availableBodyBytes = accumulated.endIndex - bodyStartIndex
        guard availableBodyBytes >= expectedContentLength else {
            // Still waiting for full body payload
            return
        }

        let bodyEndIndex = bodyStartIndex + expectedContentLength
        let bodyData = accumulated[bodyStartIndex..<bodyEndIndex]

        lock.lock()
        let remainingBytes = accumulated[bodyEndIndex...]
        if remainingBytes.isEmpty {
            connectionBuffers.removeValue(forKey: id)
        } else {
            connectionBuffers[id] = Data(remainingBytes)
        }
        lock.unlock()

        let requestLine = headersPart.components(separatedBy: .newlines).first ?? ""

        // HTTP GET /
        if requestLine.hasPrefix("GET / ") || requestLine.hasPrefix("GET /index.html") {
            let htmlData = Data(MobileWebPortal.htmlContent.utf8)
            sendHTTPResponse(data: htmlData, contentType: "text/html; charset=utf-8", connection: connection, id: id)
            return
        }

        // HTTP POST /api/pair
        if requestLine.hasPrefix("POST /api/pair") {
            let bodyPart = String(data: bodyData, encoding: .utf8) ?? ""
            handlePairingRequest(body: bodyPart, connection: connection, id: id)
            return
        }

        // HTTP POST /api/clipboard
        if requestLine.hasPrefix("POST /api/clipboard") {
            let bodyPart = String(data: bodyData, encoding: .utf8) ?? ""
            handlePostClipboard(body: bodyPart, connection: connection, id: id)
            return
        }

        // HTTP GET /api/clipboard
        if requestLine.hasPrefix("GET /api/clipboard") {
            handleGetClipboard(connection: connection, id: id)
            return
        }

        // HTTP POST /api/upload
        if requestLine.hasPrefix("POST /api/upload") {
            handleUploadRequest(
                bodyData: Data(bodyData),
                contentType: contentType,
                authToken: authorizationHeader,
                xFilename: xFilenameHeader,
                connection: connection,
                id: id
            )
            return
        }

        // Fallback 404
        sendHTTPResponse(
            data: Data("404 Not Found".utf8),
            statusCode: 404,
            contentType: "text/plain",
            connection: connection,
            id: id
        )
    }

    private func handleUploadRequest(
        bodyData: Data,
        contentType: String,
        authToken: String,
        xFilename: String?,
        connection: NWConnection,
        id: UUID
    ) {
        let activeSessions = securityManager.activeSessionsList()
        if !activeSessions.isEmpty && !securityManager.authorizeToken(authToken) {
            sendHTTPResponse(
                data: Data("{\"error\":\"Unauthorized: Invalid or missing token\"}".utf8),
                statusCode: 403,
                contentType: "application/json",
                connection: connection,
                id: id
            )
            return
        }

        let fallbackName = xFilename ?? "upload_\(Int(Date().timeIntervalSince1970))"
        guard let upload = MultipartParser.parse(body: bodyData, contentType: contentType, defaultFilename: fallbackName),
              !upload.data.isEmpty else {
            sendHTTPResponse(
                data: Data("{\"error\":\"No file content received\"}".utf8),
                statusCode: 400,
                contentType: "application/json",
                connection: connection,
                id: id
            )
            return
        }

        let rawName = !upload.filename.isEmpty ? upload.filename : fallbackName
        let safeFilename = sanitizeFilename(rawName)
        let destinationURL = getDestinationURL(for: safeFilename)

        do {
            try upload.data.write(to: destinationURL, options: .atomic)
            let savedFilename = destinationURL.lastPathComponent

            DispatchQueue.main.async { [weak self] in
                self?.onFileReceived?(savedFilename, destinationURL)
            }

            let respJson: [String: Any] = [
                "status": "ok",
                "filename": savedFilename,
                "path": destinationURL.path,
                "size": upload.data.count
            ]
            let respData = (try? JSONSerialization.data(withJSONObject: respJson)) ?? Data("{\"status\":\"ok\"}".utf8)
            sendHTTPResponse(data: respData, statusCode: 200, contentType: "application/json", connection: connection, id: id)
        } catch {
            print("[AirBridgeServer] Failed to save file: \(error)")
            sendHTTPResponse(
                data: Data("{\"error\":\"Failed to save file on Mac: \(error.localizedDescription)\"}".utf8),
                statusCode: 500,
                contentType: "application/json",
                connection: connection,
                id: id
            )
        }
    }

    private func sanitizeFilename(_ filename: String) -> String {
        var clean = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("\"") && clean.hasSuffix("\"") && clean.count >= 2 {
            clean = String(clean.dropFirst().dropLast())
        }
        let url = URL(fileURLWithPath: clean)
        var name = url.lastPathComponent
        name = name.replacingOccurrences(of: "/", with: "_")
        name = name.replacingOccurrences(of: "\\", with: "_")
        name = name.replacingOccurrences(of: "..", with: "_")
        name = name.replacingOccurrences(of: "\0", with: "")
        if name.isEmpty || name == "." || name == ".." {
            name = "upload_\(Int(Date().timeIntervalSince1970))"
        }
        return name
    }

    private func getDestinationURL(for filename: String) -> URL {
        let baseDir: URL
        if let custom = customDownloadDirectory {
            baseDir = custom
        } else if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            baseDir = downloads
        } else {
            baseDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        }

        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        let targetURL = baseDir.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: targetURL.path) {
            return targetURL
        }

        let ext = targetURL.pathExtension
        let baseName = targetURL.deletingPathExtension().lastPathComponent
        var counter = 1
        while true {
            let candidateName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            let candidateURL = baseDir.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }

    private func handlePairingRequest(body: String, connection: NWConnection, id: UUID) {
        guard let bodyData = body.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let pin = json["pin"] as? String else {
            sendHTTPResponse(data: Data("{\"error\":\"Invalid request\"}".utf8), statusCode: 400, contentType: "application/json", connection: connection, id: id)
            return
        }

        let deviceName = (json["deviceName"] as? String) ?? "Remote Device"
        let deviceType = (json["deviceType"] as? String) ?? "Unknown"
        let ip = "Remote"

        let result = securityManager.registerDevice(deviceName: deviceName, deviceType: deviceType, ipAddress: ip, pin: pin)

        let respJson: [String: Any] = [
            "authorized": result.authorized,
            "token": result.session?.token ?? ""
        ]
        let respData = (try? JSONSerialization.data(withJSONObject: respJson)) ?? Data()
        sendHTTPResponse(data: respData, statusCode: result.authorized ? 200 : 403, contentType: "application/json", connection: connection, id: id)
    }

    private func handlePostClipboard(body: String, connection: NWConnection, id: UUID) {
        guard let bodyData = body.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let content = json["content"] as? String else {
            sendHTTPResponse(data: Data("{\"error\":\"Bad request\"}".utf8), statusCode: 400, contentType: "application/json", connection: connection, id: id)
            return
        }

        let typeStr = (json["type"] as? String) ?? "text"
        let type: ClipboardType = (typeStr == "url") ? .url : ((typeStr == "image") ? .image : .text)
        let item = ClipboardItem(type: type, content: content, sourceDevice: "Remote")

        self.latestItem = item
        self.onClientPushedItem?(item)
        self.broadcastClipboardItem(item: item)

        sendHTTPResponse(data: Data("{\"status\":\"ok\"}".utf8), contentType: "application/json", connection: connection, id: id)
    }

    private func handleGetClipboard(connection: NWConnection, id: UUID) {
        if let item = latestItem, let data = try? JSONEncoder().encode(item) {
            sendHTTPResponse(data: data, contentType: "application/json", connection: connection, id: id)
        } else {
            sendHTTPResponse(data: Data("{}".utf8), contentType: "application/json", connection: connection, id: id)
        }
    }

    private func handleWebSocketHandshake(requestString: String, connection: NWConnection, id: UUID) {
        guard let keyLine = requestString.components(separatedBy: "\r\n").first(where: {
            $0.lowercased().hasPrefix("sec-websocket-key:")
        }) else { return }

        let key = keyLine.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data((key + magic).utf8))
        let acceptKey = Data(digest).base64EncodedString()

        let handshakeResponse = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(acceptKey)\r\n\r\n"

        connection.send(content: Data(handshakeResponse.utf8), completion: .contentProcessed { [weak self] error in
            guard let self = self, error == nil else { return }
            self.lock.lock()
            self.webSocketConnections[id] = connection
            let count = self.webSocketConnections.count
            self.lock.unlock()

            DispatchQueue.main.async {
                self.onClientCountChanged?(count)
            }

            // Send current item upon connection if exists
            if let item = self.latestItem, let itemData = try? JSONEncoder().encode(item), let text = String(data: itemData, encoding: .utf8) {
                self.sendWebSocketText(text, to: connection)
            }
        })
    }

    private func handleWebSocketMessage(_ data: Data, connection: NWConnection, id: UUID) {
        // RFC 6455 frame decoding for text message
        guard data.count >= 2 else { return }
        let isMasked = (data[1] & 0x80) != 0
        var payloadLen = Int(data[1] & 0x7F)
        var offset = 2

        if payloadLen == 126 {
            guard data.count >= 4 else { return }
            payloadLen = Int(data[2]) << 8 | Int(data[3])
            offset = 4
        } else if payloadLen == 127 {
            guard data.count >= 10 else { return }
            offset = 10
        }

        var mask = [UInt8]()
        if isMasked {
            guard data.count >= offset + 4 else { return }
            mask = Array(data[offset..<offset+4])
            offset += 4
        }

        guard data.count >= offset + payloadLen else { return }
        var payload = Array(data[offset..<offset+payloadLen])
        if isMasked {
            for i in 0..<payload.count {
                payload[i] ^= mask[i % 4]
            }
        }

        if let text = String(bytes: payload, encoding: .utf8),
           let jsonData = text.data(using: .utf8),
           let item = try? JSONDecoder().decode(ClipboardItem.self, from: jsonData) {
            self.latestItem = item
            self.onClientPushedItem?(item)
            self.broadcastClipboardItem(item: item, excluding: id)
        }
    }

    public func broadcastClipboardItem(item: ClipboardItem, excluding: UUID? = nil) {
        self.latestItem = item
        guard let jsonData = try? JSONEncoder().encode(item),
              let jsonText = String(data: jsonData, encoding: .utf8) else { return }

        lock.lock()
        let clients = webSocketConnections
        lock.unlock()

        for (id, conn) in clients {
            if let excluding = excluding, id == excluding { continue }
            sendWebSocketText(jsonText, to: conn)
        }
    }

    private func sendWebSocketText(_ text: String, to connection: NWConnection) {
        let payload = Data(text.utf8)
        var header = Data()
        header.append(0x81) // FIN + Text opcode

        if payload.count < 126 {
            header.append(UInt8(payload.count))
        } else if payload.count <= 65535 {
            header.append(126)
            var len16 = UInt16(payload.count).bigEndian
            withUnsafeBytes(of: &len16) { header.append(contentsOf: $0) }
        } else {
            header.append(127)
            var len64 = UInt64(payload.count).bigEndian
            withUnsafeBytes(of: &len64) { header.append(contentsOf: $0) }
        }

        var packet = header
        packet.append(payload)
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }

    private func sendHTTPResponse(
        data: Data,
        statusCode: Int = 200,
        contentType: String,
        connection: NWConnection,
        id: UUID
    ) {
        let statusPhrase: String
        switch statusCode {
        case 200: statusPhrase = "OK"
        case 400: statusPhrase = "Bad Request"
        case 403: statusPhrase = "Forbidden"
        case 404: statusPhrase = "Not Found"
        default: statusPhrase = "OK"
        }

        let headers = "HTTP/1.1 \(statusCode) \(statusPhrase)\r\nContent-Type: \(contentType)\r\nContent-Length: \(data.count)\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        var responseData = Data(headers.utf8)
        responseData.append(data)
        connection.send(content: responseData, completion: .contentProcessed { [weak self] _ in
            self?.removeConnection(id: id)
        })
    }
}
