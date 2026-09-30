import Foundation

public struct RecognitionSessionTracker {
    public private(set) var activeSessionID: UUID?
    public private(set) var activeStreamID: UUID?

    public init() {}

    public mutating func beginSession() -> RecognitionStreamIdentity {
        let sessionID = UUID()
        let streamID = UUID()
        activeSessionID = sessionID
        activeStreamID = streamID
        return RecognitionStreamIdentity(sessionID: sessionID, streamID: streamID)
    }

    public mutating func beginStream() -> RecognitionStreamIdentity {
        guard let sessionID = activeSessionID else {
            return beginSession()
        }
        let streamID = UUID()
        activeStreamID = streamID
        return RecognitionStreamIdentity(sessionID: sessionID, streamID: streamID)
    }

    public func accepts(_ identity: RecognitionStreamIdentity) -> Bool {
        activeSessionID == identity.sessionID && activeStreamID == identity.streamID
    }

    @discardableResult
    public mutating func endSession() -> UUID? {
        let endedSessionID = activeSessionID
        activeSessionID = nil
        activeStreamID = nil
        return endedSessionID
    }
}
