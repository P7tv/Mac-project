import Foundation
import AppKit

public final class ClipboardWatcher: @unchecked Sendable {
    private var lastChangeCount: Int
    private var lastItemHash: String = ""
    private var isObserving: Bool = false
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.airbridge.clipboardwatcher", qos: .userInteractive)
    private let lock = NSLock()

    public var onNewItem: (@Sendable (ClipboardItem) -> Void)?

    public init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    public func startObserving(intervalSeconds: Double = 0.5) {
        lock.lock()
        defer { lock.unlock() }

        guard !isObserving else { return }
        isObserving = true
        lastChangeCount = NSPasteboard.general.changeCount

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + intervalSeconds, repeating: intervalSeconds)
        timer.setEventHandler { [weak self] in
            self?.checkPasteboard()
        }
        timer.resume()
        self.timer = timer
    }

    public func stopObserving() {
        lock.lock()
        defer { lock.unlock() }

        isObserving = false
        timer?.cancel()
        timer = nil
    }

    public func checkPasteboard() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let currentCount = NSPasteboard.general.changeCount
            self.lock.lock()
            let previousCount = self.lastChangeCount
            self.lock.unlock()

            guard currentCount != previousCount else { return }

            if let item = self.readCurrentPasteboard() {
                self.lock.lock()
                let previousHash = self.lastItemHash
                if item.hash != previousHash {
                    self.lastItemHash = item.hash
                    self.lastChangeCount = currentCount
                    self.lock.unlock()

                    self.onNewItem?(item)
                } else {
                    self.lastChangeCount = currentCount
                    self.lock.unlock()
                }
            } else {
                self.lock.lock()
                self.lastChangeCount = currentCount
                self.lock.unlock()
            }
        }
    }

    public func readCurrentPasteboard() -> ClipboardItem? {
        let pasteboard = NSPasteboard.general

        // 1. Check for file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = urls.first {
            let path = firstURL.path
            let fileName = firstURL.lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
            return ClipboardItem(
                type: .file,
                content: path,
                previewText: "File: \(fileName) (\(size) bytes)",
                fileSize: size
            )
        }

        // 2. Check for image
        if let pngData = pasteboard.data(forType: .png) {
            let base64 = pngData.base64EncodedString()
            return ClipboardItem(
                type: .image,
                content: base64,
                previewText: "PNG Image (\(pngData.count) bytes)",
                fileSize: Int64(pngData.count)
            )
        } else if let tiffData = pasteboard.data(forType: .tiff),
                  let image = NSImage(data: tiffData),
                  let tiffRep = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffRep),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            let base64 = pngData.base64EncodedString()
            return ClipboardItem(
                type: .image,
                content: base64,
                previewText: "Image (\(pngData.count) bytes)",
                fileSize: Int64(pngData.count)
            )
        }

        // 3. Check for text / URL
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let isURL = (URL(string: trimmed)?.scheme != nil) && (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"))
            return ClipboardItem(
                type: isURL ? .url : .text,
                content: string,
                previewText: String(trimmed.prefix(80))
            )
        }

        return nil
    }

    public func copyToPasteboard(item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            switch item.type {
            case .text, .url:
                pasteboard.setString(item.content, forType: .string)
            case .image:
                if let data = Data(base64Encoded: item.content) {
                    pasteboard.setData(data, forType: .png)
                }
            case .file:
                let url = URL(fileURLWithPath: item.content)
                pasteboard.writeObjects([url as NSURL])
            }

            self.lock.lock()
            self.lastChangeCount = pasteboard.changeCount
            self.lastItemHash = item.hash
            self.lock.unlock()
        }
    }
}
