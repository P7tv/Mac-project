import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var viewModel: AirBridgeViewModel
    @State private var isTargetedForDrop: Bool = false

    public init(viewModel: AirBridgeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                    Text("🌉")
                        .font(.system(size: 15))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("AirBridge")
                        .font(.system(size: 14, weight: .bold))
                    Text("Universal Wireless Clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status Badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.connectedClients > 0 ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(viewModel.connectedClients > 0 ? "\(viewModel.connectedClients) connected" : "Ready")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(viewModel.connectedClients > 0 ? .green : .orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    // QR Code & Pairing Section
                    HStack(spacing: 14) {
                        if let qr = viewModel.qrCodeImage {
                            Image(nsImage: qr)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 90, height: 90)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Scan with Phone Camera")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Button {
                                viewModel.copyURLToClipboard()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                    Text(viewModel.connectionURL)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            // 4-Digit Security PIN Badge
                            HStack(spacing: 6) {
                                Text("PIN:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)

                                Text(viewModel.currentPIN)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.15)))

                                Button {
                                    viewModel.generateNewPIN()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Generate New PIN")
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))

                    // Drop Zone Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isTargetedForDrop ? Color.blue : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .background(RoundedRectangle(cornerRadius: 10).fill(isTargetedForDrop ? Color.blue.opacity(0.08) : Color.primary.opacity(0.02)))

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text("Drop file here to send to Windows / Phone")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url {
                                Task { @MainActor in
                                    let item = ClipboardItem(
                                        type: .file,
                                        content: url.path,
                                        previewText: "File: \(url.lastPathComponent)",
                                        fileSize: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                                    )
                                    viewModel.addItemToHistory(item)
                                    viewModel.showToast("📤 Shared \(url.lastPathComponent)")
                                }
                            }
                        }
                        return true
                    }

                    // Recent Clipboard Feed
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Recent Clipboard Items")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if !viewModel.recentItems.isEmpty {
                                Button("Clear") {
                                    viewModel.clearHistory()
                                }
                                .font(.system(size: 10))
                                .buttonStyle(.plain)
                                .foregroundColor(.red.opacity(0.8))
                            }
                        }

                        if viewModel.recentItems.isEmpty {
                            HStack {
                                Spacer()
                                Text("No clipboard items yet. Copy anything on Mac!")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 14)
                                Spacer()
                            }
                        } else {
                            ForEach(viewModel.recentItems) { item in
                                ClipboardItemRow(item: item) {
                                    viewModel.copyItemToMac(item)
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }

            // Toast Alert Banner
            if let toast = viewModel.toastMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
            }

            Divider()

            // Bottom Footer
            HStack {
                Button("Preferences...") {
                    // Settings placeholder
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button("Quit AirBridge") {
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
        .frame(width: 360, height: 460)
        .background(.ultraThinMaterial)
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: item.type))
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .frame(width: 16)

            Text(item.previewText)
                .font(.system(size: 11))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onCopy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to Mac Clipboard")
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }

    private func iconName(for type: ClipboardType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}
