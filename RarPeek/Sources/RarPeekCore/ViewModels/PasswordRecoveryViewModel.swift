import Foundation
import SwiftUI
import Combine

public enum RecoveryStrategyType: String, CaseIterable, Identifiable, Sendable {
    case common = "Top Common"
    case numericPin = "Numeric PIN"
    case customWords = "Custom Clues"

    public var id: String { rawValue }
}

@MainActor
public final class PasswordRecoveryViewModel: ObservableObject {
    @Published public var selectedStrategy: RecoveryStrategyType = .common
    @Published public var pinLength: Int = 4
    @Published public var customWordsText: String = ""

    @Published public var isRunning: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var testedCount: Int = 0
    @Published public var totalCount: Int = 0
    @Published public var currentCandidate: String = ""
    @Published public var candidatesPerSecond: Double = 0.0
    @Published public var foundPassword: String? = nil
    @Published public var statusMessage: String = "Ready to test candidate passwords."
    @Published public var errorMessage: String? = nil

    private var engine: PasswordRecoveryEngine?
    private var recoveryTask: Task<Void, Never>?

    public init() {}

    public func startRecovery(for archiveURL: URL) {
        guard !isRunning else { return }

        isRunning = true
        progress = 0.0
        testedCount = 0
        totalCount = 0
        currentCandidate = ""
        candidatesPerSecond = 0.0
        foundPassword = nil
        errorMessage = nil
        statusMessage = "Starting recovery..."

        let strategy: RecoveryStrategy
        switch selectedStrategy {
        case .common:
            strategy = .commonPasswords
        case .numericPin:
            strategy = .numericPin(length: pinLength)
        case .customWords:
            let list = customWordsText
                .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",; ")))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if list.isEmpty {
                errorMessage = "Please enter at least one word or clue."
                isRunning = false
                return
            }
            strategy = .customList(list)
        }

        let engineInstance = PasswordRecoveryEngine()
        self.engine = engineInstance

        let updateProgress: @Sendable (RecoveryProgress) -> Void = { [weak self] prog in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRunning else { return }
                self.testedCount = prog.testedCount
                self.totalCount = prog.totalCount
                self.currentCandidate = prog.currentCandidate
                self.candidatesPerSecond = prog.speed
                if prog.totalCount > 0 {
                    self.progress = Double(prog.testedCount) / Double(prog.totalCount)
                }
                self.statusMessage = "Testing (\(prog.testedCount)/\(prog.totalCount)) • \(Int(prog.speed)) test/s"
            }
        }

        recoveryTask = Task { [weak self] in
            let result = await engineInstance.runRecovery(
                archiveURL: archiveURL,
                strategy: strategy,
                onProgress: updateProgress
            )

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isRunning = false

                if let found = result {
                    self.foundPassword = found
                    self.statusMessage = "Password found: \(found)"
                    self.progress = 1.0
                } else if !Task.isCancelled {
                    self.statusMessage = "Password not found in this set."
                }
            }
        }
    }

    public func cancel() {
        recoveryTask?.cancel()
        Task {
            await engine?.cancel()
        }
        isRunning = false
        statusMessage = "Recovery cancelled."
    }

    public func reset() {
        cancel()
        progress = 0.0
        testedCount = 0
        totalCount = 0
        currentCandidate = ""
        candidatesPerSecond = 0.0
        foundPassword = nil
        errorMessage = nil
        statusMessage = "Ready to test candidate passwords."
    }
}
