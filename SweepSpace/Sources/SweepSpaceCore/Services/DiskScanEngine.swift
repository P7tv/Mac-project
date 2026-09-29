import Foundation

public struct ScanProgress: Sendable {
    public let currentPath: String
    public let scannedItemsCount: Int
    public let discoveredBytes: Int64

    public init(currentPath: String, scannedItemsCount: Int, discoveredBytes: Int64) {
        self.currentPath = currentPath
        self.scannedItemsCount = scannedItemsCount
        self.discoveredBytes = discoveredBytes
    }
}

public actor DiskScanEngine {
    private var isCancelled: Bool = false

    public init() {}

    public func cancel() {
        isCancelled = true
    }

    private var shouldStop: Bool {
        isCancelled || Task.isCancelled
    }

    public func scan(
        rules: [ScanRule] = ScanRuleCatalog.defaultRules,
        largeFileDirectories: [URL] = ScanRuleCatalog.largeFileTargetDirectories,
        largeFileThreshold: Int64 = ScanRuleCatalog.largeFileSizeThreshold,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> [CleanableItem] {
        isCancelled = false
        var results: [CleanableItem] = []
        var totalBytes: Int64 = 0
        var scannedCount = 0

        // 1. Scan Category Rules (Caches, Developer Junk, Trash)
        for rule in rules {
            if shouldStop { break }

            guard FileManager.default.fileExists(atPath: rule.path.path) else {
                continue
            }

            if rule.isPerSubdirectory {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: rule.path,
                        includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    )

                    for itemURL in contents {
                        if shouldStop { break }

                        scannedCount += 1
                        let (size, count, modDate) = calculateDirectoryMetrics(for: itemURL)
                        if size > 0 {
                            totalBytes += size
                            results.append(CleanableItem(
                                name: itemURL.lastPathComponent,
                                path: itemURL,
                                sizeBytes: size,
                                category: rule.category,
                                isSafeToClean: rule.category.isSafeByDefault,
                                fileCount: count,
                                modificationDate: modDate
                            ))
                        }

                        onProgress?(ScanProgress(
                            currentPath: itemURL.path,
                            scannedItemsCount: scannedCount,
                            discoveredBytes: totalBytes
                        ))
                    }
                } catch {
                    continue
                }
            } else {
                scannedCount += 1
                let (size, count, modDate) = calculateDirectoryMetrics(for: rule.path)
                if size > 0 {
                    totalBytes += size
                    results.append(CleanableItem(
                        name: rule.name,
                        path: rule.path,
                        sizeBytes: size,
                        category: rule.category,
                        isSafeToClean: rule.category.isSafeByDefault,
                        fileCount: count,
                        modificationDate: modDate
                    ))
                }

                onProgress?(ScanProgress(
                    currentPath: rule.path.path,
                    scannedItemsCount: scannedCount,
                    discoveredBytes: totalBytes
                ))
            }
        }

        // 2. Scan Large & Old Files
        for dirURL in largeFileDirectories {
            if shouldStop { break }
            guard FileManager.default.fileExists(atPath: dirURL.path) else { continue }

            let largeItems = scanLargeFiles(in: dirURL, threshold: largeFileThreshold)
            for item in largeItems {
                if shouldStop { break }
                scannedCount += 1
                totalBytes += item.sizeBytes
                results.append(item)

                onProgress?(ScanProgress(
                    currentPath: item.path.path,
                    scannedItemsCount: scannedCount,
                    discoveredBytes: totalBytes
                ))
            }
        }

        // 3. Scan Project Dependencies (node_modules, .build, target, venv, Pods)
        let projectDeps = scanProjectDependencies()
        for item in projectDeps {
            if shouldStop { break }
            scannedCount += 1
            totalBytes += item.sizeBytes
            results.append(item)

            onProgress?(ScanProgress(
                currentPath: item.path.path,
                scannedItemsCount: scannedCount,
                discoveredBytes: totalBytes
            ))
        }

        return results
    }

    public func scanProjectDependencies(
        roots: [URL] = [FileManager.default.homeDirectoryForCurrentUser],
        maxDepth: Int = 4
    ) -> [CleanableItem] {
        let targetFolderNames: Set<String> = ["node_modules", ".build", "target", "venv", ".venv", "Pods"]
        let ignoredSubstrings: [String] = ["/Library/", "/.Trash/", "/.cursor/", "/.vscode/", "/.git/", "/Library", "/Applications"]

        var discovered: [CleanableItem] = []

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants]
            ) else {
                continue
            }

            for case let itemURL as URL in enumerator {
                if shouldStop { break }

                let pathString = itemURL.path
                if ignoredSubstrings.contains(where: { pathString.contains($0) }) {
                    enumerator.skipDescendants()
                    continue
                }

                // Check depth limit
                let relativeComponents = itemURL.pathComponents.dropFirst(root.pathComponents.count)
                if relativeComponents.count > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }

                let folderName = itemURL.lastPathComponent
                if targetFolderNames.contains(folderName) {
                    // Skip descending into children of this dependency folder
                    enumerator.skipDescendants()

                    let projectName = itemURL.deletingLastPathComponent().lastPathComponent
                    let (size, count, modDate) = calculateDirectoryMetrics(for: itemURL)

                    if size > 1024 * 1024 { // Minimum 1MB to avoid cluttering with empty dirs
                        let displayName = "\(projectName) (\(folderName))"
                        discovered.append(CleanableItem(
                            name: displayName,
                            path: itemURL,
                            sizeBytes: size,
                            category: .developerJunk,
                            isSafeToClean: true,
                            fileCount: count,
                            modificationDate: modDate
                        ))
                    }
                }
            }
        }

        return discovered
    }

    public nonisolated func calculateDirectoryMetrics(for url: URL) -> (size: Int64, count: Int, modificationDate: Date?) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return (0, 0, nil)
        }

        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        if !isDir.boolValue {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
            return (size, 1, modDate)
        }

        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else {
            return (0, 0, modDate)
        }

        var totalSize: Int64 = 0
        var totalCount = 0

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: keys)
                if values.isRegularFile == true, let fileSize = values.fileSize {
                    totalSize += Int64(fileSize)
                    totalCount += 1
                }
            } catch {
                continue
            }
        }

        return (totalSize, totalCount, modDate)
    }

    private func scanLargeFiles(in directory: URL, threshold: Int64) -> [CleanableItem] {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var largeItems: [CleanableItem] = []

        for case let fileURL as URL in enumerator {
            if shouldStop { break }

            do {
                let values = try fileURL.resourceValues(forKeys: keys)
                if values.isRegularFile == true, let size = values.fileSize, Int64(size) >= threshold {
                    let ext = fileURL.pathExtension
                    let type = LargeFileType.classify(extension: ext)

                    largeItems.append(CleanableItem(
                        name: fileURL.lastPathComponent,
                        path: fileURL,
                        sizeBytes: Int64(size),
                        category: .largeAndOldFiles,
                        isSafeToClean: false,
                        fileCount: 1,
                        modificationDate: values.contentModificationDate,
                        fileTypeCategory: type
                    ))
                }
            } catch {
                continue
            }
        }

        return largeItems
    }
}
