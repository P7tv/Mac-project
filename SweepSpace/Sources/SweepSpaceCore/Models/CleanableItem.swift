import Foundation

public enum LargeFileType: String, CaseIterable, Identifiable, Sendable {
    case video = "Videos"
    case archive = "Archives"
    case diskImage = "Disk Images"
    case other = "Other"

    public var id: String { rawValue }

    public static func classify(extension ext: String) -> LargeFileType {
        let lower = ext.lowercased()
        switch lower {
        case "mov", "mp4", "mkv", "avi", "m4v", "wmv", "flv", "webm":
            return .video
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz":
            return .archive
        case "dmg", "iso", "img", "pkg":
            return .diskImage
        default:
            return .other
        }
    }
}

public struct CleanableItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let sizeBytes: Int64
    public let category: CleaningCategory
    public let isSafeToClean: Bool
    public let fileCount: Int
    public let modificationDate: Date?
    public let fileTypeCategory: LargeFileType?

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        sizeBytes: Int64,
        category: CleaningCategory,
        isSafeToClean: Bool = true,
        fileCount: Int = 1,
        modificationDate: Date? = nil,
        fileTypeCategory: LargeFileType? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.category = category
        self.isSafeToClean = isSafeToClean
        self.fileCount = fileCount
        self.modificationDate = modificationDate
        self.fileTypeCategory = fileTypeCategory
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    public var formattedDate: String {
        guard let date = modificationDate else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
