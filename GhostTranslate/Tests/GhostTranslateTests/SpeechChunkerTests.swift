import XCTest
@testable import GhostTranslateCore

final class SpeechChunkerTests: XCTestCase {
    func testChunkingOnPunctuation() {
        let chunker = SpeechChunker()
        let text = "Hello and welcome to the interview. Today we will discuss system design"
        let (committed, remainder) = chunker.process(fullTranscript: text, isFinal: false)

        XCTAssertEqual(committed.count, 1)
        XCTAssertTrue(committed[0].contains("Hello and welcome to the interview"))
        XCTAssertTrue(remainder.contains("Today we will discuss system design"))
    }

    func testLongUnpunctuatedSpeechStaysInOpenSentence() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        let update = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            transcript: "I have been working with distributed systems for several years without stopping"
        )))

        XCTAssertTrue(update.finalized.isEmpty)
        XCTAssertEqual(
            chunker.previewCurrentSentence(sessionID: sessionID, expectedRevision: update.revision)?.text,
            "I have been working with distributed systems for several years without stopping"
        )
    }

    func testStreamingSequence() {
        let chunker = SpeechChunker()

        // Step 1: Incomplete sentence
        let step1 = chunker.process(fullTranscript: "Hello everyone", isFinal: false)
        XCTAssertTrue(step1.committedSegments.isEmpty)
        XCTAssertEqual(step1.activeRemainder, "Hello everyone")

        // Step 2: Sentence completed with period
        let step2 = chunker.process(fullTranscript: "Hello everyone. Welcome", isFinal: false)
        XCTAssertEqual(step2.committedSegments.count, 1)
        XCTAssertTrue(step2.committedSegments[0].contains("Hello everyone"))
        XCTAssertEqual(step2.activeRemainder, "Welcome")

        // Step 3: Next words streamed, previous sentence shouldn't be re-emitted
        let step3 = chunker.process(fullTranscript: "Hello everyone. Welcome to the show today.", isFinal: false)
        // Only the second sentence is new
        XCTAssertEqual(step3.committedSegments.count, 1)
        XCTAssertTrue(step3.committedSegments[0].contains("Welcome to the show today"))

        // Step 4: Finalize
        let step4 = chunker.process(fullTranscript: "Hello everyone. Welcome to the show today. Thank you", isFinal: true)
        XCTAssertEqual(step4.committedSegments.count, 1)
        XCTAssertEqual(step4.committedSegments[0], "Thank you")
        XCTAssertEqual(step4.activeRemainder, "")
    }

    func testThaiTextChunking() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        let firstStream = UUID()
        let secondStream = UUID()
        _ = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: firstStream,
            locale: "th-TH",
            transcript: "ฉัน กำลัง ทำงาน"
        )))

        let update = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: secondStream,
            locale: "th-TH",
            transcript: "ทำงาน วันนี้"
        )))

        XCTAssertEqual(
            chunker.previewCurrentSentence(sessionID: sessionID, expectedRevision: update.revision)?.text,
            "ฉัน กำลัง ทำงาน วันนี้"
        )
    }

    func testRevisingSpeechStreamNoCrash() {
        let chunker = SpeechChunker()
        // Simulate rapid speech recognition revisions (e.g. word changes, length shortening)
        _ = chunker.process(fullTranscript: "Good morning ladies", isFinal: false)
        _ = chunker.process(fullTranscript: "Good morning ladies and gentlemen.", isFinal: false)
        _ = chunker.process(fullTranscript: "Good morning ladies and gentlemen. Today we", isFinal: false)
        // Recognizer resets or reconnects
        _ = chunker.process(fullTranscript: "Today we are starting", isFinal: false)
        _ = chunker.process(fullTranscript: "Today we are starting a new journey.", isFinal: true)
    }

    func testPreviewUsesWholeRevisedSentenceAndFinalizedSentenceAsContext() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        let streamID = UUID()

        let partial = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: streamID,
            transcript: "I joined the company"
        )))
        XCTAssertEqual(
            chunker.previewCurrentSentence(sessionID: sessionID, expectedRevision: partial.revision),
            SentenceTranslationInput(text: "I joined the company", context: nil)
        )

        let revised = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: streamID,
            transcript: "I joined the company. I work on search.",
            isFinal: true
        )))

        XCTAssertEqual(revised.finalized.map(\.text), ["I joined the company.", "I work on search."])
        XCTAssertEqual(revised.finalized[0].context, nil)
        XCTAssertEqual(revised.finalized[1].context, "I joined the company.")
    }

    func testRevisedPartialReplacesOpenSentence() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        let streamID = UUID()
        _ = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: streamID,
            transcript: "I joined a company"
        )))

        let revised = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: streamID,
            transcript: "I joined the company"
        )))

        XCTAssertEqual(
            chunker.previewCurrentSentence(sessionID: sessionID, expectedRevision: revised.revision)?.text,
            "I joined the company"
        )
    }

    func testNewStreamPreservesOpenSentenceAndDoesNotDuplicateOverlap() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        _ = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: UUID(),
            transcript: "I joined the company"
        )))

        let nextStream = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: UUID(),
            transcript: "company yesterday."
        )))

        XCTAssertEqual(nextStream.finalized.map(\.text), ["I joined the company yesterday."])
    }

    func testDuplicateSnapshotDoesNotFinalizeSentenceTwice() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        let streamID = UUID()
        let finalSentence = snapshot(
            sessionID: sessionID,
            streamID: streamID,
            transcript: "Hello there."
        )

        XCTAssertEqual(chunker.process(.snapshot(finalSentence)).finalized.map(\.text), ["Hello there."])
        XCTAssertTrue(chunker.process(.snapshot(finalSentence)).finalized.isEmpty)
    }

    func testTimedPauseRequestsFullOpenSentencePreview() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        let text = "The engineer joined the team and moved to Seattle"
        let pauseOffset = (text as NSString).range(of: "and").location
        let segmentEnd = pauseOffset
        let snapshot = SpeechRecognitionSnapshot(
            sessionID: sessionID,
            streamID: UUID(),
            localeIdentifier: "en-US",
            transcript: text,
            isFinal: false,
            receivedAtUptime: 2,
            segments: [
                SpeechSegmentTiming(substringRange: NSRange(location: 0, length: segmentEnd), timestamp: 0, duration: 1),
                SpeechSegmentTiming(
                    substringRange: NSRange(location: segmentEnd, length: (text as NSString).length - segmentEnd),
                    timestamp: 1.5,
                    duration: 0.7
                )
            ]
        )

        let update = chunker.process(.snapshot(snapshot))

        XCTAssertEqual(update.preview?.text, text)
    }

    func testUsesEarliestPunctuationAndSupportsJapaneseWithoutSpaces() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        let english = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: UUID(),
            transcript: "Is this okay? Yes, it is."
        )))
        XCTAssertEqual(english.finalized.map(\.text), ["Is this okay?", "Yes, it is."])

        let japanese = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: UUID(),
            locale: "ja-JP",
            transcript: "こんにちは。世界！",
            isFinal: true
        )))
        XCTAssertEqual(japanese.finalized.map(\.text), ["こんにちは。", "世界！"])
    }

    func testSessionEndFlushesOpenSentenceExactlyOnce() {
        let chunker = SpeechChunker()
        let sessionID = UUID()
        _ = chunker.process(.snapshot(snapshot(
            sessionID: sessionID,
            streamID: UUID(),
            transcript: "This sentence is still open"
        )))

        XCTAssertEqual(
            chunker.process(.sessionEnded(sessionID: sessionID)).finalized.map(\.text),
            ["This sentence is still open"]
        )
        XCTAssertTrue(chunker.process(.sessionEnded(sessionID: sessionID)).finalized.isEmpty)
    }

    private func snapshot(
        sessionID: UUID,
        streamID: UUID = UUID(),
        locale: String = "en-US",
        transcript: String,
        isFinal: Bool = false
    ) -> SpeechRecognitionSnapshot {
        SpeechRecognitionSnapshot(
            sessionID: sessionID,
            streamID: streamID,
            localeIdentifier: locale,
            transcript: transcript,
            isFinal: isFinal,
            receivedAtUptime: 1,
            segments: []
        )
    }
}
