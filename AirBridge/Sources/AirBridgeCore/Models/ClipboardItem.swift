import Foundation
import CryptoKit

public enum ClipboardType: String, Codable, Sendable {
    case text
    case url
    case image
    case file
}

public struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let type: ClipboardType
    public let content: String // Text string, URL string, or Base64 encoded image
    public let hash: String
    public let timestamp: Date
    public let sourceDevice: String
    public let previewText: String
    public let fileSize: Int64?

    public init(
        id: UUID = UUID(),
        type: ClipboardType,
        content: String,
        timestamp: Date = Date(),
        sourceDevice: String = "Mac",
        previewText: String? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.timestamp = timestamp
        self.sourceDevice = sourceDevice
        self.fileSize = fileSize

        // Calculate SHA-256 hash for deduplication
        let digest = SHA256.hash(data: Data(content.utf8))
        self.hash = digest.compactMap { String(format: "%02x", $0) }.joined()

        if let preview = previewText {
            self.previewText = preview
        } else {
            switch type {
            case .text, .url:
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                self.previewText = String(trimmed.prefix(80))
            case .image:
                self.previewText = "Image (\(fileSize ?? 0) bytes)"
            case .file:
                self.previewText = "File: \(content)"
            }
        }
    }
}
