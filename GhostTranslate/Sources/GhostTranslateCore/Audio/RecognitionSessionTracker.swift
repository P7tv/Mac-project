import Foundation

public struct RecognitionSessionTracker {
    public private(set) var activeSessionID: UUID?

    public init() {}

    public mutating func beginSession() -> RecognitionStreamIdentity {
        let sessionID = UUID()
        activeSessionID = sessionID
        return RecognitionStreamIdentity(sessionID: sessionID, streamID: UUID())
    }

    public mutating func beginStream() -> RecognitionStreamIdentity {
        guard let sessionID = activeSessionID else {
            return beginSession()
        }
        return RecognitionStreamIdentity(sessionID: sessionID, streamID: UUID())
    }

    @discardableResult
    public mutating func endSession() -> UUID? {
        let endedSessionID = activeSessionID
        activeSessionID = nil
        return endedSessionID
    }
}
