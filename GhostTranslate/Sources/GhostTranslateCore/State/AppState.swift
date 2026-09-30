import SwiftUI
import Combine

public enum AIStatus: Equatable {
    case idle
    case translating
    case error(String)
    
    public var label: String {
        switch self {
        case .idle: return "Ready"
        case .translating: return "Typhoon AI Translating..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

public struct SubtitleLine: Identifiable, Equatable {
    public let id = UUID()
    public let original: String
    public let translation: String
    public let timestamp: Date = Date()
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // Core Dependencies
    public let windowManager = GhostWindowManager.shared
    public let audioEngine = AudioTranscriptionEngine.shared
    public let typhoon = TyphoonService.shared
    public let ocrEngine = VisionOCREngine.shared
    public let snipper = ScreenSnipper.shared
    public let chunker = SpeechChunker()
    
    // Translation & Content State
    @Published public var originalText: String = ""
    @Published public var translatedText: String = ""
    @Published public var previousLine: SubtitleLine? = nil
    @Published public var interviewResult: InterviewPromptResult?
    @Published public var aiStatus: AIStatus = .idle
    @Published public var latencyMs: Int = 0
    
    // Settings & Configuration
    @Published public var typhoonAPIKey: String {
        didSet {
            UserDefaults.standard.set(typhoonAPIKey, forKey: "ghost_typhoon_api_key")
            Task { await typhoon.setAPIKey(typhoonAPIKey) }
        }
    }
    
    @Published public var typhoonModel: String {
        didSet {
            UserDefaults.standard.set(typhoonModel, forKey: "ghost_typhoon_model")
            Task { await typhoon.setModel(typhoonModel) }
        }
    }
    
    @Published public var subtitleFontSize: CGFloat = 16 {
        didSet { UserDefaults.standard.set(subtitleFontSize, forKey: "ghost_font_size") }
    }
    
    private var translationDebounceTask: Task<Void, Never>?
    private var pausePreviewTask: Task<Void, Never>?
    private var checkpointTask: Task<Void, Never>?
    private var previewTranslationGate = LatestTranslationGate()
    private var finalizedTranslationGate = LatestTranslationGate()
    private var activeRecognitionSessionID: UUID?
    private var latestChunkingRevision: UInt64 = 0
    private var lastPreviewRequest: SentenceTranslationInput?
    private var cancellables = Set<AnyCancellable>()
    private let restartRecognitionStream: @MainActor () -> Void
    private let interviewPromptGenerator: @MainActor (String) async throws -> InterviewPromptResult
    private let subtitleTranslator: @MainActor (SentenceTranslationInput) async throws -> String

    private let pausePreviewDelay: UInt64 = 350_000_000
    private let checkpointDelay: UInt64 = 4_000_000_000
    
    public convenience init() {
        self.init(
            restartRecognitionStream: nil,
            interviewPromptGenerator: nil,
            subtitleTranslator: nil
        )
    }

    init(
        restartRecognitionStream: (@MainActor () -> Void)?,
        interviewPromptGenerator: (@MainActor (String) async throws -> InterviewPromptResult)?,
        subtitleTranslator: (@MainActor (SentenceTranslationInput) async throws -> String)?
    ) {
        self.restartRecognitionStream = restartRecognitionStream ?? {
            AudioTranscriptionEngine.shared.restartRecognitionStream()
        }
        self.interviewPromptGenerator = interviewPromptGenerator ?? { question in
            try await TyphoonService.shared.generateInterviewPrompts(question: question)
        }
        self.subtitleTranslator = subtitleTranslator ?? { input in
            try await TyphoonService.shared.translateSubtitle(text: input.text, context: input.context)
        }
        let storedKey = UserDefaults.standard.string(forKey: "ghost_typhoon_api_key") ?? ""
        let storedModel = UserDefaults.standard.string(forKey: "ghost_typhoon_model") ?? "typhoon-v2.5-30b-a3b-instruct"
        let storedFontSize = UserDefaults.standard.double(forKey: "ghost_font_size")
        
        self.typhoonAPIKey = storedKey
        self.typhoonModel = storedModel
        if storedFontSize > 10 {
            self.subtitleFontSize = CGFloat(storedFontSize)
        }
        
        setupAudioCallbacks()
    }
    
    private func setupAudioCallbacks() {
        audioEngine.onSegmentReceived = nil
        audioEngine.onRecognitionEvent = { [weak self] event in
            self?.handleRecognitionEvent(event)
        }
        windowManager.$currentMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.handleModeChange(mode)
            }
            .store(in: &cancellables)
    }

    private func handleModeChange(_ mode: HUDMode) {
        previewTranslationGate.invalidate()
        lastPreviewRequest = nil
        interviewResult = nil
        if aiStatus == .translating {
            aiStatus = .idle
        }

        guard !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let openSentence = activeRecognitionSessionID.flatMap { sessionID in
            chunker.previewCurrentSentence(
                sessionID: sessionID,
                expectedRevision: latestChunkingRevision
            )
        }
        let input = openSentence ?? SentenceTranslationInput(text: originalText, context: nil)
        requestPreview(input)
    }

    private func handleRecognitionEvent(_ event: SpeechRecognitionEvent) {
        switch event {
        case .snapshot(let snapshot):
            if activeRecognitionSessionID != snapshot.sessionID {
                cancelPreviewTimers()
                previewTranslationGate.invalidate()
                finalizedTranslationGate.invalidate()
                if aiStatus == .translating {
                    aiStatus = .idle
                }
                activeRecognitionSessionID = snapshot.sessionID
                lastPreviewRequest = nil
            }

            let update = chunker.process(.snapshot(snapshot))
            let recognitionChanged = update.revision != latestChunkingRevision
            latestChunkingRevision = update.revision
            let currentInput = chunker.previewCurrentSentence(
                sessionID: snapshot.sessionID,
                expectedRevision: update.revision
            )
            let finalizedInput = finalizedTranslationInput(for: update.finalized)
            if currentInput != lastPreviewRequest {
                if lastPreviewRequest != nil {
                    previewTranslationGate.invalidate()
                    if aiStatus == .translating {
                        aiStatus = .idle
                    }
                }
                lastPreviewRequest = nil
            }
            if let finalizedInput {
                previewTranslationGate.invalidate()
                lastPreviewRequest = nil
                translatedText = ""
                if aiStatus == .translating {
                    aiStatus = .idle
                }
                translateFinalized(finalizedInput)
                checkpointTask?.cancel()
                checkpointTask = nil
            }

            if let current = currentInput {
                originalText = current.text
                if recognitionChanged {
                    schedulePausePreview(sessionID: snapshot.sessionID, revision: update.revision)
                }
                scheduleCheckpoint(sessionID: snapshot.sessionID)
            } else {
                cancelPreviewTimers()
                if let finalizedInput {
                    originalText = finalizedInput.text
                }
            }

            if let preview = update.preview {
                requestPreview(preview)
            }

        case .sessionEnded(let sessionID):
            let update = chunker.process(.sessionEnded(sessionID: sessionID))
            latestChunkingRevision = update.revision
            cancelPreviewTimers()
            previewTranslationGate.invalidate()
            lastPreviewRequest = nil
            if aiStatus == .translating {
                aiStatus = .idle
            }
            if activeRecognitionSessionID == sessionID {
                activeRecognitionSessionID = nil
            }
            if let finalInput = finalizedTranslationInput(for: update.finalized) {
                translatedText = ""
                originalText = finalInput.text
                translateFinalized(finalInput)
            }
        }
    }

    private func finalizedTranslationInput(
        for inputs: [SentenceTranslationInput]
    ) -> SentenceTranslationInput? {
        guard let latest = inputs.last else { return nil }
        guard windowManager.currentMode == .interviewPrompter else { return latest }
        return SentenceTranslationInput(
            text: inputs.map(\.text).joined(separator: " "),
            context: nil
        )
    }

    private func schedulePausePreview(sessionID: UUID, revision: UInt64) {
        pausePreviewTask?.cancel()
        pausePreviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: self.pausePreviewDelay)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  let input = self.chunker.previewCurrentSentence(
                    sessionID: sessionID,
                    expectedRevision: revision
                  ) else {
                return
            }
            self.pausePreviewTask = nil
            self.requestPreview(input)
        }
    }

    private func scheduleCheckpoint(sessionID: UUID) {
        guard checkpointTask == nil else { return }
        checkpointTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: self.checkpointDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self.checkpointTask = nil
            guard self.activeRecognitionSessionID == sessionID,
                  let input = self.chunker.previewCurrentSentence(
                    sessionID: sessionID,
                    expectedRevision: self.latestChunkingRevision
                  ) else {
                return
            }
            self.requestPreview(input)
            self.scheduleCheckpoint(sessionID: sessionID)
        }
    }

    private func cancelPreviewTimers() {
        pausePreviewTask?.cancel()
        pausePreviewTask = nil
        checkpointTask?.cancel()
        checkpointTask = nil
    }

    private func requestPreview(_ input: SentenceTranslationInput) {
        guard !input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              input != lastPreviewRequest else {
            return
        }
        lastPreviewRequest = input
        if windowManager.currentMode == .interviewPrompter {
            interviewResult = nil
        }
        let ticket = previewTranslationGate.issue()
        aiStatus = .translating
        Task {
            await translatePreview(input, ticket: ticket)
        }
    }

    private func translatePreview(_ input: SentenceTranslationInput, ticket: UInt64) async {
        let startTime = DispatchTime.now()
        do {
            if windowManager.currentMode == .interviewPrompter {
                let result = try await interviewPromptGenerator(input.text)
                guard previewTranslationGate.accepts(ticket) else { return }
                interviewResult = result
                translatedText = result.questionSummary
            } else {
                let translation = try await subtitleTranslator(input)
                guard previewTranslationGate.accepts(ticket) else { return }
                translatedText = translation
            }

            guard previewTranslationGate.accepts(ticket) else { return }
            let elapsed = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            latencyMs = Int(elapsed / 1_000_000)
            aiStatus = .idle
        } catch {
            guard previewTranslationGate.accepts(ticket) else { return }
            aiStatus = .error(error.localizedDescription)
        }
    }

    private func translateFinalized(_ input: SentenceTranslationInput) {
        if windowManager.currentMode == .interviewPrompter {
            requestPreview(input)
            return
        }

        let ticket = finalizedTranslationGate.issue()
        Task {
            do {
                let translation = try await subtitleTranslator(input)
                guard finalizedTranslationGate.accepts(ticket) else { return }
                previousLine = SubtitleLine(original: input.text, translation: translation)
            } catch {
                guard finalizedTranslationGate.accepts(ticket) else { return }
                previousLine = SubtitleLine(original: input.text, translation: input.text)
            }
        }
    }
    
    public func debounceTranslation(text: String, immediate: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        translationDebounceTask?.cancel()
        let ticket = previewTranslationGate.issue()
        lastPreviewRequest = nil
        
        let delayNanoseconds: UInt64 = immediate ? 50_000_000 : 500_000_000 // 50ms or 500ms
        
        translationDebounceTask = Task {
            do {
                if !immediate {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                }
                guard !Task.isCancelled else { return }
                await self.translatePreview(
                    SentenceTranslationInput(text: trimmed, context: nil),
                    ticket: ticket
                )
            } catch {
                // Task cancelled
            }
        }
    }
    
    public func performTranslation(for text: String) async {
        guard !text.isEmpty else { return }
        let ticket = previewTranslationGate.issue()
        lastPreviewRequest = nil
        aiStatus = .translating
        await translatePreview(SentenceTranslationInput(text: text, context: nil), ticket: ticket)
    }
    
    public func triggerScreenOCR() {
        let ticket = previewTranslationGate.issue()
        lastPreviewRequest = nil
        snipper.startCapture { [weak self] cgImage in
            guard let self = self, let image = cgImage else { return }
            Task {
                do {
                    guard self.previewTranslationGate.accepts(ticket) else { return }
                    self.aiStatus = .translating
                    let recognized = try await self.ocrEngine.recognizeText(from: image)
                    guard self.previewTranslationGate.accepts(ticket) else { return }
                    guard !recognized.isEmpty else {
                        self.aiStatus = .error("No text detected in selected area")
                        return
                    }
                    self.originalText = recognized
                    let translated = try await self.typhoon.translateOCR(text: recognized)
                    guard self.previewTranslationGate.accepts(ticket) else { return }
                    self.translatedText = translated
                    self.aiStatus = .idle
                    self.windowManager.show()
                } catch {
                    guard self.previewTranslationGate.accepts(ticket) else { return }
                    self.aiStatus = .error(error.localizedDescription)
                }
            }
        }
    }
    
    public func clear() {
        translationDebounceTask?.cancel()
        translationDebounceTask = nil
        cancelPreviewTimers()
        previewTranslationGate.invalidate()
        finalizedTranslationGate.invalidate()
        activeRecognitionSessionID = nil
        lastPreviewRequest = nil
        chunker.reset()
        restartRecognitionStream()
        originalText = ""
        translatedText = ""
        previousLine = nil
        interviewResult = nil
        aiStatus = .idle
    }
}
