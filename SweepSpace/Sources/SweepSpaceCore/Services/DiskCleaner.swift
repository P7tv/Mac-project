import Foundation
import AppKit

public struct CleanResult: Sendable {
    public let cleanedBytes: Int64
    public let successCount: Int
    public let failedCount: Int

    public init(cleanedBytes: Int64, successCount: Int, failedCount: Int) {
        self.cleanedBytes = cleanedBytes
        self.successCount = successCount
        self.failedCount = failedCount
    }

    public var formattedCleaned: String {
        ByteCountFormatter.string(fromByteCount: cleanedBytes, countStyle: .file)
    }
}

public struct DiskCleaner: Sendable {
    public init() {}

    private static let dangerousSystemPaths: Set<String> = [
        "/",
        "/System",
        "/Library",
        "/Applications",
        "/Users",
        "/bin",
        "/sbin",
        "/usr",
        "/var",
        "/etc",
        "/private"
    ]

    public static func isSafeToDelete(url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let tmp = FileManager.default.temporaryDirectory.standardizedFileURL.path

        // Must NOT match dangerous system roots
        if dangerousSystemPaths.contains(path) {
            return false
        }

        // Must NOT be the user's home folder itself
        if path == home {
            return false
        }

        // Must be located within user home or temporary directories
        if path.hasPrefix(home) || path.hasPrefix(tmp) || path.hasPrefix("/tmp") {
            return true
        }

        return false
    }

    public static func clean(items: [CleanableItem], useTrash: Bool = true) async -> CleanResult {
        var cleanedBytes: Int64 = 0
        var successCount = 0
        var failedCount = 0

        for item in items {
            guard isSafeToDelete(url: item.path) else {
                failedCount += 1
                continue
            }

            guard FileManager.default.fileExists(atPath: item.path.path) else {
                continue
            }

            do {
                if useTrash && item.category == .largeAndOldFiles {
                    // Always move large user files to trash for safety
                    var resultingURL: NSURL?
                    try FileManager.default.trashItem(at: item.path, resultingItemURL: &resultingURL)
                } else if item.category == .trashAndLeftovers {
                    // Permanent delete from trash
                    try FileManager.default.removeItem(at: item.path)
                } else if useTrash {
                    // Safe trash
                    var resultingURL: NSURL?
                    try FileManager.default.trashItem(at: item.path, resultingItemURL: &resultingURL)
                } else {
                    // Permanent remove for caches / DerivedData
                    try FileManager.default.removeItem(at: item.path)
                }

                cleanedBytes += item.sizeBytes
                successCount += 1
            } catch {
                failedCount += 1
            }
        }

        return CleanResult(
            cleanedBytes: cleanedBytes,
            successCount: successCount,
            failedCount: failedCount
        )
    }
}
