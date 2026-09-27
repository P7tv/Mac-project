import Foundation

public enum ArchiveEngineError: LocalizedError {
    case binaryNotFound(String)
    case executionFailed(String)
    case invalidArchiveFormat
    case passwordRequired
    case invalidPassword
    case extractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "Engine tool '\(name)' not found."
        case .executionFailed(let reason):
            return "Archive command failed: \(reason)"
        case .invalidArchiveFormat:
            return "Unable to parse archive format or archive is corrupted."
        case .passwordRequired:
            return "Archive is encrypted and requires a password to open."
        case .invalidPassword:
            return "The provided password was incorrect."
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
        }
    }
}

public struct ArchiveEngine: Sendable {

    public static func findBinary(named: String) -> String? {
        // 1. App Bundle Resource bin
        if let bundleBin = Bundle.main.resourceURL?.appendingPathComponent("bin/\(named)").path,
           FileManager.default.isExecutableFile(atPath: bundleBin) {
            return bundleBin
        }

        // 2. Project local Resources bin (during development / test runs)
        let localCandidate = "/Users/panpan/Mac project/RarPeek/Resources/bin/\(named)"
        if FileManager.default.isExecutableFile(atPath: localCandidate) {
            return localCandidate
        }

        // 3. Homebrew ARM64
        let brewArmCandidate = "/opt/homebrew/bin/\(named)"
        if FileManager.default.isExecutableFile(atPath: brewArmCandidate) {
            return brewArmCandidate
        }

        // 4. Standard system paths
        let standardCandidates = [
            "/usr/local/bin/\(named)",
            "/usr/bin/\(named)"
        ]
        for path in standardCandidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    public static func inspectArchive(url: URL, password: String? = nil) async throws -> ArchiveInfo {
        guard let lsarPath = findBinary(named: "lsar") else {
            throw ArchiveEngineError.binaryNotFound("lsar")
        }

        var arguments = ["-j"]
        if let pwd = password, !pwd.isEmpty {
            arguments.append(contentsOf: ["-p", pwd])
        }
        arguments.append(url.path)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: lsarPath)
        proc.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            throw ArchiveEngineError.executionFailed(error.localizedDescription)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        if proc.terminationStatus != 0 {
            let errMsg = String(data: stderrData, encoding: .utf8) ?? "lsar exited with code \(proc.terminationStatus)"
            if errMsg.lowercased().contains("password") {
                throw ArchiveEngineError.passwordRequired
            }
            throw ArchiveEngineError.executionFailed(errMsg)
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: stdoutData) as? [String: Any] else {
            throw ArchiveEngineError.invalidArchiveFormat
        }

        let formatName = jsonObject["lsarFormatName"] as? String ?? "Archive"
        let contents = jsonObject["lsarContents"] as? [[String: Any]] ?? []

        var entries: [ArchiveEntry] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        for (index, dict) in contents.enumerated() {
            let path = dict["XADFileName"] as? String ?? "file_\(index)"
            let fileSize = (dict["XADFileSize"] as? NSNumber)?.int64Value ?? 0
            let compressedSize = (dict["XADCompressedSize"] as? NSNumber)?.int64Value ?? 0
            let isDir = (dict["XADIsDirectory"] as? NSNumber)?.intValue == 1
            let isEncrypted = (dict["XADIsEncrypted"] as? NSNumber)?.intValue == 1

            var date: Date? = nil
            if let dateString = dict["XADLastModificationDate"] as? String {
                date = dateFormatter.date(from: dateString)
            }

            entries.append(ArchiveEntry(
                index: index,
                path: path,
                uncompressedSize: fileSize,
                compressedSize: compressedSize,
                isDirectory: isDir,
                isEncrypted: isEncrypted,
                modificationDate: date
            ))
        }

        return ArchiveInfo(
            fileURL: url,
            formatName: formatName,
            entries: entries
        )
    }

    public static func extractArchive(
        url: URL,
        options: ExtractionOptions,
        onProgress: (@Sendable (Double, String) -> Void)? = nil
    ) async throws -> URL {
        guard let unarPath = findBinary(named: "unar") else {
            throw ArchiveEngineError.binaryNotFound("unar")
        }

        let targetDir = options.targetFolder
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        var arguments = ["-o", targetDir.path]

        // Container directory policy
        if !options.createContainingFolder {
            arguments.append("-D")
        }

        // Overwrite policy
        switch options.overwritePolicy {
        case .overwrite:
            arguments.append("-f")
        case .rename:
            arguments.append("-r")
        case .skip:
            arguments.append("-s")
        }

        // Password
        if let pwd = options.password, !pwd.isEmpty {
            arguments.append(contentsOf: ["-p", pwd])
        }

        // Selective extraction by indexes
        if let selected = options.selectedIndexes, !selected.isEmpty {
            arguments.append("-i")
            arguments.append(url.path)
            for idx in selected {
                arguments.append(String(idx))
            }
        } else {
            arguments.append(url.path)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: unarPath)
        proc.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            throw ArchiveEngineError.executionFailed(error.localizedDescription)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        if proc.terminationStatus != 0 {
            let stderrStr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stdoutStr = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fullOutput = !stderrStr.isEmpty ? stderrStr : stdoutStr
            let lower = fullOutput.lowercased()

            if lower.contains("password") || lower.contains("error on decrunching") || lower.contains("checksum error") {
                throw ArchiveEngineError.invalidPassword
            }
            throw ArchiveEngineError.extractionFailed(fullOutput.isEmpty ? "Extraction process failed with code \(proc.terminationStatus)." : fullOutput)
        }

        // Output directory is targetDir
        return targetDir
    }
}
