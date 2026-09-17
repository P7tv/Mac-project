import SwiftUI
import AppKit

public struct RecallSearchView: View {
    @ObservedObject public var viewModel: QuickRecallViewModel
    public var onClose: (() -> Void)?

    public init(viewModel: QuickRecallViewModel, onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            searchHeaderView

            Divider().opacity(0.15)

            // Content Area (Results List + Detail Inspector)
            if viewModel.searchResults.isEmpty {
                emptyStateView
            } else {
                HStack(spacing: 0) {
                    // Left list of cards
                    resultsListView
                        .frame(width: 340)

                    Divider().opacity(0.15)

                    // Right detail preview
                    detailInspectorView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 840, height: 560)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 30, y: 15)
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
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toast)
            }
        }
    }

    // MARK: - Subviews
    private var searchHeaderView: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.accentColor)

            TextField("Search anything you saw on screen (Thai & English)...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .regular))

            if !viewModel.searchQuery.isEmpty {
                Button(action: {
                    viewModel.searchQuery = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }

            // Close hint
            Text("ESC")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(4)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.primary.opacity(0.03))
    }

    private var resultsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.searchResults) { record in
                        recordRowView(record)
                            .id(record.id)
                            .onTapGesture {
                                viewModel.selectedRecord = record
                            }
                    }
                }
                .padding(8)
            }
        }
    }

    private func recordRowView(_ record: RecallRecord) -> some View {
        let isSelected = viewModel.selectedRecord?.id == record.id
        return HStack(spacing: 10) {
            // Small thumbnail
            if let nsImage = NSImage(contentsOfFile: record.thumbnailPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 36)
                    .cornerRadius(6)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 52, height: 36)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(record.appName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(record.timeAgoDisplay)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Text(record.extractedText.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? AnyShapeStyle(Color.accentColor)
                : AnyShapeStyle(Color.clear)
        )
        .cornerRadius(10)
        .contentShape(Rectangle())
    }

    private var detailInspectorView: some View {
        VStack(spacing: 0) {
            if let record = viewModel.selectedRecord {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header bar inside detail
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.appName)
                                    .font(.system(size: 16, weight: .bold))
                                Text(record.formattedDateTime)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                viewModel.copyText(record.extractedText)
                            }) {
                                Label("Copy Text", systemImage: "doc.on.doc")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.08))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                viewModel.openImageInFinder(record.thumbnailPath)
                            }) {
                                Label("Finder", systemImage: "folder")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.08))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                        // Full Screenshot Preview
                        if let nsImage = NSImage(contentsOfFile: record.thumbnailPath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(radius: 4)
                        }

                        // Extracted OCR Text Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Extracted Text (Apple Silicon Neural OCR)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(record.extractedText.isEmpty ? "(No readable text detected)" : record.extractedText)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                        }
                    }
                    .padding(20)
                }
            } else {
                emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Moments Found")
                .font(.system(size: 16, weight: .semibold))

            Text("Try searching with different keywords or browse recent history.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
