import XCTest
@testable import AudioTunnelCore

final class AudioConfigTests: XCTestCase {
    func testLatencyProfileProperties() {
        let ultraLow = LatencyProfile.ultraLow
        XCTAssertEqual(ultraLow.targetBufferMs, 25.0)
        XCTAssertEqual(ultraLow.targetFrames(sampleRate: 48000), 1200)

        let balanced = LatencyProfile.balanced
        XCTAssertEqual(balanced.targetBufferMs, 60.0)
        XCTAssertEqual(balanced.targetFrames(sampleRate: 48000), 2880)

        let smooth = LatencyProfile.smooth
        XCTAssertEqual(smooth.targetBufferMs, 120.0)
        XCTAssertEqual(smooth.targetFrames(sampleRate: 48000), 5760)
    }

    func testAudioSourceModes() {
        let modes = AudioSourceMode.allCases
        XCTAssertTrue(modes.contains(.systemAudio))
        XCTAssertTrue(modes.contains(.microphone))
        XCTAssertTrue(modes.contains(.testTone))
    }
}
