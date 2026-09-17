import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class AirBridgeViewModel: ObservableObject {
    @Published public var isRunning: Bool = false
    @Published public var currentPIN: String = ""
    @Published public var recentItems: [ClipboardItem] = []
    @Published public var connectedClients: Int = 0
    @Published public var connectionURL: String = ""
    @Published public var qrCodeImage: NSImage? = nil
    @Published public var toastMessage: String? = nil

    public let port: UInt16 = 5050
    private let server: AirBridgeServer
    private let watcher: ClipboardWatcher
    private let securityManager: SecurityManager

    public init() {
        let security = SecurityManager()
        self.securityManager = security
        self.currentPIN = security.currentPIN
        self.server = AirBridgeServer(port: port, securityManager: security)
        self.watcher = ClipboardWatcher()

        setupCallbacks()
        detectConnectionURL()
        startServices()
    }

    private func detectConnectionURL() {
        // Detect local Wi-Fi IP
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
                            let ip = String(cString: hostname)
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

        self.connectionURL = "http://\(address):\(port)"
        self.qrCodeImage = QRCodeHelper.generateQRCode(from: connectionURL, size: 160)
    }

    private func setupCallbacks() {
        // When local Mac clipboard changes -> broadcast over Wi-Fi
        watcher.onNewItem = { [weak self] item in
            Task { @MainActor in
                self?.addItemToHistory(item)
                self?.server.broadcastClipboardItem(item: item)
            }
        }

        // When remote phone/PC pushes item -> copy to Mac clipboard
        server.onClientPushedItem = { [weak self] item in
            Task { @MainActor in
                self?.addItemToHistory(item)
                self?.watcher.copyToPasteboard(item: item)
                self?.showToast("📥 Received from \(item.sourceDevice)")
            }
        }

        server.onClientCountChanged = { [weak self] count in
            Task { @MainActor in
                self?.connectedClients = count
            }
        }
    }

    public func startServices() {
        do {
            try server.start()
            watcher.startObserving()
            isRunning = true
        } catch {
            print("[AirBridgeViewModel] Failed to start: \(error)")
        }
    }

    public func stopServices() {
        watcher.stopObserving()
        server.stop()
        isRunning = false
    }

    public func generateNewPIN() {
        let pin = securityManager.generateNewPIN()
        self.currentPIN = pin
        showToast("🔑 New PIN: \(pin)")
    }

    public func copyPINToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentPIN, forType: .string)
        showToast("📋 PIN copied: \(currentPIN)")
    }

    public func copyURLToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(connectionURL, forType: .string)
        showToast("🔗 URL copied to clipboard")
    }

    public func copyItemToMac(_ item: ClipboardItem) {
        watcher.copyToPasteboard(item: item)
        showToast("📋 Copied to Mac Clipboard")
    }

    public func addItemToHistory(_ item: ClipboardItem) {
        // Prevent duplicate consecutive items
        if recentItems.first?.hash == item.hash { return }
        recentItems.insert(item, at: 0)
        if recentItems.count > 15 {
            recentItems.removeLast()
        }
    }

    public func clearHistory() {
        recentItems.removeAll()
        showToast("🗑️ History cleared")
    }

    public func showToast(_ message: String) {
        self.toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }
}
