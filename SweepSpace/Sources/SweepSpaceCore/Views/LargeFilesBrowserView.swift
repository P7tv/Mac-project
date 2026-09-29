import SwiftUI

public struct LargeFilesBrowserView: View {
    @ObservedObject var viewModel: SweepSpaceViewModel

    public init(viewModel: SweepSpaceViewModel) {
        self.viewModel = viewModel
    }

    private let sizeThresholds: [(label: String, bytes: Int64)] = [
        ("> 100 MB", 100 * 1024 * 1024),
        ("> 500 MB", 500 * 1024 * 1024),
        ("> 1 GB", 1024 * 1024 * 1024)
    ]

    public var body: some View {
        VStack(spacing: 12) {
            // Filters bar
            HStack(spacing: 12) {
                // Size threshold pills
                HStack(spacing: 6) {
                    ForEach(sizeThresholds, id: \.bytes) { item in
                        Button {
                            viewModel.largeFileSizeFilter = item.bytes
                        } label: {
                            Text(item.label)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(viewModel.largeFileSizeFilter == item.bytes ? Color.orange : Color.primary.opacity(0.06))
                                .foregroundColor(viewModel.largeFileSizeFilter == item.bytes ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().frame(height: 18)

                // Type filter pills
                HStack(spacing: 6) {
                    Button {
                        viewModel.largeFileTypeFilter = nil
                    } label: {
                        Text("All Types")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(viewModel.largeFileTypeFilter == nil ? Color.blue : Color.primary.opacity(0.06))
                            .foregroundColor(viewModel.largeFileTypeFilter == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(LargeFileType.allCases) { type in
                        Button {
                            viewModel.largeFileTypeFilter = type
                        } label: {
                            Text(type.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(viewModel.largeFileTypeFilter == type ? Color.blue : Color.primary.opacity(0.06))
                                .foregroundColor(viewModel.largeFileTypeFilter == type ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Selection helpers
                if !viewModel.filteredLargeFiles.isEmpty {
                    Button("Select All") {
                        for item in viewModel.filteredLargeFiles {
                            viewModel.selectedItemIDs.insert(item.id)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))

            // File items
            if viewModel.filteredLargeFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No large files matching current filters.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.filteredLargeFiles) { item in
                            CleanableItemRowView(
                                item: item,
                                isSelected: viewModel.isSelected(item.id),
                                onToggle: {
                                    viewModel.toggleSelection(for: item.id)
                                },
                                onReveal: {
                                    viewModel.revealInFinder(url: item.path)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
