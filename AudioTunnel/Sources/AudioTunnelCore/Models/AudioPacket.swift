import Foundation

public struct AudioPacket: Sendable, Equatable {
    public static let magic: UInt32 = 0x4154554E // "ATUN"
    public static let headerSize: Int = 24

    public let sequence: UInt32
    public let timestamp: UInt64
    public let sampleRate: UInt16
    public let channels: UInt8
    public let format: UInt8 // 1 = Int16 PCM, 2 = Float32 PCM
    public let pcmData: Data

    public init(
        sequence: UInt32,
        timestamp: UInt64,
        sampleRate: UInt16 = 48000,
        channels: UInt8 = 2,
        format: UInt8 = 1,
        pcmData: Data
    ) {
        self.sequence = sequence
        self.timestamp = timestamp
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
        self.pcmData = pcmData
    }

    /// Serializes packet with binary header for low-latency UDP or custom TCP clients
    public func serialize() -> Data {
        var data = Data(capacity: Self.headerSize + pcmData.count)
        
        var magic = Self.magic.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &magic) { Array($0) })

        var seq = sequence.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &seq) { Array($0) })

        var ts = timestamp.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &ts) { Array($0) })

        var sr = sampleRate.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &sr) { Array($0) })

        data.append(channels)
        data.append(format)

        var payloadLen = UInt32(pcmData.count).bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &payloadLen) { Array($0) })

        data.append(pcmData)
        return data
    }

    /// Deserializes binary packet
    public static func deserialize(from data: Data) -> AudioPacket? {
        guard data.count >= headerSize else { return nil }

        let magic = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard magic == Self.magic else { return nil }

        let seq = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let ts = data.subdata(in: 8..<16).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let sr = data.subdata(in: 16..<18).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        let ch = data[18]
        let fmt = data[19]
        let payloadLen = Int(data.subdata(in: 20..<24).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

        guard data.count >= headerSize + payloadLen else { return nil }
        let payload = data.subdata(in: headerSize..<(headerSize + payloadLen))

        return AudioPacket(
            sequence: seq,
            timestamp: ts,
            sampleRate: sr,
            channels: ch,
            format: fmt,
            pcmData: payload
        )
    }

    /// Calculate RMS audio level between 0.0 (silent) and 1.0 (peak clipping)
    public static func calculateRMS(pcm16Data: Data) -> Float {
        guard !pcm16Data.isEmpty else { return 0.0 }
        let count = pcm16Data.count / MemoryLayout<Int16>.size
        guard count > 0 else { return 0.0 }

        var sumSquares: Double = 0.0
        pcm16Data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<count {
                let val = Double(samples[i]) / 32768.0
                sumSquares += val * val
            }
        }

        let mean = sumSquares / Double(count)
        let rms = sqrt(mean)
        // Normalize and clamp between 0.0 and 1.0
        return Float(min(max(rms * 1.5, 0.0), 1.0))
    }

    /// Encodes raw PCM into RFC 6455 Binary WebSocket Frame (opcode 0x02, unmasked server->client)
    public static func encodeWebSocketBinaryFrame(payload: Data) -> Data {
        var frame = Data()
        // Fin bit (0x80) + Binary Opcode (0x02) = 0x82
        frame.append(0x82)

        let len = payload.count
        if len <= 125 {
            frame.append(UInt8(len))
        } else if len <= 65535 {
            frame.append(126)
            var len16 = UInt16(len).bigEndian
            frame.append(contentsOf: withUnsafeBytes(of: &len16) { Array($0) })
        } else {
            frame.append(127)
            var len64 = UInt64(len).bigEndian
            frame.append(contentsOf: withUnsafeBytes(of: &len64) { Array($0) })
        }

        frame.append(payload)
        return frame
    }
}
