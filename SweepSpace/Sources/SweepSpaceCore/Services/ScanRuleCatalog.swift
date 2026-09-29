import Foundation

public struct ScanRule: Sendable {
    public let name: String
    public let path: URL
    public let category: CleaningCategory
    public let isPerSubdirectory: Bool // If true, list each child folder as an item (e.g. Caches/*)

    public init(name: String, path: URL, category: CleaningCategory, isPerSubdirectory: Bool = true) {
        self.name = name
        self.path = path
        self.category = category
        self.isPerSubdirectory = isPerSubdirectory
    }
}

public struct ScanRuleCatalog: Sendable {
    public static var defaultRules: [ScanRule] {
        let home = FileManager.default.homeDirectoryForCurrentUser

        return [
            // System & App Caches
            ScanRule(
                name: "User Caches",
                path: home.appendingPathComponent("Library/Caches", isDirectory: true),
                category: .systemAndAppCache,
                isPerSubdirectory: true
            ),
            ScanRule(
                name: "User Logs",
                path: home.appendingPathComponent("Library/Logs", isDirectory: true),
                category: .systemAndAppCache,
                isPerSubdirectory: true
            ),

            // Developer Junk
            ScanRule(
                name: "Xcode DerivedData",
                path: home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: true
            ),
            ScanRule(
                name: "Xcode Archives",
                path: home.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: true
            ),
            ScanRule(
                name: "Xcode iOS DeviceSupport",
                path: home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: true
            ),
            ScanRule(
                name: "Swift Package Manager Cache",
                path: home.appendingPathComponent("Library/Caches/org.swift.swiftpm", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "CocoaPods Cache",
                path: home.appendingPathComponent("Library/Caches/CocoaPods", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "Homebrew Cache",
                path: home.appendingPathComponent("Library/Caches/Homebrew", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "npm Cache",
                path: home.appendingPathComponent(".npm", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "Yarn Cache",
                path: home.appendingPathComponent("Library/Caches/Yarn", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "pnpm Store",
                path: home.appendingPathComponent(".pnpm-store", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "Gradle Cache",
                path: home.appendingPathComponent(".gradle/caches", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: true
            ),
            ScanRule(
                name: "Maven Repository Cache",
                path: home.appendingPathComponent(".m2/repository", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: true
            ),
            ScanRule(
                name: "CoreSimulator Devices & Caches",
                path: home.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: true
            ),
            ScanRule(
                name: "Go Module Cache",
                path: home.appendingPathComponent("go/pkg/mod", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "Go Build Cache",
                path: home.appendingPathComponent(".cache/go-build", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "Python pip Cache",
                path: home.appendingPathComponent(".cache/pip", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),
            ScanRule(
                name: "Rust Cargo Registry",
                path: home.appendingPathComponent(".cargo/registry", isDirectory: true),
                category: .developerJunk,
                isPerSubdirectory: false
            ),

            // Trash
            ScanRule(
                name: "Trash",
                path: home.appendingPathComponent(".Trash", isDirectory: true),
                category: .trashAndLeftovers,
                isPerSubdirectory: true
            )
        ]
    }

    public static var largeFileTargetDirectories: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Downloads", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true),
            home.appendingPathComponent("Movies", isDirectory: true),
            home.appendingPathComponent("Desktop", isDirectory: true)
        ]
    }

    public static let largeFileSizeThreshold: Int64 = 100 * 1024 * 1024 // 100 MB
}
