import XCTest
@testable import AudioTunnelCore

final class AudioPacketTests: XCTestCase {
    func testSerializationRoundTrip() {
        let fakePcm = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let packet = AudioPacket(
            sequence: 42,
            timestamp: 1690000000000,
            sampleRate: 48000,
            channels: 2,
            format: 1,
            pcmData: fakePcm
        )

        let serialized = packet.serialize()
        XCTAssertGreaterThan(serialized.count, AudioPacket.headerSize)

        let deserialized = AudioPacket.deserialize(from: serialized)
        XCTAssertNotNil(deserialized)
        XCTAssertEqual(deserialized?.sequence, 42)
        XCTAssertEqual(deserialized?.timestamp, 1690000000000)
        XCTAssertEqual(deserialized?.sampleRate, 48000)
        XCTAssertEqual(deserialized?.channels, 2)
        XCTAssertEqual(deserialized?.pcmData, fakePcm)
    }

    func testCalculateRMS() {
        // Test silence
        let silentData = Data(repeating: 0, count: 2048)
        let silentRms = AudioPacket.calculateRMS(pcm16Data: silentData)
        XCTAssertEqual(silentRms, 0.0, accuracy: 0.001)

        // Test loud signal (alternating +30000 and -30000)
        var loudSamples = [Int16]()
        for i in 0..<1024 {
            loudSamples.append(i % 2 == 0 ? 30000 : -30000)
        }
        let loudData = loudSamples.withUnsafeBufferPointer { Data(buffer: $0) }
        let loudRms = AudioPacket.calculateRMS(pcm16Data: loudData)
        XCTAssertGreaterThan(loudRms, 0.8)
    }

    func testWebSocketBinaryFrameEncoding() {
        // 1. Small payload (<= 125 bytes)
        let smallPayload = Data(repeating: 0x55, count: 100)
        let smallFrame = AudioPacket.encodeWebSocketBinaryFrame(payload: smallPayload)
        XCTAssertEqual(smallFrame[0], 0x82) // Fin bit + Binary opcode
        XCTAssertEqual(smallFrame[1], 100)
        XCTAssertEqual(smallFrame.count, 2 + 100)

        // 2. Medium payload (> 125 bytes, <= 65535)
        let medPayload = Data(repeating: 0xAA, count: 2048)
        let medFrame = AudioPacket.encodeWebSocketBinaryFrame(payload: medPayload)
        XCTAssertEqual(medFrame[0], 0x82)
        XCTAssertEqual(medFrame[1], 126)
        XCTAssertEqual(medFrame.count, 4 + 2048)
    }
}
