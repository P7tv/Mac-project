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
}
