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
        VStack(spacing: 12) {
            CategoryRowView(viewModel: viewModel, category: .developerJunk)

            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))

                Text("Developer junk (such as Xcode DerivedData, SPM caches, and npm caches) can consume tens of gigabytes. Deleting them is safe—your projects will rebuild them cleanly on next build.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.08)))
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
