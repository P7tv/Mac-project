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
    @Published public var selectedLocale: Locale = Locale(identifier: "en-US")
    @Published public var errorMessage: String? = nil
    
    public var onSegmentReceived: ((String, Bool) -> Void)? // (transcript, isFinal)
    
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    public init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: selectedLocale)
    }
    
    public static func supportedLocales() -> [Locale] {
        return [
            Locale(identifier: "en-US"),
            Locale(identifier: "en-GB"),
            Locale(identifier: "th-TH"),
            Locale(identifier: "ja-JP"),
            Locale(identifier: "zh-CN")
        ]
    }
    
    public func setLocale(_ locale: Locale) {
        self.selectedLocale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        if isRecording {
            stopTranscription()
            try? startTranscription()
        }
    }
    
    public func toggleTranscription() {
        if isRecording {
            stopTranscription()
        } else {
            do {
                try startTranscription()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    public func startTranscription() throws {
        stopTranscription()
        
        guard let recognizer = speechRecognizer ?? SFSpeechRecognizer(locale: selectedLocale),
              recognizer.isAvailable else {
            throw AudioEngineError.recognizerUnavailable
        }
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        
        // Add on-device preference if available for minimal latency
        if #available(macOS 14.0, *) {
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
        }
        
        self.audioEngine = engine
        self.recognitionRequest = request
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        
        try engine.start()
        
        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.currentTranscript = text
                    self.onSegmentReceived?(text, result.isFinal)
                }
                
                if error != nil || (result?.isFinal ?? false) {
                    if self.isRecording {
                        // Restart cycle for continuous listening if stream ended
                        self.restartContinuousStream()
                    }
                }
            }
        }
        
        self.isRecording = true
        self.errorMessage = nil
    }
    
    public func stopTranscription() {
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
