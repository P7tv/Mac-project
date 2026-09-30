import XCTest
@testable import GhostTranslateCore

@MainActor
final class AudioTranscriptionTests: XCTestCase {
    func testEngineInitialization() {
        let engine = AudioTranscriptionEngine()
        XCTAssertFalse(engine.isRecording)
        XCTAssertTrue(engine.currentTranscript.isEmpty)
    }

    func testLocaleSupported() {
        let supported = AudioTranscriptionEngine.supportedLocales()
        XCTAssertTrue(supported.contains(where: { $0.identifier.hasPrefix("en") }))
        XCTAssertTrue(supported.contains(where: { $0.identifier.hasPrefix("th") }))
    }

    func testRecognitionStreamKeepsSessionAndChangesStream() {
        var tracker = RecognitionSessionTracker()
        let first = tracker.beginSession()
        let nextStream = tracker.beginStream()

        XCTAssertEqual(nextStream.sessionID, first.sessionID)
        XCTAssertNotEqual(nextStream.streamID, first.streamID)
    }

    func testRecognitionTrackerRejectsCallbacksFromRotatedStream() {
        var tracker = RecognitionSessionTracker()
        let previousStream = tracker.beginSession()
        XCTAssertTrue(tracker.accepts(previousStream))

        let currentStream = tracker.beginStream()

        XCTAssertFalse(tracker.accepts(previousStream))
        XCTAssertTrue(tracker.accepts(currentStream))
    }

    func testEndingSessionCreatesANewSessionOnNextStart() {
        var tracker = RecognitionSessionTracker()
        let first = tracker.beginSession()

        XCTAssertEqual(tracker.endSession(), first.sessionID)
        let nextSession = tracker.beginSession()

        XCTAssertNotEqual(nextSession.sessionID, first.sessionID)
        XCTAssertNotEqual(nextSession.streamID, first.streamID)
    }
}
