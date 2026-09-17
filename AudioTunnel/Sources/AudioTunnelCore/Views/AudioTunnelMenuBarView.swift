import SwiftUI
import AppKit

public struct AudioTunnelMenuBarView: View {
    @ObservedObject public var viewModel: AudioTunnelViewModel

    public init(viewModel: AudioTunnelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView

            // Live Volume Meter
            volumeMeterView

            // Source Mode Picker
            sourceModePicker

            // Web Broadcast Card
            webBroadcastCard

            // Master Start / Stop Button
            broadcastToggleButton

            // Footer
            footerView
        }
        .padding(18)
        .frame(width: 330)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                    .shadow(radius: 6)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast)
            }
        }
    }

    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "headphones")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("AudioTunnel")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }

            Spacer()

            // Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isStreaming ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .shadow(color: viewModel.isStreaming ? Color.green.opacity(0.8) : .clear, radius: 4)

                Text(viewModel.isStreaming ? "\(viewModel.connectedListeners) Listening" : "Idle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(viewModel.isStreaming ? .green : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(12)
        }
    }

    private var volumeMeterView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Audio Output Level")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text(viewModel.isStreaming ? "\(Int(viewModel.currentVolumeRMS * 100))%" : "Muted")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.currentVolumeRMS > 0.85 ? .red : .primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.08))

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
            .frame(height: 10)
        }
    }

    private var sourceModePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audio Source")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(AudioSourceMode.allCases) { mode in
                    Button(action: {
                        viewModel.switchSourceMode(mode)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.sourceMode == mode
                                ? Color.accentColor.opacity(0.2)
                                : Color.primary.opacity(0.05)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    viewModel.sourceMode == mode
                                        ? Color.accentColor.opacity(0.6)
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

    private var webBroadcastCard: some View {
        VStack(spacing: 10) {
            if let qrImage = viewModel.qrCodeImage {
                Image(nsImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.12), radius: 6)
            }

            VStack(spacing: 2) {
                Text("Scan or open on Windows / Phone")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Text(viewModel.webPlayerURL)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }

            HStack(spacing: 8) {
                Button(action: {
                    viewModel.copyPlayerURL()
                }) {
                    Label("Copy Link", systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let url = URL(string: viewModel.webPlayerURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("Open", systemImage: "safari")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var broadcastToggleButton: some View {
        Button(action: {
            viewModel.toggleStreaming()
        }) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isStreaming ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))

                Text(viewModel.isStreaming ? "Stop Broadcasting" : "Start Broadcasting")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                viewModel.isStreaming
                    ? LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(14)
            .shadow(
                color: (viewModel.isStreaming ? Color.red : Color.blue).opacity(0.35),
                radius: 8,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    private var footerView: some View {
        HStack {
            Text("Port \(viewModel.port) • Zero Cloud")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
        }
    }
}

public struct VisualEffectView: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode

    public init(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    public func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
