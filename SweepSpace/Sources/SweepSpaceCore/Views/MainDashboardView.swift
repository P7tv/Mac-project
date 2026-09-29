import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable {
    case smartClean = "Smart Clean"
    case largeFiles = "Large Files"
    case developerSpace = "Developer"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .smartClean: return "sparkles"
        case .largeFiles: return "archivebox.fill"
        case .developerSpace: return "hammer.fill"
        }
    }
}

public struct MainDashboardView: View {
    @StateObject private var viewModel = SweepSpaceViewModel()
    @State private var selectedTab: MainTab = .smartClean

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar & Tab Selector
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)

                    Text("SweepSpace")
                        .font(.system(size: 16, weight: .bold))
                }

                Spacer()

                // Mode Tabs
                Picker("", selection: $selectedTab) {
                    ForEach(MainTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Spacer()

                Button {
                    viewModel.startScan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Re-scan Storage")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content Area
            ScrollView {
                VStack(spacing: 16) {
                    // Hero Disk Storage Card
                    DiskHeroCardView(viewModel: viewModel)

                    // Tab Specific Views
                    switch selectedTab {
                    case .smartClean:
                        smartCleanView
                    case .largeFiles:
                        LargeFilesBrowserView(viewModel: viewModel)
                    case .developerSpace:
                        developerSpaceView
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer Status Bar
            footerStatusBar
        }
        .frame(minWidth: 780, minHeight: 620)
        .sheet(isPresented: $viewModel.isShowingCleanSummary) {
            CleanSummaryView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.startScan()
        }
    }

    private var smartCleanView: some View {
        VStack(spacing: 12) {
            CategoryRowView(viewModel: viewModel, category: .systemAndAppCache)
            CategoryRowView(viewModel: viewModel, category: .developerJunk)
            CategoryRowView(viewModel: viewModel, category: .trashAndLeftovers)
            CategoryRowView(viewModel: viewModel, category: .largeAndOldFiles)
        }
    }

    private var developerSpaceView: some View {
        VStack(spacing: 16) {
            // Safety Reassurance Banner
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.purple)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Safe Developer Cleaning")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Your source code is never touched. Only dependencies (node_modules, .build, venv) and tool caches (Gradle, Simulators) are cleaned. You can always run npm i, swift build, or gradle to restore packages.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.08)))

            // Section 1: Project Dependencies (node_modules, .build, venv, target)
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(.orange)
                        Text("Project Dependencies & Artifacts")
                            .font(.system(size: 13, weight: .bold))
                        Text("(\(viewModel.developerProjectDependencyItems.count))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Sub-filter pills
                    HStack(spacing: 6) {
                        let filters: [(label: String, val: String?)] = [
                            ("All", nil),
                            ("node_modules", "node_modules"),
                            (".build (Swift)", ".build"),
                            ("venv (Python)", "venv")
                        ]

                        ForEach(filters, id: \.label) { f in
                            Button {
                                viewModel.developerDependencyFilter = f.val
                            } label: {
                                Text(f.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(viewModel.developerDependencyFilter == f.val ? Color.orange : Color.primary.opacity(0.06))
                                    .foregroundColor(viewModel.developerDependencyFilter == f.val ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    let depBytes = viewModel.developerProjectDependencyItems.reduce(0) { $0 + $1.sizeBytes }
                    Text(ByteCountFormatter.string(fromByteCount: depBytes, countStyle: .file))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.025))

                Divider()

                if viewModel.filteredProjectDependencyItems.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("No project dependencies found matching filter.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                } else {
                    VStack(spacing: 1) {
                        ForEach(viewModel.filteredProjectDependencyItems) { item in
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
                    .padding(.vertical, 6)
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

            // Section 2: Global Tool & Environment Caches
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.purple)
                        Text("Global Package & Tooling Caches")
                            .font(.system(size: 13, weight: .bold))
                        Text("(\(viewModel.developerGlobalCacheItems.count))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    let globalBytes = viewModel.developerGlobalCacheItems.reduce(0) { $0 + $1.sizeBytes }
                    Text(ByteCountFormatter.string(fromByteCount: globalBytes, countStyle: .file))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.025))

                Divider()

                VStack(spacing: 1) {
                    ForEach(viewModel.developerGlobalCacheItems) { item in
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
                .padding(.vertical, 6)
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

    private var footerStatusBar: some View {
        HStack(spacing: 12) {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
            } else {
                Circle()
                    .fill(viewModel.items.isEmpty ? Color.green : Color.blue)
                    .frame(width: 8, height: 8)
            }

            Text(viewModel.scanStatusText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            if !viewModel.items.isEmpty {
                Text("\(viewModel.selectedItems.count) of \(viewModel.items.count) items selected (\(viewModel.formattedSelectedBytes))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Button {
                    Task {
                        await viewModel.cleanSelected(useTrash: true)
                    }
                } label: {
                    Text("Clean Selected")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.selectedBytes == 0 || viewModel.isCleaning)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
