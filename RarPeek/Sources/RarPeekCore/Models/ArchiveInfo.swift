import Foundation

public struct ArchiveInfo: Identifiable, Sendable {
    public let id: UUID
    public let fileURL: URL
    public let formatName: String
    public let entries: [ArchiveEntry]

    public init(
        id: UUID = UUID(),
        fileURL: URL,
        formatName: String,
        entries: [ArchiveEntry]
    ) {
        self.id = id
        self.fileURL = fileURL
        self.formatName = formatName
        self.entries = entries
    }

    public var archiveName: String {
        fileURL.lastPathComponent
    }

    public var archiveSize: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
    }

    public var formattedArchiveSize: String {
        ByteCountFormatter.string(fromByteCount: archiveSize, countStyle: .file)
    }

    public var totalEntries: Int {
        entries.count
    }

    public var fileCount: Int {
        entries.filter { !$0.isDirectory }.count
    }

    public var folderCount: Int {
        entries.filter { $0.isDirectory }.count
    }

    public var totalUncompressedBytes: Int64 {
        entries.reduce(0) { $0 + $1.uncompressedSize }
    }

    public var formattedTotalUncompressedSize: String {
        ByteCountFormatter.string(fromByteCount: totalUncompressedBytes, countStyle: .file)
    }

    public var isEncrypted: Bool {
        entries.contains { $0.isEncrypted }
    }
}
