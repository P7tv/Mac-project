import Foundation
import AppKit

public struct ArchiveEntry: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let index: Int
    public let path: String
    public let uncompressedSize: Int64
    public let compressedSize: Int64
    public let isDirectory: Bool
    public let isEncrypted: Bool
    public let modificationDate: Date?

    public init(
        id: UUID = UUID(),
        index: Int,
        path: String,
        uncompressedSize: Int64,
        compressedSize: Int64 = 0,
        isDirectory: Bool = false,
        isEncrypted: Bool = false,
        modificationDate: Date? = nil
    ) {
        self.id = id
        self.index = index
        self.path = path
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.isDirectory = isDirectory
        self.isEncrypted = isEncrypted
        self.modificationDate = modificationDate
    }

    public var name: String {
        path.components(separatedBy: "/").last ?? path
    }

    public var directoryPath: String {
        let components = path.components(separatedBy: "/")
        if components.count > 1 {
            return components.dropLast().joined(separator: "/")
        }
        return ""
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: uncompressedSize, countStyle: .file)
    }

    public var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    public var compressionRatio: Int {
        guard uncompressedSize > 0, compressedSize > 0 else { return 0 }
        let ratio = (Double(compressedSize) / Double(uncompressedSize)) * 100.0
        return min(100, max(0, Int(round(ratio))))
    }

    public var fileExtension: String {
        URL(fileURLWithPath: path).pathExtension.lowercased()
    }

    public var iconSystemName: String {
        if isDirectory {
            return "folder.fill"
        }
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "svg", "bmp":
            return "photo"
        case "mp4", "mov", "mkv", "avi", "webm":
            return "film"
        case "mp3", "m4a", "wav", "flac", "aac":
            return "waveform"
        case "pdf":
            return "doc.text.fill"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        case "swift", "py", "js", "ts", "html", "css", "c", "cpp", "json", "sh":
            return "chevron.left.forwardslash.chevron.right"
        case "txt", "md", "rtf":
            return "doc.plaintext"
        default:
            return "doc"
        }
    }
}
