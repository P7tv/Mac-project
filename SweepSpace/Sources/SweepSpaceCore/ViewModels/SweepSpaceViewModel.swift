import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
public final class SweepSpaceViewModel: ObservableObject {
    @Published public var diskInfo: DiskSpaceInfo
    @Published public var items: [CleanableItem] = []
    @Published public var selectedItemIDs: Set<UUID> = []

    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var scanStatusText: String = "Ready to scan"
    @Published public var lastCleanResult: CleanResult? = nil
    @Published public var isShowingCleanSummary: Bool = false

    // Filters for Large Files view
    @Published public var largeFileSizeFilter: Int64 = 100 * 1024 * 1024 // 100MB default
    @Published public var largeFileTypeFilter: LargeFileType? = nil // nil = All
    @Published public var selectedCategoryTab: CleaningCategory = .systemAndAppCache

    private let scanEngine = DiskScanEngine()
    private var scanTask: Task<Void, Never>?

    public init() {
        self.diskInfo = DiskSpaceCalculator.currentDiskSpace()
    }

    public func refreshDiskInfo() {
        let current = DiskSpaceCalculator.currentDiskSpace()
        let recoverable = totalRecoverableBytes
        self.diskInfo = DiskSpaceInfo(
            totalCapacityBytes: current.totalCapacityBytes,
            freeCapacityBytes: current.freeCapacityBytes,
            recoverableBytes: recoverable
        )
    }

    // MARK: - Filtered Lists & Calculations

    public func items(for category: CleaningCategory) -> [CleanableItem] {
        items.filter { $0.category == category }
    }

    public func categoryBytes(for category: CleaningCategory) -> Int64 {
        items(for: category).reduce(0) { $0 + $1.sizeBytes }
    }

    public var totalRecoverableBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    public var selectedBytes: Int64 {
        items.filter { selectedItemIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    public var formattedSelectedBytes: String {
        ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)
    }

    public var selectedItems: [CleanableItem] {
        items.filter { selectedItemIDs.contains($0.id) }
    }

    public var filteredLargeFiles: [CleanableItem] {
        let base = items(for: .largeAndOldFiles).filter { $0.sizeBytes >= largeFileSizeFilter }
        if let type = largeFileTypeFilter {
            return base.filter { $0.fileTypeCategory == type }
        }
        return base
    }

    // MARK: - Developer Specific Filtered Lists

    @Published public var developerDependencyFilter: String? = nil // nil = All, "node_modules", ".build", "venv", "target"

    public var developerProjectDependencyItems: [CleanableItem] {
        let allDev = items(for: .developerJunk)
        let depKeywords = ["node_modules", ".build", "target", "venv", "Pods"]
        return allDev.filter { item in
            depKeywords.contains(where: { item.name.contains("(\($0))") })
        }
    }

    public var developerGlobalCacheItems: [CleanableItem] {
        let allDev = items(for: .developerJunk)
        let depKeywords = ["node_modules", ".build", "target", "venv", "Pods"]
        return allDev.filter { item in
            !depKeywords.contains(where: { item.name.contains("(\($0))") })
        }
    }

    public var filteredProjectDependencyItems: [CleanableItem] {
        guard let filter = developerDependencyFilter else {
            return developerProjectDependencyItems
        }
        return developerProjectDependencyItems.filter { $0.name.contains("(\(filter))") }
    }

    // MARK: - Selection

    public func isSelected(_ id: UUID) -> Bool {
        selectedItemIDs.contains(id)
    }

    public func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    public func selectAll(for category: CleaningCategory) {
        let categoryItems = items(for: category)
        for item in categoryItems {
            selectedItemIDs.insert(item.id)
        }
    }

    public func deselectAll(for category: CleaningCategory) {
        let categoryItemIDs = Set(items(for: category).map { $0.id })
        selectedItemIDs.subtract(categoryItemIDs)
    }

    // MARK: - Scanning

    public func startScan() {
        guard !isScanning else { return }

        isScanning = true
        scanStatusText = "Scanning your Mac storage..."
        items.removeAll()
        selectedItemIDs.removeAll()

        scanTask = Task { [weak self] in
            guard let self = self else { return }

            let onProgressUpdate: @Sendable (ScanProgress) -> Void = { [weak self] prog in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isScanning else { return }
                    let foundStr = ByteCountFormatter.string(fromByteCount: prog.discoveredBytes, countStyle: .file)
                    self.scanStatusText = "Scanned \(prog.scannedItemsCount) items • Found \(foundStr)"
                }
            }

            let discovered = await self.scanEngine.scan(onProgress: onProgressUpdate)

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.items = discovered

                // Pre-select safe categories by default
                var initialSelection: Set<UUID> = []
                for item in discovered where item.isSafeToClean {
                    initialSelection.insert(item.id)
                }
                self.selectedItemIDs = initialSelection

                self.isScanning = false
                self.refreshDiskInfo()
                let totalStr = ByteCountFormatter.string(fromByteCount: self.totalRecoverableBytes, countStyle: .file)
                self.scanStatusText = "Scan Complete: Found \(discovered.count) items (\(totalStr) cleanable)"
            }
        }
    }

    public func cancelScan() {
        scanTask?.cancel()
        Task {
            await scanEngine.cancel()
        }
        isScanning = false
        scanStatusText = "Scan cancelled"
    }

    // MARK: - Cleaning

    public func cleanSelected(useTrash: Bool = true) async {
        guard !isCleaning, !selectedItems.isEmpty else { return }

        isCleaning = true
        let toClean = selectedItems
        scanStatusText = "Cleaning \(toClean.count) selected items..."

        let result = await DiskCleaner.clean(items: toClean, useTrash: useTrash)

        // Remove cleaned items from local list
        let cleanedIDs = Set(toClean.map { $0.id })
        self.items.removeAll { cleanedIDs.contains($0.id) }
        self.selectedItemIDs.subtract(cleanedIDs)

        self.lastCleanResult = result
        self.isCleaning = false
        self.isShowingCleanSummary = true
        self.refreshDiskInfo()

        self.scanStatusText = "Cleaned \(result.formattedCleaned) successfully!"
    }

    // MARK: - Finder Helpers

    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
