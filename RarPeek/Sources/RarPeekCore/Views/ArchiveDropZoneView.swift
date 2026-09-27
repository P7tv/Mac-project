import SwiftUI
import UniformTypeIdentifiers
import AppKit

public struct ArchiveDropZoneView: View {
    @ObservedObject var viewModel: ArchiveViewModel
    @State private var isTargeted: Bool = false

    public init(viewModel: ArchiveViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon with glowing effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 75
                        )
                    )
                    .frame(width: 150, height: 150)

                Image(systemName: "doc.zipper")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 5)
                    .scaleEffect(isTargeted ? 1.12 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isTargeted)
            }

            VStack(spacing: 8) {
                Text("Drop RAR Archive Here")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                Text("Inspect contents, search files, or extract seamlessly")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // Browse button
            Button {
                openArchivePicker()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                    Text("Select Archive File...")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            // Supported Format Badges
            HStack(spacing: 8) {
                ForEach(["RAR5", "RAR4", ".part1.rar", "7-Zip", "ZIP", "TAR.GZ", "ISO"], id: \.self) { badge in
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                        )
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.blue : Color.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: isTargeted ? 3 : 1.5, dash: [8, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isTargeted ? Color.blue.opacity(0.05) : Color.clear)
                )
        )
        .padding(20)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let fileURL = url {
                    Task { @MainActor in
                        await viewModel.loadArchive(url: fileURL)
                    }
                }
            }
            return true
        }
    }

    private func openArchivePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "rar") ?? .data,
            UTType(filenameExtension: "7z") ?? .data,
            UTType(filenameExtension: "tar") ?? .data,
            .zip,
            .gzip
        ]

        if panel.runModal() == .OK, let selectedURL = panel.url {
            Task {
                await viewModel.loadArchive(url: selectedURL)
            }
        }
    }
}
