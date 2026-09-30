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

    func testChunkingOnWordThreshold() {
        let chunker = SpeechChunker()
        // Long speech without punctuation (18 words)
        let text = "I have been working with distributed microservices for over five years building scalable backends with Go and Kubernetes"
        let (committed, remainder) = chunker.process(fullTranscript: text, isFinal: false)
        
        XCTAssertFalse(committed.isEmpty, "Should break long unpunctuated speech into chunks")
        XCTAssertFalse(remainder.isEmpty, "Should have active remainder for continuous listening")
    }
}
