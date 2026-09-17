import Foundation

public enum AudioSourceMode: String, CaseIterable, Identifiable, Sendable {
    case systemAudio = "System Audio"
    case microphone = "Microphone"
    case testTone = "Test Generator"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .systemAudio: return "speaker.wave.3.fill"
        case .microphone: return "mic.fill"
        case .testTone: return "waveform.path"
        }
    }

    public var localizedDescription: String {
        switch self {
        case .systemAudio:
            return "เสียงระบบ Mac (ScreenCaptureKit)"
        case .microphone:
            return "ไมโครโฟน Mac / Wireless Mic"
        case .testTone:
            return "สัญญาณทดสอบ (Sine Wave 440Hz)"
        }
    }
}

public struct AudioFormatConfig: Sendable, Equatable {
    public var sampleRate: Double
    public var channels: Int
    public var bitDepth: Int
    public var bufferFrameSize: UInt32

    public init(
        sampleRate: Double = 48000,
        channels: Int = 2,
        bitDepth: Int = 16,
        bufferFrameSize: UInt32 = 1024
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
        self.bufferFrameSize = bufferFrameSize
    }

    public var bytesPerFrame: Int {
        return channels * (bitDepth / 8)
    }

    public var chunkSizeBytes: Int {
        return Int(bufferFrameSize) * bytesPerFrame
    }
}

public struct StreamStats: Sendable {
    public var connectedListeners: Int
    public var bytesStreamed: Int64
    public var packetsSent: Int64
    public var currentVolumeRMS: Float
    public var uptimeSeconds: Double

    public init(
        connectedListeners: Int = 0,
        bytesStreamed: Int64 = 0,
        packetsSent: Int64 = 0,
        currentVolumeRMS: Float = 0.0,
        uptimeSeconds: Double = 0.0
    ) {
        self.connectedListeners = connectedListeners
        self.bytesStreamed = bytesStreamed
        self.packetsSent = packetsSent
        self.currentVolumeRMS = currentVolumeRMS
        self.uptimeSeconds = uptimeSeconds
    }
}
