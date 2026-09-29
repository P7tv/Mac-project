import Foundation
import SwiftUI

public enum CleaningCategory: String, CaseIterable, Identifiable, Sendable {
    case systemAndAppCache = "System & App Cache"
    case developerJunk = "Developer Space Hogs"
    case largeAndOldFiles = "Large & Old Files"
    case trashAndLeftovers = "Trash & Leftovers"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .systemAndAppCache:
            return "leaf.fill"
        case .developerJunk:
            return "hammer.fill"
        case .largeAndOldFiles:
            return "archivebox.fill"
        case .trashAndLeftovers:
            return "trash.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .systemAndAppCache:
            return .blue
        case .developerJunk:
            return .purple
        case .largeAndOldFiles:
            return .orange
        case .trashAndLeftovers:
            return .red
        }
    }

    public var subtitle: String {
        switch self {
        case .systemAndAppCache:
            return "App caches, crash logs, and temporary files that can be safely recreated."
        case .developerJunk:
            return "Xcode DerivedData, CocoaPods, SPM, Homebrew, and npm caches."
        case .largeAndOldFiles:
            return "Files larger than 100MB, videos, archives, and disk images."
        case .trashAndLeftovers:
            return "Items currently in the Trash and leftover orphaned data."
        }
    }

    public var isSafeByDefault: Bool {
        switch self {
        case .systemAndAppCache, .developerJunk:
            return true
        case .largeAndOldFiles:
            return false // User must review
        case .trashAndLeftovers:
            return true
        }
    }
}
