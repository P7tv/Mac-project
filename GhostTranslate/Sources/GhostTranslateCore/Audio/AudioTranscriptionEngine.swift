import Foundation
import Speech
import AVFoundation

public enum AudioEngineError: LocalizedError {
    case recognizerUnavailable
    case permissionDenied
    case audioInputUnavailable
    case custom(String)
    
    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available for the selected language."
        case .permissionDenied:
            return "Microphone or Speech Recognition permission was denied."
        case .audioInputUnavailable:
            return "Audio input hardware could not be initialized."
        case .custom(let msg):
            return msg
        }
    }
}

@MainActor
public final class AudioTranscriptionEngine: ObservableObject {
    public static let shared = AudioTranscriptionEngine()
    
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var currentTranscript: String = ""
    @Published public var isAutoDetectLanguage: Bool = true
    @Published public var detectedLanguageTag: String = "AUTO"
    @Published public var selectedLocale: Locale = Locale(identifier: "en-US")
    @Published public var errorMessage: String? = nil
    
    public var onSegmentReceived: ((String, Bool) -> Void)? // (transcript, isFinal)
    
    private var audioEngine: AVAudioEngine?
    
    // Single-mode recognizer
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Auto-detect Dual Recognizers (EN & TH)
    private var enRecognizer: SFSpeechRecognizer?
    private var thRecognizer: SFSpeechRecognizer?
    private var enRequest: SFSpeechAudioBufferRecognitionRequest?
    private var thRequest: SFSpeechAudioBufferRecognitionRequest?
    private var enTask: SFSpeechRecognitionTask?
    private var thTask: SFSpeechRecognitionTask?
    
    private var latestENText: String = ""
    private var latestENConfidence: Float = 0
    private var latestTHText: String = ""
    private var latestTHConfidence: Float = 0
    
    public init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: selectedLocale)
        self.enRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.thRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH"))
    }
    
    public static func supportedLocales() -> [Locale] {
        return [
            Locale(identifier: "en-US"),
            Locale(identifier: "th-TH"),
            Locale(identifier: "ja-JP"),
            Locale(identifier: "zh-CN")
        ]
    }
    
    public func enableAutoDetect() {
        self.isAutoDetectLanguage = true
        self.detectedLanguageTag = "AUTO"
        if isRecording {
            stopTranscription()
            try? startTranscription()
        }
    }
    
    public func setLocale(_ locale: Locale) {
        self.isAutoDetectLanguage = false
        self.selectedLocale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.detectedLanguageTag = locale.identifier.hasPrefix("th") ? "TH" : "EN"
        if isRecording {
            stopTranscription()
            try? startTranscription()
        }
    }
    
    public func toggleTranscription() {
        if isRecording {
            stopTranscription()
        } else {
            startListeningWithPermissions()
        }
    }
    
    public func startListeningWithPermissions() {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch authStatus {
        case .authorized:
            do {
                try startTranscription()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        do {
                            try self?.startTranscription()
                        } catch {
                            self?.errorMessage = error.localizedDescription
                        }
                    } else {
                        self?.errorMessage = "Speech Recognition was not granted."
                    }
                }
            }
            
        default:
            do {
                try startTranscription()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    public func startTranscription() throws {
        stopTranscription()
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw AudioEngineError.audioInputUnavailable
        }
        
        self.audioEngine = engine
        self.latestENText = ""
        self.latestTHText = ""
        self.latestENConfidence = 0
        self.latestTHConfidence = 0
        
        if isAutoDetectLanguage {
            // Auto-detect mode: Start Dual parallel streams (EN + TH)
            try startAutoDualRecognition(engine: engine, inputNode: inputNode, format: recordingFormat)
        } else {
            // Manual single locale mode
            try startSingleRecognition(engine: engine, inputNode: inputNode, format: recordingFormat)
        }
        
        try engine.start()
        self.isRecording = true
        self.errorMessage = nil
    }
    
    private func startAutoDualRecognition(engine: AVAudioEngine, inputNode: AVAudioInputNode, format: AVAudioFormat) throws {
        guard let enRec = enRecognizer ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              let thRec = thRecognizer ?? SFSpeechRecognizer(locale: Locale(identifier: "th-TH")),
              enRec.isAvailable && thRec.isAvailable else {
            throw AudioEngineError.recognizerUnavailable
        }
        
        let enReq = SFSpeechAudioBufferRecognitionRequest()
        enReq.shouldReportPartialResults = true
        enReq.taskHint = .dictation
        
        let thReq = SFSpeechAudioBufferRecognitionRequest()
        thReq.shouldReportPartialResults = true
        thReq.taskHint = .dictation
        
        self.enRequest = enReq
        self.thRequest = thReq
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak enReq, weak thReq] buffer, _ in
            enReq?.append(buffer)
            thReq?.append(buffer)
        }
        
        // English recognition task
        self.enTask = enRec.recognitionTask(with: enReq) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                if let result = result {
                    self.latestENText = result.bestTranscription.formattedString
                    self.latestENConfidence = self.calculateConfidence(result.bestTranscription)
                    self.evaluateAutoLanguageDecision(isFinal: result.isFinal)
                }
                if let error = error as NSError?, error.code == 203 && self.isRecording {
                    self.restartContinuousStream()
                }
            }
        }
        
        // Thai recognition task
        self.thTask = thRec.recognitionTask(with: thReq) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                if let result = result {
                    self.latestTHText = result.bestTranscription.formattedString
                    self.latestTHConfidence = self.calculateConfidence(result.bestTranscription)
                    self.evaluateAutoLanguageDecision(isFinal: result.isFinal)
                }
                if let error = error as NSError?, error.code == 203 && self.isRecording {
                    self.restartContinuousStream()
                }
            }
        }
    }
    
    private func evaluateAutoLanguageDecision(isFinal: Bool) {
        let thHasThaiChars = latestTHText.unicodeScalars.contains { $0.value >= 0x0E00 && $0.value <= 0x0E7F }
        let enHasLatinChars = latestENText.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        
        var selectedText = ""
        var langTag = "AUTO"
        
        if thHasThaiChars && !latestTHText.isEmpty {
            // Thai text detected!
            selectedText = latestTHText
            langTag = "TH ➔ EN"
        } else if enHasLatinChars && !latestENText.isEmpty {
            // English text detected!
            selectedText = latestENText
            langTag = "EN ➔ TH"
        } else {
            selectedText = !latestENText.isEmpty ? latestENText : latestTHText
            langTag = "AUTO"
        }
        
        guard !selectedText.isEmpty else { return }
        self.detectedLanguageTag = langTag
        self.currentTranscript = selectedText
        self.onSegmentReceived?(selectedText, isFinal)
    }
    
    private func startSingleRecognition(engine: AVAudioEngine, inputNode: AVAudioInputNode, format: AVAudioFormat) throws {
        guard let recognizer = speechRecognizer ?? SFSpeechRecognizer(locale: selectedLocale),
              recognizer.isAvailable else {
            throw AudioEngineError.recognizerUnavailable
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.recognitionRequest = request
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        
        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.currentTranscript = text
                    self.onSegmentReceived?(text, result.isFinal)
                }
                if let error = error as NSError?, error.code == 203 && self.isRecording {
                    self.restartContinuousStream()
                }
            }
        }
    }
    
    private func calculateConfidence(_ transcription: SFTranscription) -> Float {
        let segments = transcription.segments
        guard !segments.isEmpty else { return 0 }
        let sum = segments.reduce(0.0) { $0 + $1.confidence }
        return sum / Float(segments.count)
    }
    
    public func stopTranscription() {
        enTask?.cancel()
        enTask = nil
        thTask?.cancel()
        thTask = nil
        enRequest?.endAudio()
        enRequest = nil
        thRequest?.endAudio()
        thRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        isRecording = false
    }
    
    private func restartContinuousStream() {
        guard isRecording else { return }
        stopTranscription()
        try? startTranscription()
    }
}
