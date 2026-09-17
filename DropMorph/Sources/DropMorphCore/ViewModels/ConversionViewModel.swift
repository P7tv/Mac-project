import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class ConversionViewModel: ObservableObject {
    @Published public var queue: [ConversionItem] = []
    @Published public var settings: ConversionSettings = ConversionSettings()
    @Published public var isProcessing: Bool = false
    @Published public var isPinnedOnTop: Bool = false
    @Published public var alertMessage: String? = nil
    @Published public var isHoveringDropZone: Bool = false

    public init() {}

    public var totalOriginalBytes: Int64 {
        queue.reduce(0) { $0 + $1.originalFileSize }
    }

    public var totalConvertedBytes: Int64 {
        queue.reduce(0) { $0 + ($1.convertedFileSize ?? 0) }
    }

    public var totalSavedBytes: Int64 {
        let original = queue.filter { $0.convertedFileSize != nil }.reduce(0) { $0 + $1.originalFileSize }
        let converted = totalConvertedBytes
        return max(0, original - converted)
    }

    public var overallSavingsPercentage: Int? {
        let original = queue.filter { $0.convertedFileSize != nil }.reduce(0) { $0 + $1.originalFileSize }
        guard original > 0, totalConvertedBytes > 0 else { return nil }
        let diff = Double(original - totalConvertedBytes) / Double(original) * 100.0
        return Int(round(diff))
    }

    public func addFiles(urls: [URL]) {
        var validURLs: [URL] = []
        let supportedExtensions: Set<String> = [
            // Standard Images
            "png", "jpg", "jpeg", "webp", "heic", "tiff", "tif", "gif", "bmp", "avif",
            // Vector
            "svg",
            // Camera RAW
            "cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "pef",
            // Video
            "mp4", "mov", "m4v",
            // Documents
            "pdf"
        ]

        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    if let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        for case let fileURL as URL in enumerator {
                            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                                validURLs.append(fileURL)
                            }
                        }
                    }
                } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    validURLs.append(url)
                }
            }
        }

        guard !validURLs.isEmpty else {
            alertMessage = "No supported media or document files found."
            return
        }

        let newItems = validURLs.map { ConversionItem(inputURL: $0) }
        queue.append(contentsOf: newItems)

        Task {
            await processQueue()
        }
    }

    public func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        let pendingItems = queue.filter {
            if case .pending = $0.status { return true }
            return false
        }

        guard !pendingItems.isEmpty else { return }

        // If target format is PDF and input contains images, merge to PDF
        let imageItems = pendingItems.filter {
            let ext = $0.inputURL.pathExtension.lowercased()
            return ext != "mp4" && ext != "mov" && ext != "m4v" && ext != "pdf"
        }

        if settings.targetFormat == .pdf && imageItems.count == pendingItems.count && imageItems.count > 1 {
            await processPDFMerge(items: imageItems)
            return
        }

        let currentSettings = self.settings

        for item in pendingItems {
            item.status = .processing(0.5)
            let ext = item.inputURL.pathExtension.lowercased()

            do {
                let outputURL: URL

                if ext == "mp4" || ext == "mov" || ext == "m4v" {
                    // Video conversion
                    if currentSettings.targetFormat == .gif {
                        let target = ImageConverter.destinationURL(for: item.inputURL, format: .gif, customFolder: currentSettings.customOutputFolder)
                        outputURL = try await VideoConverter.convertToGIF(videoURL: item.inputURL, outputURL: target)
                    } else if currentSettings.targetFormat == .m4a {
                        let target = ImageConverter.destinationURL(for: item.inputURL, format: .m4a, customFolder: currentSettings.customOutputFolder)
                        outputURL = try await VideoConverter.extractAudio(videoURL: item.inputURL, outputURL: target)
                    } else {
                        // Extract poster frame and convert to target image format
                        guard let poster = await VideoConverter.extractPosterFrame(videoURL: item.inputURL) else {
                            throw VideoConverterError.noFramesExtracted
                        }
                        let target = ImageConverter.destinationURL(for: item.inputURL, format: currentSettings.targetFormat, customFolder: currentSettings.customOutputFolder)
                        // Save poster
                        let tempPNG = FileManager.default.temporaryDirectory.appendingPathComponent("poster_\(UUID().uuidString).png")
                        let dest = CGImageDestinationCreateWithURL(tempPNG as CFURL, "public.png" as CFString, 1, nil)!
                        CGImageDestinationAddImage(dest, poster, nil)
                        CGImageDestinationFinalize(dest)
                        outputURL = try ImageConverter.convert(inputURL: tempPNG, settings: currentSettings, targetOutputURL: target)
                        try? FileManager.default.removeItem(at: tempPNG)
                    }
                } else if ext == "pdf" {
                    // PDF extraction to images
                    if currentSettings.targetFormat != .pdf {
                        let extracted = try PDFExtractor.extractPages(
                            pdfURL: item.inputURL,
                            format: currentSettings.targetFormat,
                            outputDirectory: currentSettings.customOutputFolder
                        )
                        outputURL = extracted.first ?? item.inputURL
                    } else {
                        outputURL = item.inputURL
                    }
                } else {
                    // Images, Camera RAW (CR2/NEF/ARW/DNG), SVG
                    outputURL = try ImageConverter.convert(inputURL: item.inputURL, settings: currentSettings)
                }

                let convertedSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
                item.status = .completed(outputURL: outputURL)
                item.convertedFileSize = convertedSize
                item.outputURL = outputURL
            } catch {
                item.status = .failed(error.localizedDescription)
            }
        }
    }

    public func processPDFMerge(items: [ConversionItem]) async {
        let imageURLs = items.map { $0.inputURL }
        for item in items {
            item.status = .processing(0.5)
        }

        do {
            let firstInput = items.first!.inputURL
            let baseDir: URL
            if let custom = settings.customOutputFolder {
                baseDir = custom
            } else {
                let parent = firstInput.deletingLastPathComponent()
                baseDir = FileManager.default.isWritableFile(atPath: parent.path) ? parent : FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            }

            var outputPDF = baseDir.appendingPathComponent("Merged_Document.pdf")
            var counter = 1
            while FileManager.default.fileExists(atPath: outputPDF.path) {
                outputPDF = baseDir.appendingPathComponent("Merged_Document_\(counter).pdf")
                counter += 1
            }

            let resultURL = try PDFMerger.mergeToPDF(imageURLs: imageURLs, outputURL: outputPDF)
            let pdfSize = (try? FileManager.default.attributesOfItem(atPath: resultURL.path)[.size] as? Int64) ?? 0

            for item in items {
                item.status = .completed(outputURL: resultURL)
                item.outputURL = resultURL
                item.convertedFileSize = pdfSize / Int64(max(1, items.count))
            }
        } catch {
            for item in items {
                item.status = .failed(error.localizedDescription)
            }
            alertMessage = "PDF Merge Failed: \(error.localizedDescription)"
        }
    }

    public func clearQueue() {
        queue.removeAll()
    }

    public func removeItem(id: UUID) {
        queue.removeAll { $0.id == id }
    }

    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func toggleAlwaysOnTop() {
        isPinnedOnTop.toggle()
        applyWindowLevel()
    }

    public func applyWindowLevel() {
        for window in NSApp.windows {
            if window.canBecomeKey {
                window.level = isPinnedOnTop ? .floating : .normal
            }
        }
    }
}
