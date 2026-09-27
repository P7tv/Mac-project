import XCTest
@testable import RarPeekCore

@MainActor
final class ArchiveViewModelTests: XCTestCase {
    func testInitialState() {
        let vm = ArchiveViewModel()
        XCTAssertNil(vm.currentArchive)
        XCTAssertTrue(vm.selectedEntryIDs.isEmpty)
        XCTAssertFalse(vm.isExtracting)
        XCTAssertEqual(vm.searchFilter, "")
        XCTAssertTrue(vm.filteredEntries.isEmpty)
    }

    func testSearchFilter() {
        let vm = ArchiveViewModel()
        let e1 = ArchiveEntry(index: 0, path: "Photos/beach.jpg", uncompressedSize: 500)
        let e2 = ArchiveEntry(index: 1, path: "Docs/taxes.pdf", uncompressedSize: 1000)
        let e3 = ArchiveEntry(index: 2, path: "Music/song.mp3", uncompressedSize: 2000)

        let info = ArchiveInfo(
            fileURL: URL(fileURLWithPath: "/tmp/test.rar"),
            formatName: "RAR",
            entries: [e1, e2, e3]
        )
        vm.currentArchive = info

        XCTAssertEqual(vm.filteredEntries.count, 3)

        // Filter by name
        vm.searchFilter = "beach"
        XCTAssertEqual(vm.filteredEntries.count, 1)
        XCTAssertEqual(vm.filteredEntries.first?.name, "beach.jpg")

        // Filter by extension
        vm.searchFilter = "pdf"
        XCTAssertEqual(vm.filteredEntries.count, 1)
        XCTAssertEqual(vm.filteredEntries.first?.name, "taxes.pdf")

        // Clear filter
        vm.searchFilter = ""
        XCTAssertEqual(vm.filteredEntries.count, 3)
    }

    func testSelectionManagement() {
        let vm = ArchiveViewModel()
        let e1 = ArchiveEntry(index: 0, path: "file1.txt", uncompressedSize: 100)
        let e2 = ArchiveEntry(index: 1, path: "file2.txt", uncompressedSize: 200)

        let info = ArchiveInfo(
            fileURL: URL(fileURLWithPath: "/tmp/test.rar"),
            formatName: "RAR",
            entries: [e1, e2]
        )
        vm.currentArchive = info

        XCTAssertEqual(vm.selectedEntryIDs.count, 0)

        vm.toggleSelection(for: e1.id)
        XCTAssertTrue(vm.isEntrySelected(e1.id))
        XCTAssertEqual(vm.selectedCount, 1)

        vm.selectAll()
        XCTAssertEqual(vm.selectedCount, 2)

        vm.deselectAll()
        XCTAssertEqual(vm.selectedCount, 0)
    }
}
