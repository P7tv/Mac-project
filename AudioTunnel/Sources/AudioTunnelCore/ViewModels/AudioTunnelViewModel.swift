import Foundation
import SwiftUI
import AppKit
import Combine
import AVFoundation

@MainActor
public final class AudioTunnelViewModel: ObservableObject, AudioCaptureEngineDelegate, AudioStreamServerDelegate {
    @Published public var isStreaming: Bool = false
    @Published public var sourceMode: AudioSourceMode = .systemAudio
    @Published public var latencyProfile: LatencyProfile = .balanced
    @Published public var connectedListeners: Int = 0
    @Published public var currentVolumeRMS: Float = 0.0
    @Published public var webPlayerURL: String = ""
    @Published public var localIP: String = "127.0.0.1"
    @Published public var qrCodeImage: NSImage? = nil
    @Published public var toastMessage: String? = nil
    @Published public var hasScreenCapturePermission: Bool = true
    @Published public var hasMicrophonePermission: Bool = true
    @Published public var uptimeSeconds: TimeInterval = 0

    public let port: UInt16 = 7070
    private let captureEngine: AudioCaptureEngine
    private let server: AudioStreamServer
    private var uptimeTimer: AnyCancellable?

    public var uptimeFormatted: String {
        let hours = Int(uptimeSeconds) / 3600
        let minutes = (Int(uptimeSeconds) % 3600) / 60
        let seconds = Int(uptimeSeconds) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    public init() {
        self.captureEngine = AudioCaptureEngine()
        self.server = AudioStreamServer(port: 7070)

        self.captureEngine.delegate = self
        self.server.delegate = self

        checkPermissions()
        detectNetworkAddress()
        startServer()
    }

    public func checkPermissions() {
        self.hasScreenCapturePermission = CGPreflightScreenCaptureAccess()
        if #available(macOS 14.0, *) {
            self.hasMicrophonePermission = AVAudioApplication.shared.recordPermission == .granted
        } else {
            self.hasMicrophonePermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    public func requestScreenCapturePermission() {
        CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    public func requestMicrophonePermission() {
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.hasMicrophonePermission = granted
                }
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    public func detectNetworkAddress() {
        var address = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                let flags = Int32(ptr!.pointee.ifa_flags)
                let addr = ptr!.pointee.ifa_addr.pointee
                if (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(ptr!.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let ip = String(decoding: hostname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
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
        self.webPlayerURL = "http://\(address):\(port)"
        self.qrCodeImage = QRCodeHelper.generateQRCode(from: self.webPlayerURL, size: 160)
    }

    public func startServer() {
        do {
            server.currentModeName = sourceMode.rawValue
            try server.start()
        } catch {
            print("[AudioTunnel] Server start error: \(error)")
        }
    }

    public func toggleStreaming() {
        if isStreaming {
            stopStreaming()
        } else {
            startStreaming()
        }
    }

    public func startStreaming() {
        guard !isStreaming else { return }
        checkPermissions()
        Task {
            do {
                try await captureEngine.start(mode: sourceMode)
                self.isStreaming = true
                self.uptimeSeconds = 0
                self.uptimeTimer = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        self?.uptimeSeconds += 1
                    }
                self.showToast("⚡ Streaming \(sourceMode.rawValue)")
            } catch {
                self.showToast("❌ Capture failed: \(error.localizedDescription)")
            }
        }
    }

    public func stopStreaming() {
        guard isStreaming else { return }
        captureEngine.stop()
        uptimeTimer?.cancel()
        uptimeTimer = nil
        self.isStreaming = false
        self.currentVolumeRMS = 0.0
        self.uptimeSeconds = 0
        self.showToast("⏹️ Streaming stopped")
    }

    public func switchSourceMode(_ newMode: AudioSourceMode) {
        guard sourceMode != newMode else { return }
        self.sourceMode = newMode
        server.currentModeName = newMode.rawValue

        if isStreaming {
            stopStreaming()
            startStreaming()
        }
    }

    public func switchLatencyProfile(_ newProfile: LatencyProfile) {
        guard latencyProfile != newProfile else { return }
        self.latencyProfile = newProfile
        showToast("Latency set to \(newProfile.rawValue)")
    }

    public func copyPlayerURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(webPlayerURL, forType: .string)
        showToast("📋 Web Player URL copied!")
    }

    public func openInBrowser() {
        if let url = URL(string: webPlayerURL) {
            NSWorkspace.shared.open(url)
        }
    }

    public func showToast(_ message: String) {
        self.toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }

    // MARK: - AudioCaptureEngineDelegate
    nonisolated public func audioCaptureEngine(didCapturePCMData data: Data, rmsLevel: Float) {
        server.broadcast(pcm16Data: data)
        Task { @MainActor in
            self.currentVolumeRMS = rmsLevel
        }
    }

    nonisolated public func audioCaptureEngine(didFailWithError error: Error) {
        Task { @MainActor in
            self.showToast("⚠️ Audio error: \(error.localizedDescription)")
        }
    }

    // MARK: - AudioStreamServerDelegate
    nonisolated public func audioStreamServer(didUpdateListeners count: Int) {
        Task { @MainActor in
            self.connectedListeners = count
        }
    }
}
