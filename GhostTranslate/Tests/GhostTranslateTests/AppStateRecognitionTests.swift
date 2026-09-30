import XCTest
@testable import GhostTranslateCore

@MainActor
final class AppStateRecognitionTests: XCTestCase {
    func testClearRestartsRecognitionStreamAndAcceptsFreshTranscript() throws {
        let engine = AudioTranscriptionEngine.shared
        let previousHandler = engine.onRecognitionEvent
        let previousSegmentHandler = engine.onSegmentReceived
        defer {
            engine.onRecognitionEvent = previousHandler
            engine.onSegmentReceived = previousSegmentHandler
        }

        var tracker = RecognitionSessionTracker()
        let firstStream = tracker.beginSession()
        var restartedStream: RecognitionStreamIdentity?
        let appState = AppState(restartRecognitionStream: {
            restartedStream = tracker.beginStream()
        }, interviewPromptGenerator: nil, subtitleTranslator: nil)

        engine.onRecognitionEvent?(.snapshot(snapshot(
            identity: firstStream,
            transcript: "Old transcript still accumulating"
        )))
        XCTAssertEqual(appState.originalText, "Old transcript still accumulating")

        appState.clear()

        let nextStream = try XCTUnwrap(restartedStream)
        XCTAssertEqual(nextStream.sessionID, firstStream.sessionID)
        XCTAssertNotEqual(nextStream.streamID, firstStream.streamID)
        XCTAssertEqual(appState.originalText, "")

        engine.onRecognitionEvent?(.snapshot(snapshot(
            identity: nextStream,
            transcript: "Fresh speech after clear"
        )))
        XCTAssertEqual(appState.originalText, "Fresh speech after clear")

        appState.clear()
    }

    func testFinalizedQuestionRunsInterviewCopilotInsteadOfSubtitleTranslation() async {
        let engine = AudioTranscriptionEngine.shared
        let previousHandler = engine.onRecognitionEvent
        let previousSegmentHandler = engine.onSegmentReceived
        let previousMode = GhostWindowManager.shared.currentMode
        var tracker = RecognitionSessionTracker()
        let identity = tracker.beginSession()
        let copilotExpectation = expectation(description: "Interview question is analyzed")
        var analyzedQuestion = ""
        let result = InterviewPromptResult(
            questionSummary: "สรุปคำถาม",
            bulletPoints: ["ใช้ตัวอย่างที่วัดผลได้"],
            rawText: "response"
        )
        let appState = AppState(
            restartRecognitionStream: { _ = tracker.beginStream() },
            interviewPromptGenerator: { question in
                analyzedQuestion = question
                copilotExpectation.fulfill()
                return result
            },
            subtitleTranslator: { _ in
                XCTFail("Finalized interview questions should use the interview co-pilot")
                return "unexpected subtitle translation"
            }
        )
        defer {
            appState.clear()
            engine.onRecognitionEvent = previousHandler
            engine.onSegmentReceived = previousSegmentHandler
            GhostWindowManager.shared.currentMode = previousMode
        }

        GhostWindowManager.shared.currentMode = .interviewPrompter
        engine.onRecognitionEvent?(.snapshot(snapshot(
            identity: identity,
            transcript: "Tell me about a difficult project. How did you measure success?",
            isFinal: true
        )))

        await fulfillment(of: [copilotExpectation], timeout: 1)

        XCTAssertEqual(analyzedQuestion, "Tell me about a difficult project. How did you measure success?")
        XCTAssertEqual(appState.interviewResult, result)
        XCTAssertEqual(appState.originalText, analyzedQuestion)
    }

    func testSwitchingToInterviewCopilotAnalyzesAlreadyRecognizedQuestion() async {
        let engine = AudioTranscriptionEngine.shared
        let previousHandler = engine.onRecognitionEvent
        let previousSegmentHandler = engine.onSegmentReceived
        let previousMode = GhostWindowManager.shared.currentMode
        var tracker = RecognitionSessionTracker()
        let identity = tracker.beginSession()
        let subtitleExpectation = expectation(description: "Recognized question is translated in subtitle mode")
        let copilotExpectation = expectation(description: "Existing question is analyzed after switching modes")
        let question = "Tell me about a difficult project."
        var analyzedQuestion = ""
        let appState = AppState(
            restartRecognitionStream: {},
            interviewPromptGenerator: { text in
                analyzedQuestion = text
                copilotExpectation.fulfill()
                return InterviewPromptResult(
                    questionSummary: "สรุปคำถาม",
                    bulletPoints: ["ใช้ตัวอย่างที่วัดผลได้"],
                    rawText: "response"
                )
            },
            subtitleTranslator: { _ in
                subtitleExpectation.fulfill()
                return "คำแปล"
            }
        )
        defer {
            appState.clear()
            engine.onRecognitionEvent = previousHandler
            engine.onSegmentReceived = previousSegmentHandler
            GhostWindowManager.shared.currentMode = previousMode
        }

        GhostWindowManager.shared.currentMode = .subtitleBar
        engine.onRecognitionEvent?(.snapshot(snapshot(
            identity: identity,
            transcript: question,
            isFinal: true
        )))
        await fulfillment(of: [subtitleExpectation], timeout: 1)

        GhostWindowManager.shared.currentMode = .interviewPrompter
        await fulfillment(of: [copilotExpectation], timeout: 1)

        XCTAssertEqual(analyzedQuestion, question)
    }

    private func snapshot(
        identity: RecognitionStreamIdentity,
        transcript: String,
        isFinal: Bool = false
    ) -> SpeechRecognitionSnapshot {
        SpeechRecognitionSnapshot(
            sessionID: identity.sessionID,
            streamID: identity.streamID,
            localeIdentifier: "en-US",
            transcript: transcript,
            isFinal: isFinal,
            receivedAtUptime: 1,
            segments: []
        )
    }
}
