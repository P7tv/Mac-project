import Foundation

// One frame in transit and one replaceable latest frame per receiver.
// Accessed under StreamServer's lock.
struct FramePacer {
    let requiresAcknowledgement: Bool
    private var sending = false
    private var awaitingAcknowledgement = false
    private var lastSendTime: CFAbsoluteTime = 0
    private var latest: Data?
    public var ackTimeoutSeconds: Double

    init(requiresAcknowledgement: Bool, ackTimeoutSeconds: Double = 0.5) {
        self.requiresAcknowledgement = requiresAcknowledgement
        self.ackTimeoutSeconds = ackTimeoutSeconds
    }

    mutating func offer(_ frame: Data, now: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> Data? {
        latest = frame
        checkAckTimeout(now: now)
        return takeReadyFrame(now: now)
    }

    mutating func sent(now: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> Data? {
        sending = false
        lastSendTime = now
        return takeReadyFrame(now: now)
    }

    mutating func acknowledge(now: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> Data? {
        awaitingAcknowledgement = false
        return takeReadyFrame(now: now)
    }

    private mutating func checkAckTimeout(now: CFAbsoluteTime) {
        if awaitingAcknowledgement && (now - lastSendTime >= ackTimeoutSeconds) {
            // ACK timed out (due to packet loss or client delay); break deadlock
            awaitingAcknowledgement = false
        }
    }

    private mutating func takeReadyFrame(now: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> Data? {
        checkAckTimeout(now: now)
        guard !sending, !awaitingAcknowledgement, let frame = latest else { return nil }
        latest = nil
        sending = true
        lastSendTime = now
        awaitingAcknowledgement = requiresAcknowledgement
        return frame
    }
}

// Receiver traffic consists of masked binary ACKs, control frames, and heartbeats.
// TCP may split a frame or combine several frames in a receive callback.
struct ReceiverControlParser {
    struct Message {
        let opcode: UInt8
        let payload: Data
    }
    enum ParseError: Error { case invalidFrame }
    private var buffer = Data()

    mutating func append(_ bytes: Data) throws -> [Message] {
        buffer.append(bytes)
        var messages: [Message] = []
        while buffer.count >= 2 {
            let bytes = [UInt8](buffer)
            let opcode = bytes[0] & 0x0F
            let isMasked = (bytes[1] & 0x80) != 0
            let length = Int(bytes[1] & 0x7F)

            // Validate FIN bit (0x80), required masking from client, supported opcodes (1, 2, 8, 9, 10), and control length <= 125
            guard bytes[0] & 0xF0 == 0x80, isMasked, [1, 2, 8, 9, 10].contains(opcode), length <= 125 else {
                throw ParseError.invalidFrame
            }

            let maskOffset = 2
            let payloadOffset = maskOffset + 4
            let totalFrameLength = payloadOffset + length
            guard bytes.count >= totalFrameLength else { break }

            let mask = Array(bytes[maskOffset..<payloadOffset])
            var payload = [UInt8](repeating: 0, count: length)
            for i in 0..<length {
                payload[i] = bytes[payloadOffset + i] ^ mask[i % 4]
            }

            messages.append(Message(opcode: opcode, payload: Data(payload)))
            buffer = Data(bytes.dropFirst(totalFrameLength))
        }
        return messages
    }
}
