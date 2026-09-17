import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class DeskExtendViewModel: ObservableObject {
    @Published public var isStreaming: Bool = false
    @Published public var isStarting: Bool = false
    @Published public var selectedResolution: DisplayResolution = .fullHD
    @Published public var targetFPS: Int = 60
    @Published public var streamQuality: Double = 0.6 {
        didSet { captureEngine.updateQuality(streamQuality) }
    }
    @Published public var networkAddresses: [NetworkAddress] = []
    @Published public var connectedClients: Int = 0
    @Published public var latestPreviewImage: NSImage? = nil
    @Published public var activeDisplayID: CGDirectDisplayID? = nil
    @Published public var alertMessage: String? = nil
    @Published public var port: UInt16 = 8080
    @Published public var hasScreenRecordingPermission: Bool = false

    private let virtualDisplayManager = VirtualDisplayManager()
    private let captureEngine = ScreenCaptureEngine()
    private var streamServer: StreamServer?

    public init() {
        refreshNetworkAddresses()
        checkPermissions()
        captureEngine.onCaptureError = { [weak self] error in
            Task { @MainActor in
                self?.stopStreaming()
                self?.checkPermissions()
                self?.alertMessage = "การส่งภาพหยุดทำงาน: \(error.localizedDescription)"
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
                self?.refreshNetworkAddresses()
            }
        }
    }

    public func checkPermissions() {
        self.hasScreenRecordingPermission = ScreenCaptureEngine.hasScreenRecordingPermission()
    }

    public func requestScreenRecordingPermission() {
        ScreenCaptureEngine.requestScreenRecordingPermission()
        ScreenCaptureEngine.openScreenRecordingSettings()
        checkPermissions()
    }

    public func refreshNetworkAddresses() {
        self.networkAddresses = NetworkInterfaceHelper.getLocalIPAddresses(port: port)
        checkPermissions()
    }

    public func toggleStreaming() {
        guard !isStarting else { return }
        if isStreaming {
            stopStreaming()
        } else {
            Task {
                await startStreaming()
            }
        }
    }

    public func startStreaming() async {
        guard !isStreaming, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        alertMessage = nil

        // 1. Request Screen Capture permission if needed
        if !ScreenCaptureEngine.hasScreenRecordingPermission() {
            ScreenCaptureEngine.requestScreenRecordingPermission()
        }
        checkPermissions()

        // 2. Start Virtual Display
        let config = DisplayConfig(
            resolution: selectedResolution,
            refreshRate: Double(targetFPS),
            hiDPI: false,
            displayName: "DeskExtend Display"
        )

        guard let displayID = virtualDisplayManager.start(config: config) else {
            alertMessage = "Failed to create Virtual Display. Check macOS permissions."
            return
        }

        self.activeDisplayID = displayID

        // 3. Start Embedded HTTP & WebSocket Server
        let server = StreamServer(port: port)
        server.onClientCountChanged = { [weak self] count in
            self?.connectedClients = count
        }

        do {
            try server.start()
            self.streamServer = server
        } catch {
            stopStreaming()
            alertMessage = "Failed to start local server on port \(port): \(error.localizedDescription)"
            return
        }

        // 4. Start Screen Capture Engine
        do {
            try await captureEngine.startCapture(
                displayID: displayID,
                fps: targetFPS,
                quality: streamQuality
            ) { [weak self] frameData, preview in
                server.broadcastFrame(imageData: frameData)
                if let preview = preview {
                    DispatchQueue.main.async {
                        self?.latestPreviewImage = preview
                    }
                }
            }
        } catch {
            stopStreaming()
            checkPermissions()
            alertMessage = "เริ่มส่งภาพจอที่สองไม่ได้: \(error.localizedDescription)"
            return
        }

        refreshNetworkAddresses()
        self.isStreaming = true
        self.alertMessage = nil
    }

    public func stopStreaming() {
        captureEngine.stopCapture()
        streamServer?.stop()
        streamServer = nil
        virtualDisplayManager.stop()

        self.activeDisplayID = nil
        self.isStreaming = false
        self.connectedClients = 0
        self.latestPreviewImage = nil
    }

    public func openDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    public func copyURLToClipboard(url: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url, forType: .string)
    }
}
