import SwiftUI
import AppKit

public struct KeySyncMenuBarView: View {
    @ObservedObject var viewModel: KeySyncViewModel

    public init(viewModel: KeySyncViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                    Text("⌨️")
                        .font(.system(size: 15))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("KeySync")
                        .font(.system(size: 14, weight: .bold))
                    Text("Universal Mouse & Keyboard")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isClientConnected ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(viewModel.isClientConnected ? (viewModel.isControllingRemote ? "Controlling PC" : "PC Connected") : "Waiting for PC")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(viewModel.isClientConnected ? .green : .orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))

            Divider()

            VStack(spacing: 12) {
                // Interactive Screen Arrangement
                VStack(alignment: .leading, spacing: 6) {
                    Text("Screen Edge Arrangement")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        // Mac Screen
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 100, height: 65)
                                .overlay(
                                    VStack(spacing: 2) {
                                        Image(systemName: "laptopcomputer")
                                            .font(.system(size: 16))
                                        Text("Mac")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundColor(.blue)
                                )
                        }

                        // Arrow
                        Image(systemName: "arrow.left.and.right")
                            .foregroundColor(.secondary)

                        // Windows Screen
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 100, height: 65)
                                .overlay(
                                    VStack(spacing: 2) {
                                        Image(systemName: "display")
                                            .font(.system(size: 16))
                                        Text("Windows")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundColor(.purple)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))

                // Edge Selector
                HStack(spacing: 6) {
                    Text("Glide Edge:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.selectedEdge) {
                        ForEach(ScreenEdge.allCases) { edge in
                            Text(edge.rawValue).tag(edge)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Connection Info Card
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect on Windows:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("\(viewModel.localIP):\(viewModel.port)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                        Spacer()
                        Text("Port \(viewModel.port)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple.opacity(0.08)))

                // Emergency Panic Unlock
                if viewModel.isControllingRemote {
                    Button {
                        viewModel.panicRelease()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                            Text("Release Mouse to Mac (Esc)")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.2)))
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)

            Divider()

            // Footer
            HStack {
                Text("Zero-lag Local Wi-Fi")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit KeySync") {
                    NSApp.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.red.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 330, height: 320)
        .background(.ultraThinMaterial)
    }
}
