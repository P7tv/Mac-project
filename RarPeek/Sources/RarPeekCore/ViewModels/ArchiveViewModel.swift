import Foundation
import SwiftUI
import Combine
import AppKit

public enum DestinationMode: String, CaseIterable, Identifiable, Sendable {
    case sameFolder = "Same Folder"
    case downloads = "Downloads"
    case custom = "Choose Folder..."

    public var id: String { rawValue }
}

@MainActor
public final class ArchiveViewModel: ObservableObject {
    @Published public var currentArchive: ArchiveInfo? = nil
    @Published public var selectedEntryIDs: Set<UUID> = []
    @Published public var searchFilter: String = ""
    @Published public var destinationMode: DestinationMode = .sameFolder
    @Published public var customDestinationFolder: URL? = nil
    @Published public var overwritePolicy: OverwritePolicy = .rename

    @Published public var isExtracting: Bool = false
    @Published public var extractionProgress: Double = 0.0
    @Published public var statusMessage: String = ""
    @Published public var alertMessage: String? = nil

    @Published public var isShowingPasswordPrompt: Bool = false
    @Published public var passwordInput: String = ""
    @Published public var extractedOutputURL: URL? = nil

    public init() {}

    public var filteredEntries: [ArchiveEntry] {
        guard let archive = currentArchive else { return [] }
        let query = searchFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return archive.entries
        }
        return archive.entries.filter {
            $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query)
        }
    }

    public var selectedCount: Int {
        selectedEntryIDs.count
    }

    public func isEntrySelected(_ id: UUID) -> Bool {
        selectedEntryIDs.contains(id)
    }

    public func toggleSelection(for id: UUID) {
        if selectedEntryIDs.contains(id) {
            selectedEntryIDs.remove(id)
        } else {
            selectedEntryIDs.insert(id)
        }
    }

    public func selectAll() {
        guard let archive = currentArchive else { return }
        selectedEntryIDs = Set(archive.entries.map { $0.id })
    }

    public func deselectAll() {
        selectedEntryIDs.removeAll()
    }

    public func effectiveDestinationURL(for archiveURL: URL) -> URL {
        switch destinationMode {
        case .sameFolder:
            return archiveURL.deletingLastPathComponent()
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? archiveURL.deletingLastPathComponent()
        case .custom:
            return customDestinationFolder ?? archiveURL.deletingLastPathComponent()
        }
    }

    public func loadArchive(url: URL, password: String? = nil) async {
        statusMessage = "Inspecting archive..."
        do {
            let info = try await ArchiveEngine.inspectArchive(url: url, password: password)
            self.currentArchive = info
            self.selectedEntryIDs.removeAll()
            self.searchFilter = ""
            self.statusMessage = "\(info.formatName) • \(info.fileCount) files • \(info.formattedTotalUncompressedSize)"
            if info.isEncrypted && (password == nil || password!.isEmpty) {
                self.isShowingPasswordPrompt = true
            }
        } catch ArchiveEngineError.passwordRequired {
            self.isShowingPasswordPrompt = true
            self.statusMessage = "Password required to view contents."
        } catch {
            self.alertMessage = error.localizedDescription
            self.statusMessage = "Failed to open archive."
        }
    }

    public func extractAll() async {
        await performExtraction(selectedOnly: false)
    }

    public func extractSelected() async {
        await performExtraction(selectedOnly: true)
    }

    private func performExtraction(selectedOnly: Bool) async {
        guard let archive = currentArchive else { return }
        isExtracting = true
        extractionProgress = 0.1
        statusMessage = "Extracting..."

        let dest = effectiveDestinationURL(for: archive.fileURL)
        let selectedIndexes: [Int]?
        if selectedOnly {
            selectedIndexes = archive.entries.filter { selectedEntryIDs.contains($0.id) }.map { $0.index }
        } else {
            selectedIndexes = nil
        }

        let options = ExtractionOptions(
            targetFolder: dest,
            password: passwordInput.isEmpty ? nil : passwordInput,
            selectedIndexes: selectedIndexes,
            overwritePolicy: overwritePolicy,
            createContainingFolder: true
        )

        do {
            let resultURL = try await ArchiveEngine.extractArchive(url: archive.fileURL, options: options) { [weak self] progress, file in
                Task { @MainActor in
                    self?.extractionProgress = progress
                    self?.statusMessage = "Extracting: \(file)"
                }
            }
            self.extractedOutputURL = resultURL
            self.statusMessage = "Extraction Complete!"
            self.extractionProgress = 1.0
        } catch ArchiveEngineError.invalidPassword {
            self.isShowingPasswordPrompt = true
            self.alertMessage = "Incorrect password. Please try again."
        } catch {
            self.alertMessage = error.localizedDescription
            self.statusMessage = "Extraction failed."
        }

        isExtracting = false
    }

    public func revealExtractedFolder() {
        if let output = extractedOutputURL {
            NSWorkspace.shared.activateFileViewerSelecting([output])
        }
    }

    public func closeArchive() {
        currentArchive = nil
        selectedEntryIDs.removeAll()
        searchFilter = ""
        extractedOutputURL = nil
        statusMessage = ""
    }
}
