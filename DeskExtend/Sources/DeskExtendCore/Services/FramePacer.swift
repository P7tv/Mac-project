import Foundation

// One frame in transit and one replaceable latest frame per receiver.
// Accessed under StreamServer's lock.
struct FramePacer {
    let requiresAcknowledgement: Bool
    private var sending = false
    private var awaitingAcknowledgement = false
    private var latest: Data?

    init(requiresAcknowledgement: Bool) {
        self.requiresAcknowledgement = requiresAcknowledgement
    }

    mutating func offer(_ frame: Data) -> Data? {
        latest = frame
        return takeReadyFrame()
    }

    mutating func sent() -> Data? {
        sending = false
        return takeReadyFrame()
    }

    mutating func acknowledge() -> Data? {
        awaitingAcknowledgement = false
        return takeReadyFrame()
    }

    private mutating func takeReadyFrame() -> Data? {
        guard !sending, !awaitingAcknowledgement, let frame = latest else { return nil }
        latest = nil
        sending = true
        awaitingAcknowledgement = requiresAcknowledgement
        return frame
    }
}

// Receiver traffic consists only of small masked binary ACKs and control frames.
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
            let length = Int(bytes[1] & 0x7F)
            guard bytes[0] & 0xF0 == 0x80, bytes[1] & 0x80 != 0,
                  [2, 8, 9, 10].contains(opcode), length <= 125 else {
                throw ParseError.invalidFrame
            }
            let frameLength = 6 + length
            guard bytes.count >= frameLength else { break }
            let payload = Data((0..<length).map { bytes[6 + $0] ^ bytes[2 + $0 % 4] })
            messages.append(Message(opcode: opcode, payload: payload))
            buffer = Data(bytes.dropFirst(frameLength))
        }
        return messages
    }
}
