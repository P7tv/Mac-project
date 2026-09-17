import SwiftUI
import UniformTypeIdentifiers

public struct DropZoneView: View {
    @ObservedObject var viewModel: ConversionViewModel
    @State private var isTargeted: Bool = false
    @State private var isFileImporterPresented: Bool = false

    public init(viewModel: ConversionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 1.5, dash: [8, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
                )
                .animation(.easeInOut(duration: 0.2), value: isTargeted)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isTargeted ? [Color.blue, Color.purple] : [Color.blue.opacity(0.7), Color.teal.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.blue.opacity(isTargeted ? 0.5 : 0.2), radius: 10, y: 4)

                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(isTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
                }

                VStack(spacing: 4) {
                    Text(isTargeted ? "Release to Convert!" : "Drag & Drop Images Here")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("PNG, JPEG, WebP, HEIC, TIFF, BMP, or whole folders")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Button {
                    isFileImporterPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Browse Files")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.blue)
            }
            .padding(24)
        }
        .frame(minHeight: 180)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.addFiles(urls: urls)
            case .failure:
                break
            }
        }
    }

    private final class DroppedURLCollector: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var urls: [URL] = []
        func append(_ url: URL) {
            lock.lock()
            defer { lock.unlock() }
            urls.append(url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        let collector = DroppedURLCollector()
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    collector.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !collector.urls.isEmpty {
                viewModel.addFiles(urls: collector.urls)
            }
        }
    }
}
