import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class QuickRecallViewModel: ObservableObject, ScreenSamplerDelegate {
    @Published public var searchQuery: String = ""
    @Published public var searchResults: [RecallRecord] = []
    @Published public var selectedRecord: RecallRecord? = nil
    @Published public var totalSnapshotsCount: Int = 0
    @Published public var isRecording: Bool = true
    @Published public var isSearchWindowVisible: Bool = false
    @Published public var lastCapturedAppName: String = "Idle"
    @Published public var lastCapturedTime: Date? = nil
    @Published public var toastMessage: String? = nil

    public let database: RecallDatabase
    public let sampler: ScreenSampler
    private var cancellables = Set<AnyCancellable>()

    public init(database: RecallDatabase? = nil) {
        let db = database ?? RecallDatabase()
        self.database = db
        self.sampler = ScreenSampler(database: db)

        self.sampler.delegate = self
        self.totalSnapshotsCount = db.count()

        setupSearchDebounce()
        loadRecent()
        startRecording()
    }

    private func setupSearchDebounce() {
        $searchQuery
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    public func performSearch(query: String) {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            loadRecent()
        } else {
            let results = database.search(query: query, limit: 50)
            self.searchResults = results
            if let first = results.first {
                self.selectedRecord = first
            } else {
                self.selectedRecord = nil
            }
        }
    }

    public func loadRecent() {
        let recents = database.recentRecords(limit: 30)
        self.searchResults = recents
        self.selectedRecord = recents.first
        self.totalSnapshotsCount = database.count()
    }

    public func toggleRecording() {
        if isRecording {
            pauseRecording()
        } else {
            resumeRecording()
        }
    }

    public func startRecording() {
        sampler.start()
        isRecording = true
        showToast("⏺️ QuickRecall recording active")
    }

    public func pauseRecording() {
        sampler.stop()
        isRecording = false
        showToast("⏸️ Recording paused")
    }

    public func resumeRecording() {
        sampler.start()
        isRecording = true
        showToast("▶️ Recording resumed")
    }

    public func clearAllHistory() {
        database.clearAll()
        searchResults.removeAll()
        selectedRecord = nil
        totalSnapshotsCount = 0
        showToast("🗑️ All memory snapshots cleared")
    }

    public func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast("📋 Copied text to clipboard")
    }

    public func openImageInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func showToast(_ message: String) {
        self.toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }

    // MARK: - ScreenSamplerDelegate
    nonisolated public func screenSampler(didCaptureRecord record: RecallRecord) {
        Task { @MainActor in
            self.totalSnapshotsCount = self.database.count()
            self.lastCapturedAppName = record.appName
            self.lastCapturedTime = record.timestamp

            // If user is currently looking at recents, insert live
            if self.searchQuery.isEmpty {
                self.searchResults.insert(record, at: 0)
                if self.searchResults.count > 40 {
                    self.searchResults.removeLast()
                }
                if self.selectedRecord == nil {
                    self.selectedRecord = record
                }
            }
        }
    }

    nonisolated public func screenSampler(didSkipReason: String) {
        // Optional debug logging
    }
}
