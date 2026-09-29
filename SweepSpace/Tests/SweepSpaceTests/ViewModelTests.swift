import XCTest
@testable import SweepSpaceCore

@MainActor
final class ViewModelTests: XCTestCase {
    func testViewModelInitialState() {
        let vm = SweepSpaceViewModel()
        XCTAssertFalse(vm.isScanning)
        XCTAssertFalse(vm.isCleaning)
        XCTAssertEqual(vm.items.count, 0)
        XCTAssertEqual(vm.selectedItemIDs.count, 0)
        XCTAssertEqual(vm.selectedBytes, 0)
    }

    func testViewModelSelectionAndCalculations() {
        let vm = SweepSpaceViewModel()

        let item1 = CleanableItem(
            name: "cache1",
            path: URL(fileURLWithPath: "/tmp/c1"),
            sizeBytes: 1000,
            category: .systemAndAppCache,
            isSafeToClean: true
        )
        let item2 = CleanableItem(
            name: "cache2",
            path: URL(fileURLWithPath: "/tmp/c2"),
            sizeBytes: 2500,
            category: .systemAndAppCache,
            isSafeToClean: true
        )
        let item3 = CleanableItem(
            name: "movie.mp4",
            path: URL(fileURLWithPath: "/tmp/movie.mp4"),
            sizeBytes: 50000,
            category: .largeAndOldFiles,
            isSafeToClean: false,
            fileTypeCategory: .video
        )

        vm.items = [item1, item2, item3]

        XCTAssertEqual(vm.totalRecoverableBytes, 53500)
        XCTAssertEqual(vm.categoryBytes(for: .systemAndAppCache), 3500)
        XCTAssertEqual(vm.categoryBytes(for: .largeAndOldFiles), 50000)

        // Select item1
        vm.toggleSelection(for: item1.id)
        XCTAssertTrue(vm.isSelected(item1.id))
        XCTAssertEqual(vm.selectedBytes, 1000)

        // Select all system cache
        vm.selectAll(for: .systemAndAppCache)
        XCTAssertTrue(vm.isSelected(item1.id))
        XCTAssertTrue(vm.isSelected(item2.id))
        XCTAssertEqual(vm.selectedBytes, 3500)

        // Deselect all system cache
        vm.deselectAll(for: .systemAndAppCache)
        XCTAssertFalse(vm.isSelected(item1.id))
        XCTAssertFalse(vm.isSelected(item2.id))
        XCTAssertEqual(vm.selectedBytes, 0)
    }

    func testLargeFileFiltering() {
        let vm = SweepSpaceViewModel()

        let video = CleanableItem(
            name: "clip.mov",
            path: URL(fileURLWithPath: "/tmp/clip.mov"),
            sizeBytes: 200 * 1024 * 1024,
            category: .largeAndOldFiles,
            fileTypeCategory: .video
        )
        let archive = CleanableItem(
            name: "backup.zip",
            path: URL(fileURLWithPath: "/tmp/backup.zip"),
            sizeBytes: 600 * 1024 * 1024,
            category: .largeAndOldFiles,
            fileTypeCategory: .archive
        )

        vm.items = [video, archive]

        // Default 100MB filter: both match
        vm.largeFileSizeFilter = 100 * 1024 * 1024
        vm.largeFileTypeFilter = nil
        XCTAssertEqual(vm.filteredLargeFiles.count, 2)

        // Filter by 500MB: only archive matches
        vm.largeFileSizeFilter = 500 * 1024 * 1024
        XCTAssertEqual(vm.filteredLargeFiles.count, 1)
        XCTAssertEqual(vm.filteredLargeFiles.first?.name, "backup.zip")

        // Filter by Type video: only video matches
        vm.largeFileSizeFilter = 100 * 1024 * 1024
        vm.largeFileTypeFilter = .video
        XCTAssertEqual(vm.filteredLargeFiles.count, 1)
        XCTAssertEqual(vm.filteredLargeFiles.first?.name, "clip.mov")
    }
}
