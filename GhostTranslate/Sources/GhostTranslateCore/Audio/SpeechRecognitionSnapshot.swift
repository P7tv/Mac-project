import Foundation

public struct SpeechSegmentTiming: Equatable {
    public let substringRange: NSRange
    public let timestamp: TimeInterval
    public let duration: TimeInterval

    public var endTime: TimeInterval { timestamp + duration }

    public init(substringRange: NSRange, timestamp: TimeInterval, duration: TimeInterval) {
        self.substringRange = substringRange
        self.timestamp = timestamp
        self.duration = duration
    }
}

public struct SpeechRecognitionSnapshot: Equatable {
    public let sessionID: UUID
    public let streamID: UUID
    public let localeIdentifier: String
    public let transcript: String
    public let isFinal: Bool
    public let receivedAtUptime: TimeInterval
    public let segments: [SpeechSegmentTiming]

    public init(
        sessionID: UUID,
        streamID: UUID,
        localeIdentifier: String,
        transcript: String,
        isFinal: Bool,
        receivedAtUptime: TimeInterval,
        segments: [SpeechSegmentTiming]
    ) {
        self.sessionID = sessionID
        self.streamID = streamID
        self.localeIdentifier = localeIdentifier
        self.transcript = transcript
        self.isFinal = isFinal
        self.receivedAtUptime = receivedAtUptime
        self.segments = segments
    }
}

public struct RecognitionStreamIdentity: Equatable {
    public let sessionID: UUID
    public let streamID: UUID

    public init(sessionID: UUID, streamID: UUID) {
        self.sessionID = sessionID
        self.streamID = streamID
    }
}

public enum SpeechRecognitionEvent: Equatable {
    case snapshot(SpeechRecognitionSnapshot)
    case sessionEnded(sessionID: UUID)
}

public struct SentenceTranslationInput: Equatable {
    public let text: String
    public let context: String?

    public init(text: String, context: String?) {
        self.text = text
        self.context = context
    }
}

public struct SpeechChunkingUpdate: Equatable {
    public let revision: UInt64
    public let preview: SentenceTranslationInput?
    public let finalized: [SentenceTranslationInput]

    public init(
        revision: UInt64,
        preview: SentenceTranslationInput?,
        finalized: [SentenceTranslationInput]
    ) {
        self.revision = revision
        self.preview = preview
        self.finalized = finalized
    }
}
