import SwiftUI
import AppKit

public struct ArchiveInspectorView: View {
    @ObservedObject var viewModel: ArchiveViewModel

    public init(viewModel: ArchiveViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Search and Selection bar
            searchAndSelectionBar

            Divider()

            // File Table / Tree
            fileListView

            Divider()

            // Bottom Action & Status Footer
            footerBar
        }
        .sheet(isPresented: $viewModel.isShowingPasswordPrompt) {
            PasswordPromptView(viewModel: viewModel)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.closeArchive()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close archive and return to drop zone")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(viewModel.currentArchive?.archiveName ?? "")
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)

                    if let format = viewModel.currentArchive?.formatName {
                        Text(format.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }

                    if viewModel.currentArchive?.isEncrypted == true {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                            Text("ENCRYPTED")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                    }
                }

                if let archive = viewModel.currentArchive {
                    Text("\(archive.fileCount) files, \(archive.folderCount) folders • Uncompressed: \(archive.formattedTotalUncompressedSize) • Archive: \(archive.formattedArchiveSize)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Destination Picker
            HStack(spacing: 6) {
                Text("Extract To:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("", selection: $viewModel.destinationMode) {
                    ForEach(DestinationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .onChange(of: viewModel.destinationMode) { _, newMode in
                    if newMode == .custom {
                        chooseCustomDestination()
                    }
                }
            }

            // Extract All button
            Button {
                Task {
                    await viewModel.extractAll()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 11))
                    Text("Extract All")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isExtracting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var searchAndSelectionBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Search files by name or extension...", text: $viewModel.searchFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !viewModel.searchFilter.isEmpty {
                    Button {
                        viewModel.searchFilter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )

            // Select all / Deselect all
            HStack(spacing: 8) {
                Button("Select All") {
                    viewModel.selectAll()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Text("•")
                    .foregroundColor(.secondary.opacity(0.4))

                Button("Deselect") {
                    viewModel.deselectAll()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Extract Selected button
            if viewModel.selectedCount > 0 {
                Button {
                    Task {
                        await viewModel.extractSelected()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Extract (\(viewModel.selectedCount))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.1))
                    )
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isExtracting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }

    private var fileListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.filteredEntries) { entry in
                    ArchiveEntryRowView(
                        entry: entry,
                        isSelected: viewModel.isEntrySelected(entry.id),
                        onToggleSelect: {
                            viewModel.toggleSelection(for: entry.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            if viewModel.isExtracting {
                ProgressView()
                    .controlSize(.small)
                Text(viewModel.statusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else if let output = viewModel.extractedOutputURL {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 13))

                Text("Files extracted successfully to \(output.lastPathComponent)")
                    .font(.system(size: 11))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    viewModel.revealExtractedFolder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Reveal in Finder")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            } else {
                Text(viewModel.statusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func chooseCustomDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            viewModel.customDestinationFolder = selectedURL
        } else {
            viewModel.destinationMode = .sameFolder
        }
    }
}
