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

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // Core Dependencies
    public let windowManager = GhostWindowManager.shared
    public let audioEngine = AudioTranscriptionEngine.shared
    public let typhoon = TyphoonService.shared
    public let ocrEngine = VisionOCREngine.shared
    public let snipper = ScreenSnipper.shared
    
    // Translation & Content State
    @Published public var originalText: String = ""
    @Published public var translatedText: String = ""
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
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
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
        audioEngine.onSegmentReceived = { [weak self] transcript, isFinal in
            guard let self = self else { return }
            self.originalText = transcript
            self.debounceTranslation(text: transcript, immediate: isFinal)
        }
    }
    
    public func debounceTranslation(text: String, immediate: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        translationDebounceTask?.cancel()
        
        let delayNanoseconds: UInt64 = immediate ? 50_000_000 : 500_000_000 // 50ms or 500ms
        
        translationDebounceTask = Task {
            do {
                if !immediate {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                }
                guard !Task.isCancelled else { return }
                await self.performTranslation(for: trimmed)
            } catch {
                // Task cancelled
            }
        }
    }
    
    public func performTranslation(for text: String) async {
        guard !text.isEmpty else { return }
        self.aiStatus = .translating
        let startTime = DispatchTime.now()
        
        do {
            if windowManager.currentMode == .interviewPrompter {
                let result = try await typhoon.generateInterviewPrompts(question: text)
                self.interviewResult = result
                self.translatedText = result.questionSummary
            } else {
                let thaiText = try await typhoon.translateSubtitle(text: text)
                self.translatedText = thaiText
            }
            
            let endTime = DispatchTime.now()
            let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
            self.latencyMs = Int(nanoTime / 1_000_000)
            self.aiStatus = .idle
        } catch {
            self.aiStatus = .error(error.localizedDescription)
        }
    }
    
    public func triggerScreenOCR() {
        snipper.startCapture { [weak self] cgImage in
            guard let self = self, let image = cgImage else { return }
            Task {
                do {
                    self.aiStatus = .translating
                    let recognized = try await self.ocrEngine.recognizeText(from: image)
                    guard !recognized.isEmpty else {
                        self.aiStatus = .error("No text detected in selected area")
                        return
                    }
                    self.originalText = recognized
                    let translated = try await self.typhoon.translateOCR(text: recognized)
                    self.translatedText = translated
                    self.aiStatus = .idle
                    self.windowManager.show()
                } catch {
                    self.aiStatus = .error(error.localizedDescription)
                }
            }
        }
    }
    
    public func clear() {
        originalText = ""
        translatedText = ""
        interviewResult = nil
        aiStatus = .idle
    }
}
