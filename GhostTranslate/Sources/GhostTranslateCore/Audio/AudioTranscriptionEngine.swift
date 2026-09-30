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
    public var onRecognitionEvent: (@MainActor (SpeechRecognitionEvent) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var sessionTracker = RecognitionSessionTracker()

    public init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: selectedLocale)
    }

    public static func supportedLocales() -> [Locale] {
        return [
            Locale(identifier: "en-US"),
            Locale(identifier: "th-TH"),
            Locale(identifier: "ja-JP"),
            Locale(identifier: "zh-CN")
        ]
    }

    public func setLocale(_ locale: Locale) {
        guard locale != selectedLocale else { return }
        let wasRecording = isRecording
        if wasRecording {
            stopTranscription()
        }
        self.selectedLocale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        if wasRecording {
            try? startTranscription()
        }
    }

    public func toggleLanguage() {
        if selectedLocale.identifier.hasPrefix("en") {
            setLocale(Locale(identifier: "th-TH"))
        } else {
            setLocale(Locale(identifier: "en-US"))
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
                        self?.errorMessage = "Speech Recognition permission was not granted."
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
        if sessionTracker.activeSessionID != nil {
            stopTranscription()
        } else {
            tearDownRecognitionStream()
        }

        guard let recognizer = speechRecognizer ?? SFSpeechRecognizer(locale: selectedLocale),
              recognizer.isAvailable else {
            throw AudioEngineError.recognizerUnavailable
        }

        let identity = sessionTracker.beginSession()
        do {
            try startRecognitionStream(identity: identity, recognizer: recognizer)
        } catch {
            _ = sessionTracker.endSession()
            tearDownRecognitionStream()
            throw error
        }
    }

    public func stopTranscription() {
        let endedSessionID = sessionTracker.endSession()
        tearDownRecognitionStream()
        isRecording = false
        if let endedSessionID {
            onRecognitionEvent?(.sessionEnded(sessionID: endedSessionID))
        }
    }

    public func restartRecognitionStream() {
        guard isRecording else { return }
        restartContinuousStream()
    }

    private func startRecognitionStream(
        identity: RecognitionStreamIdentity,
        recognizer: SFSpeechRecognizer
    ) throws {
        guard recognizer.isAvailable else {
            throw AudioEngineError.recognizerUnavailable
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw AudioEngineError.audioInputUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        self.audioEngine = engine
        self.recognitionRequest = request
        self.currentTranscript = ""

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        try engine.start()

        isRecording = true
        errorMessage = nil
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self,
                      self.isRecording,
                      self.sessionTracker.accepts(identity) else { return }

                if let result = result {
                    let transcription = result.bestTranscription
                    let text = transcription.formattedString
                    self.currentTranscript = text
                    let snapshot = SpeechRecognitionSnapshot(
                        sessionID: identity.sessionID,
                        streamID: identity.streamID,
                        localeIdentifier: self.selectedLocale.identifier,
                        transcript: text,
                        isFinal: result.isFinal,
                        receivedAtUptime: ProcessInfo.processInfo.systemUptime,
                        segments: transcription.segments.map {
                            SpeechSegmentTiming(
                                substringRange: $0.substringRange,
                                timestamp: $0.timestamp,
                                duration: $0.duration
                            )
                        }
                    )
                    self.onRecognitionEvent?(.snapshot(snapshot))
                    self.onSegmentReceived?(text, result.isFinal)
                }

                if let error = error as NSError? {
                    if error.code == 203 && self.isRecording {
                        // Natural 1-minute audio silence timeout: seamlessly reconnect
                        self.restartContinuousStream()
                    } else if !self.isRecording {
                        // User stopped, ignore
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                } else if result?.isFinal ?? false {
                    if self.isRecording {
                        self.restartContinuousStream()
                    }
                }
            }
        }
    }

    private func restartContinuousStream() {
        guard isRecording else { return }
        tearDownRecognitionStream()
        let identity = sessionTracker.beginStream()
        guard let recognizer = speechRecognizer ?? SFSpeechRecognizer(locale: selectedLocale) else {
            errorMessage = AudioEngineError.recognizerUnavailable.localizedDescription
            stopTranscription()
            return
        }
        do {
            try startRecognitionStream(identity: identity, recognizer: recognizer)
        } catch {
            errorMessage = error.localizedDescription
            stopTranscription()
        }
    }

    private func tearDownRecognitionStream() {
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
    }
}
