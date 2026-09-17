import Foundation
import CoreGraphics
import AppKit
import ImageIO

public protocol ScreenSamplerDelegate: AnyObject, Sendable {
    func screenSampler(didCaptureRecord record: RecallRecord)
    func screenSampler(didSkipReason: String)
}

public final class ScreenSampler: @unchecked Sendable {
    private let database: RecallDatabase
    private let ocrEngine: NeuralOCREngine
    private let queue = DispatchQueue(label: "com.quickrecall.sampler", qos: .utility)
    private var timer: DispatchSourceTimer?
    private let thumbnailsDirectory: URL

    private let lock = NSLock()
    private var _config: RecallConfig
    private var _lastHash: UInt64 = 0
    private var _isSampling = false

    public weak var delegate: ScreenSamplerDelegate?

    public var config: RecallConfig {
        get { lock.withLock { _config } }
        set { lock.withLock { _config = newValue } }
    }

    public var isSampling: Bool {
        lock.withLock { _isSampling }
    }

    public init(database: RecallDatabase, config: RecallConfig = RecallConfig()) {
        self.database = database
        self.ocrEngine = NeuralOCREngine()
        self._config = config

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let thumbs = appSupport.appendingPathComponent("QuickRecall/thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: thumbs, withIntermediateDirectories: true)
        self.thumbnailsDirectory = thumbs
    }

    public func start() {
        stop()

        lock.withLock { _isSampling = true }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        let intervalSec = config.sampleIntervalSeconds
        timer.schedule(deadline: .now() + 1.0, repeating: .milliseconds(Int(intervalSec * 1000.0)))

        timer.setEventHandler { [weak self] in
            self?.performSample()
        }

        timer.resume()
        self.timer = timer
    }

    public func stop() {
        lock.withLock { _isSampling = false }
        timer?.cancel()
        timer = nil
    }

    public func performSample() {
        guard isSampling else { return }
        let currentConfig = self.config
        guard !currentConfig.isPaused else {
            delegate?.screenSampler(didSkipReason: "Sampling paused")
            return
        }

        // 1. Identify active application
        var activeAppName = "Finder"
        let windowTitle = ""
        DispatchQueue.main.sync {
            if let app = NSWorkspace.shared.frontmostApplication {
                activeAppName = app.localizedName ?? "Unknown"
            }
        }

        // 2. Check excluded apps
        if currentConfig.excludedApps.contains(activeAppName) {
            delegate?.screenSampler(didSkipReason: "App '\(activeAppName)' is excluded from recording")
            return
        }

        // 3. Capture main display image
        guard let screenshot = CGDisplayCreateImage(CGMainDisplayID()) else {
            delegate?.screenSampler(didSkipReason: "Failed to capture display")
            return
        }

        // 4. Perceptual diff check
        let hash = PerceptualHasher.computeDHash(image: screenshot)
        let lastHash = lock.withLock { _lastHash }

        if lastHash != 0 && !PerceptualHasher.isDifferent(hash1: hash, hash2: lastHash, threshold: currentConfig.diffThreshold) {
            delegate?.screenSampler(didSkipReason: "Screen content unchanged")
            return
        }

        lock.withLock { _lastHash = hash }

        // 5. Downscale and save thumbnail
        let recordId = UUID().uuidString
        let thumbnailFilename = "\(recordId).jpg"
        let thumbFileURL = thumbnailsDirectory.appendingPathComponent(thumbnailFilename)

        saveDownscaledThumbnail(image: screenshot, to: thumbFileURL, targetWidth: 960)

        // 6. Run OCR and save to SQLite
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let recognizedText = try await self.ocrEngine.recognizeText(from: screenshot)
                let record = RecallRecord(
                    id: recordId,
                    timestamp: Date(),
                    appName: activeAppName,
                    windowTitle: windowTitle,
                    extractedText: recognizedText,
                    thumbnailPath: thumbFileURL.path
                )

                self.database.insert(record: record)
                self.delegate?.screenSampler(didCaptureRecord: record)
            } catch {
                print("[QuickRecall] OCR error: \(error)")
            }
        }
    }

    private func saveDownscaledThumbnail(image: CGImage, to fileURL: URL, targetWidth: Int) {
        let origWidth = image.width
        let origHeight = image.height
        let scale = min(1.0, Double(targetWidth) / Double(origWidth))
        let newWidth = Int(Double(origWidth) * scale)
        let newHeight = Int(Double(origHeight) * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let downscaledImage = context.makeImage() else { return }
        let rep = NSBitmapImageRep(cgImage: downscaledImage)
        if let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.65]) {
            try? jpegData.write(to: fileURL)
        }
    }
}
