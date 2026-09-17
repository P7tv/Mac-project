import Foundation
import Network

public final class KeySyncServer: @unchecked Sendable {
    private var listener: NWListener?
    public let port: UInt16
    private var activeConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.keysync.server", qos: .userInteractive)
    private let lock = NSLock()

    public private(set) var isRunning: Bool = false
    public var onClientConnected: (@Sendable (Bool) -> Void)?
    public var onRemoteEventReceived: (@Sendable (InputEvent) -> Void)?

    public init(port: UInt16 = 6060) {
        self.port = port
    }

    public var isClientConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeConnection != nil
    }

    public func start() throws {
        guard !isRunning else { return }

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let params = NWParameters(tls: nil, tcp: tcp)
        params.allowLocalEndpointReuse = true
        params.serviceClass = .interactiveVideo

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "KeySyncServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }

        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[KeySyncServer] Listening on port \(self?.port ?? 6060)")
            case .failed(let err):
                print("[KeySyncServer] Listener failed: \(err)")
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
        activeConnection?.cancel()
        activeConnection = nil
        onClientConnected?(false)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        lock.lock()
        activeConnection?.cancel()
        activeConnection = connection
        lock.unlock()

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onClientConnected?(true)
                self?.receiveLoop(connection: connection)
            case .failed, .cancelled:
                self?.lock.lock()
                if self?.activeConnection === connection {
                    self?.activeConnection = nil
                }
                self?.lock.unlock()
                self?.onClientConnected?(false)
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func receiveLoop(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            if let data = content, let event = try? JSONDecoder().decode(InputEvent.self, from: data) {
                self.onRemoteEventReceived?(event)
            }
            if isComplete || error != nil {
                connection.cancel()
                self.lock.lock()
                if self.activeConnection === connection {
                    self.activeConnection = nil
                }
                self.lock.unlock()
                self.onClientConnected?(false)
            } else {
                self.receiveLoop(connection: connection)
            }
        }
    }

    public func sendEvent(_ event: InputEvent) {
        lock.lock()
        guard let conn = activeConnection else {
            lock.unlock()
            return
        }
        lock.unlock()

        guard var data = try? JSONEncoder().encode(event) else { return }
        data.append(0x0A) // Newline delimiter
        conn.send(content: data, completion: .contentProcessed { _ in })
    }
}
