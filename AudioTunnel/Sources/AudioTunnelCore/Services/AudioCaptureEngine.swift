import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import ScreenCaptureKit

private final class InputState: @unchecked Sendable {
    var consumed = false
}

public protocol AudioCaptureEngineDelegate: AnyObject, Sendable {
    func audioCaptureEngine(didCapturePCMData data: Data, rmsLevel: Float)
    func audioCaptureEngine(didFailWithError error: Error)
}

public final class AudioCaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var scStream: SCStream?
    private var audioEngine: AVAudioEngine?
    private var testTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.audiotunnel.capture", qos: .userInteractive)

    private let lock = NSLock()
    private var _isCapturing = false
    private var _currentMode: AudioSourceMode = .systemAudio
    private var _sequenceNumber: UInt32 = 0

    public weak var delegate: AudioCaptureEngineDelegate?

    public var isCapturing: Bool {
        lock.withLock { _isCapturing }
    }

    public var currentMode: AudioSourceMode {
        lock.withLock { _currentMode }
    }

    public override init() {
        super.init()
    }

    public func start(mode: AudioSourceMode) async throws {
        stop()

        lock.withLock {
            _isCapturing = true
            _currentMode = mode
            _sequenceNumber = 0
        }

        switch mode {
        case .systemAudio:
            do {
                try await startScreenCaptureKitAudio()
            } catch {
                // Fall back to test tone if ScreenCaptureKit permission isn't granted
                print("[AudioTunnel] ScreenCaptureKit audio failed (\(error.localizedDescription)), falling back to test tone.")
                startTestToneGenerator()
            }
        case .microphone:
            try startMicrophoneCapture()
        case .testTone:
            startTestToneGenerator()
        }
    }

    public func stop() {
        lock.withLock {
            _isCapturing = false
        }

        // Stop SCStream
        if let stream = scStream {
            stream.stopCapture { _ in }
            scStream = nil
        }

        // Stop AVAudioEngine
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            audioEngine = nil
        }

        // Stop Test Tone
        if let timer = testTimer {
            timer.cancel()
            testTimer = nil
        }
    }

    // MARK: - ScreenCaptureKit Audio
    private func startScreenCaptureKitAudio() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw NSError(domain: "AudioTunnel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active display found for audio tap"])
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        // Minimize video overhead to almost nothing since we only care about audio
        config.width = 64
        config.height = 64
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps video dummy

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.scStream = stream
    }

    // MARK: - SCStreamOutput
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, isCapturing else { return }
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        let length = CMBlockBufferGetDataLength(blockBuffer)
        guard length > 0 else { return }

        var rawData = Data(count: length)
        rawData.withUnsafeMutableBytes { ptr in
            _ = CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
        }

        // Check format description: if float32, convert to int16
        var pcm16Data: Data
        if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
            if asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                pcm16Data = convertFloat32ToInt16(rawData: rawData, channelCount: Int(asbd.pointee.mChannelsPerFrame))
            } else {
                pcm16Data = rawData
            }
        } else {
            pcm16Data = rawData
        }

        let rms = AudioPacket.calculateRMS(pcm16Data: pcm16Data)
        delegate?.audioCaptureEngine(didCapturePCMData: pcm16Data, rmsLevel: rms)
    }

    // MARK: - Microphone Capture (AVAudioEngine)
    private func startMicrophoneCapture() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        // Output format: 48kHz, 2 channels, 16-bit integer
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 48000,
            channels: 2,
            interleaved: true
        ) else {
            throw NSError(domain: "AudioTunnel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
        }

        guard let formatConverter = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            throw NSError(domain: "AudioTunnel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hwFormat) { [weak self] inputBuffer, _ in
            guard let self = self, self.isCapturing else { return }

            let frameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * 48000.0 / hwFormat.sampleRate)
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: max(frameCapacity, 1024)) else { return }

            let state = InputState()
            var convError: NSError?
            formatConverter.convert(to: outputBuffer, error: &convError) { _, outStatus in
                if !state.consumed {
                    state.consumed = true
                    outStatus.pointee = .haveData
                    return inputBuffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            if let channelData = outputBuffer.int16ChannelData {
                let bytesCount = Int(outputBuffer.frameLength) * 2 * MemoryLayout<Int16>.size
                let data = Data(bytes: channelData[0], count: bytesCount)
                let rms = AudioPacket.calculateRMS(pcm16Data: data)
                self.delegate?.audioCaptureEngine(didCapturePCMData: data, rmsLevel: rms)
            }
        }

        try engine.start()
        self.audioEngine = engine
    }

    // MARK: - Test Tone Generator (440 Hz Sine)
    private func startTestToneGenerator() {
        let sampleRate: Double = 48000
        let frequency: Double = 440.0
        let frameSize = 1024
        var phase: Double = 0.0

        let timer = DispatchSource.makeTimerSource(queue: queue)
        let intervalMs = Int((Double(frameSize) / sampleRate) * 1000.0)
        timer.schedule(deadline: .now(), repeating: .milliseconds(max(intervalMs, 10)))

        timer.setEventHandler { [weak self] in
            guard let self = self, self.isCapturing else { return }

            var samples = [Int16]()
            samples.reserveCapacity(frameSize * 2)

            for _ in 0..<frameSize {
                let sampleVal = sin(phase) * 0.4 // 40% volume
                let intVal = Int16(clamping: Int(sampleVal * 32767.0))
                samples.append(intVal) // Left
                samples.append(intVal) // Right

                phase += 2.0 * Double.pi * frequency / sampleRate
                if phase > 2.0 * Double.pi {
                    phase -= 2.0 * Double.pi
                }
            }

            let data = samples.withUnsafeBufferPointer { Data(buffer: $0) }
            let rms = AudioPacket.calculateRMS(pcm16Data: data)
            self.delegate?.audioCaptureEngine(didCapturePCMData: data, rmsLevel: rms)
        }

        timer.resume()
        self.testTimer = timer
    }

    // MARK: - Helpers
    private func convertFloat32ToInt16(rawData: Data, channelCount: Int) -> Data {
        let floatCount = rawData.count / MemoryLayout<Float32>.size
        var result = Data(capacity: floatCount * MemoryLayout<Int16>.size)

        rawData.withUnsafeBytes { rawPtr in
            let floats = rawPtr.bindMemory(to: Float32.self)
            for i in 0..<floatCount {
                let val = floats[i]
                var int16Val = Int16(clamping: Int(val * 32767.0))
                result.append(contentsOf: withUnsafeBytes(of: &int16Val) { Array($0) })
            }
        }

        return result
    }
}
