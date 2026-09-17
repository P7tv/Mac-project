import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: DeskExtendViewModel

    public init(viewModel: DeskExtendViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "display.2")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text("DeskExtend")
                            .font(.system(size: 15, weight: .bold))
                        Text("Real-Time Secondary Display")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isStreaming ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .shadow(color: viewModel.isStreaming ? Color.green.opacity(0.8) : .clear, radius: 4)

                    if viewModel.isStreaming {
                        Text(viewModel.connectedClients > 0 ? "Active (\(viewModel.connectedClients) connected)" : "Streaming (Waiting for PC)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text("Stopped")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(viewModel.isStreaming ? Color.green.opacity(0.12) : Color.primary.opacity(0.04))
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Main Content Area
            ScrollView {
                VStack(spacing: 16) {
                    // Start / Stop Main Action Button
                    Button {
                        viewModel.toggleStreaming()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                            Text(viewModel.isStreaming ? "Stop Extended Display" : "Start Extended Display")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    viewModel.isStreaming ?
                                    LinearGradient(colors: [Color.red.opacity(0.85), Color.red], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        )
                        .foregroundColor(.white)
                        .shadow(color: viewModel.isStreaming ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)

                    // Live Screen Preview Area
                    if viewModel.isStreaming {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Live Monitor Preview")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Display ID: \(viewModel.activeDisplayID ?? 0)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.black)
                                    .aspectRatio(16/9, contentMode: .fit)

                                if let preview = viewModel.latestPreviewImage {
                                    Image(nsImage: preview)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    VStack(spacing: 6) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Waiting for display stream...")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
                            )
                        }
                    }

                    // Connection Addresses List
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Open this URL on your Windows PC:")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Button {
                                viewModel.refreshNetworkAddresses()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Refresh IP Addresses")
                        }

                        ForEach(viewModel.networkAddresses) { address in
                            ConnectionCardView(address: address) {
                                viewModel.copyURLToClipboard(url: address.urlString)
                            }
                        }

                        // Helpful Tip Banner
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 13))

                            Text("Tip: On your Windows PC, open Chrome or Edge, enter the URL above, and press **F11** for Fullscreen!")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.yellow.opacity(0.08))
                        )
                    }

                    // Display Resolution & Quality Settings
                    DisplaySettingsBar(viewModel: viewModel)
                }
                .padding(18)
            }

            if let alert = viewModel.alertMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(alert)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
            }
        }
        .background(.ultraThinMaterial)
        .frame(minWidth: 540, minHeight: 580)
    }
}
