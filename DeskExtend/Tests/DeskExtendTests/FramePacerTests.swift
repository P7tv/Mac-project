import XCTest
@testable import DeskExtendCore

final class FramePacerTests: XCTestCase {
    func testSlowReceiverGetsNewestFrameAfterAcknowledging() {
        var pacer = FramePacer(requiresAcknowledgement: true)
        XCTAssertEqual(pacer.offer(Data([1])), Data([1]))
        XCTAssertNil(pacer.sent(), "Socket completion must not bypass receiver acknowledgement")
        for number in 2...200 {
            XCTAssertNil(pacer.offer(Data([UInt8(number)])))
        }
        XCTAssertEqual(pacer.acknowledge(), Data([200]), "Skip obsolete frames rather than replaying the backlog")
        XCTAssertNil(pacer.sent())
        XCTAssertNil(pacer.acknowledge())
        XCTAssertEqual(pacer.offer(Data([201])), Data([201]))
    }

    func testEarlyAcknowledgementStillWaitsForSendCompletion() {
        var pacer = FramePacer(requiresAcknowledgement: true)
        XCTAssertEqual(pacer.offer(Data([1])), Data([1]))
        XCTAssertNil(pacer.offer(Data([2])))
        XCTAssertNil(pacer.acknowledge())
        XCTAssertEqual(pacer.sent(), Data([2]))
    }

    func testLegacyReceiverHasBoundedSendQueue() {
        var pacer = FramePacer(requiresAcknowledgement: false)
        XCTAssertEqual(pacer.offer(Data([1])), Data([1]))
        XCTAssertNil(pacer.offer(Data([2])))
        XCTAssertNil(pacer.offer(Data([3])))
        XCTAssertEqual(pacer.sent(), Data([3]))
        XCTAssertNil(pacer.sent())
    }

    func testIndependentReceiversDoNotBlockEachOther() {
        var slow = FramePacer(requiresAcknowledgement: true)
        var fast = FramePacer(requiresAcknowledgement: true)
        _ = slow.offer(Data([1]))
        _ = fast.offer(Data([1]))
        _ = slow.sent()
        _ = fast.sent()
        _ = fast.acknowledge()
        XCTAssertNil(slow.offer(Data([2])))
        XCTAssertEqual(fast.offer(Data([2])), Data([2]))
    }

    func testMaskedAcknowledgementsSurviveSplitAndCombinedTCPReads() throws {
        var parser = ReceiverControlParser()
        let ack = Data([0x82, 0x81, 0x12, 0x34, 0x56, 0x78, 0x13])
        XCTAssertTrue(try parser.append(ack.prefix(3)).isEmpty)
        let messages = try parser.append(ack.dropFirst(3) + ack)
        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(messages.allSatisfy { $0.opcode == 2 && $0.payload == Data([1]) })
    }

    func testPingAndCloseControlFramesAreDecoded() throws {
        var parser = ReceiverControlParser()
        let messages = try parser.append(Data([0x89, 0x81, 0, 0, 0, 0, 42, 0x88, 0x80, 0, 0, 0, 0]))
        XCTAssertEqual(messages.map(\.opcode), [9, 8])
        XCTAssertEqual(messages[0].payload, Data([42]))
    }

    func testInvalidReceiverTrafficIsRejected() {
        for bytes in [Data([0x82, 0x01]), Data([0x82, 0xFE]), Data([0x02, 0x81])] {
            var parser = ReceiverControlParser()
            XCTAssertThrowsError(try parser.append(bytes))
        }
    }
}
