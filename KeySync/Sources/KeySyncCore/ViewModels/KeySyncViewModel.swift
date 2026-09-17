import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class KeySyncViewModel: ObservableObject {
    @Published public var isRunning: Bool = false
    @Published public var isClientConnected: Bool = false
    @Published public var isControllingRemote: Bool = false
    @Published public var selectedEdge: ScreenEdge = .right {
        didSet {
            interceptor.updateEdge(selectedEdge)
        }
    }
    @Published public var localIP: String = "127.0.0.1"

    public let port: UInt16 = 6060
    private let server: KeySyncServer
    private let interceptor: EventInterceptor
    private var globalMonitor: Any?

    public init() {
        self.server = KeySyncServer(port: port)
        self.interceptor = EventInterceptor(edge: .right)

        detectLocalIP()
        setupCallbacks()
        startServer()
    }

    private func detectLocalIP() {
        var address = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                let flags = Int32(ptr!.pointee.ifa_flags)
                let addr = ptr!.pointee.ifa_addr.pointee
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(ptr!.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let ip = String(decoding: hostname.map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: ["\0"])
                            if ip != "127.0.0.1" && !ip.hasPrefix("169.254.") {
                                address = ip
                                break
                            }
                        }
                    }
                }
                ptr = ptr!.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        self.localIP = address
    }

    private func setupCallbacks() {
        server.onClientConnected = { [weak self] connected in
            Task { @MainActor in
                self?.isClientConnected = connected
            }
        }

        interceptor.onControlStateChanged = { [weak self] controlling in
            Task { @MainActor in
                self?.isControllingRemote = controlling
            }
        }

        interceptor.onEventIntercepted = { [weak self] event in
            self?.server.sendEvent(event)
        }
    }

    public func startServer() {
        do {
            try server.start()
            startMouseTracking()
            isRunning = true
        } catch {
            print("[KeySyncViewModel] Error: \(error)")
        }
    }

    public func stopServer() {
        stopMouseTracking()
        server.stop()
        isRunning = false
    }

    private func startMouseTracking() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            let point = NSEvent.mouseLocation
            Task { @MainActor in
                self?.interceptor.handleMouseMoved(to: point)
            }
        }
    }

    private func stopMouseTracking() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    public func panicRelease() {
        interceptor.triggerPanicRelease()
    }
}
