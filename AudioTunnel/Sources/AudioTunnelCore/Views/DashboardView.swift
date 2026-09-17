import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject public var viewModel: AudioTunnelViewModel

    public init(viewModel: AudioTunnelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Main Scrollable Content
            ScrollView {
                VStack(spacing: 16) {
                    // Permissions Warning Card (if Screen Recording or Mic is missing)
                    if !viewModel.hasScreenCapturePermission && viewModel.sourceMode == .systemAudio {
                        permissionBanner(
                            icon: "lock.shield.fill",
                            title: "ต้องการสิทธิ์ Screen Recording (บันทึกหน้าจอ)",
                            subtitle: "เพื่อให้ macOS อนุญาตให้ AudioTunnel ดักจับเสียงระบบ (System Audio) ส่งไปยังอุปกรณ์อื่นได้",
                            actionTitle: "เปิด System Settings",
                            action: { viewModel.requestScreenCapturePermission() }
                        )
                    }

                    if !viewModel.hasMicrophonePermission && viewModel.sourceMode == .microphone {
                        permissionBanner(
                            icon: "mic.badge.xmark",
                            title: "ต้องการสิทธิ์การเข้าถึงไมโครโฟน (Microphone)",
                            subtitle: "กรุณาอนุญาตให้ AudioTunnel เข้าถึงไมโครโฟนของเครื่อง",
                            actionTitle: "อนุญาตไมโครโฟน",
                            action: { viewModel.requestMicrophonePermission() }
                        )
                    }

                    // Master Control Card
                    masterControlCard

                    // Audio Source & Latency Profile Selector
                    configurationCard

                    // Network Sharing & QR Code Card
                    networkSharingCard

                    // Stream Telemetry & Stats Card
                    telemetryCard
                }
                .padding(20)
            }
        }
        .frame(minWidth: 560, minHeight: 640)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                    .shadow(radius: 8)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast)
            }
        }
        .onAppear {
            viewModel.checkPermissions()
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 2)

                    Image(systemName: "headphones")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AudioTunnel")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Low-Latency Wireless Mac Audio Bridge")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isStreaming ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .shadow(color: viewModel.isStreaming ? Color.green.opacity(0.8) : .clear, radius: 4)

                Text(viewModel.isStreaming ? (viewModel.connectedListeners > 0 ? "Active (\(viewModel.connectedListeners) Listening)" : "Broadcasting (Waiting)") : "Stopped")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(viewModel.isStreaming ? .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(viewModel.isStreaming ? Color.green.opacity(0.12) : Color.primary.opacity(0.04))
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Permission Warning Banner
    private func permissionBanner(icon: String, title: String, subtitle: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
            }

            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                    Text(actionTitle)
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.18))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Master Control Card
    private var masterControlCard: some View {
        VStack(spacing: 16) {
            // Volume Meter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Master Audio Output Level", systemImage: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(viewModel.isStreaming ? "\(Int(viewModel.currentVolumeRMS * 100))%" : "Muted")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.currentVolumeRMS > 0.85 ? .red : .primary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.07))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan, .green, viewModel.currentVolumeRMS > 0.8 ? .orange : .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(min(max(viewModel.currentVolumeRMS, 0.0), 1.0)))
                            .animation(.easeOut(duration: 0.08), value: viewModel.currentVolumeRMS)
                    }
                }
                .frame(height: 12)
            }

            // Big Start / Stop Broadcast Button
            Button(action: {
                viewModel.toggleStreaming()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))

                    Text(viewModel.isStreaming ? "Stop Audio Broadcast" : "Start Audio Broadcast")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    viewModel.isStreaming
                        ? LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(
                    color: (viewModel.isStreaming ? Color.red : Color.blue).opacity(0.35),
                    radius: 10,
                    y: 4
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Configuration Card (Source & Latency)
    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Audio Source Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Source")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(AudioSourceMode.allCases) { mode in
                        Button(action: {
                            viewModel.switchSourceMode(mode)
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(mode.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                viewModel.sourceMode == mode
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.primary.opacity(0.04)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        viewModel.sourceMode == mode
                                            ? Color.accentColor.opacity(0.7)
                                            : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Latency Profile Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Latency Preset (AudioWorklet Buffer)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(viewModel.latencyProfile.localizedDescription)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    ForEach(LatencyProfile.allCases) { profile in
                        Button(action: {
                            viewModel.switchLatencyProfile(profile)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: profile.icon)
                                    .font(.system(size: 11, weight: .bold))
                                Text(profile.rawValue)
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.latencyProfile == profile
                                    ? Color.green.opacity(0.16)
                                    : Color.primary.opacity(0.04)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        viewModel.latencyProfile == profile
                                            ? Color.green.opacity(0.6)
                                            : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Network Sharing & QR Code Card
    private var networkSharingCard: some View {
        HStack(spacing: 16) {
            if let qrImage = viewModel.qrCodeImage {
                Image(nsImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.12), radius: 6)
            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan to Listen on Mobile / PC")
                        .font(.system(size: 12, weight: .semibold))

                    Text("Open any browser on the same Wi-Fi/LAN")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Text(viewModel.webPlayerURL)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.copyPlayerURL()
                    }) {
                        Label("Copy URL", systemImage: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.openInBrowser()
                    }) {
                        Label("Open in Safari", systemImage: "safari")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Telemetry & Stats Card
    private var telemetryCard: some View {
        HStack(spacing: 12) {
            telemetryPill(title: "Active Listeners", value: "\(viewModel.connectedListeners)", icon: "person.wave.2.fill")
            telemetryPill(title: "Broadcast Uptime", value: viewModel.uptimeFormatted, icon: "timer")
            telemetryPill(title: "Server Port", value: "\(viewModel.port)", icon: "network")
        }
    }

    private func telemetryPill(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
    }
}
