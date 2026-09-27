import Foundation

public enum PasswordTestResult: Equatable, Sendable {
    case valid
    case invalid
    case corrupted(String)
    case binaryNotFound
}

public enum RecoveryStrategy: Sendable {
    case commonPasswords
    case numericPin(length: Int)
    case customList([String])
}

public struct RecoveryProgress: Sendable {
    public let testedCount: Int
    public let totalCount: Int
    public let currentCandidate: String
    public let speed: Double // candidates per second

    public init(testedCount: Int, totalCount: Int, currentCandidate: String, speed: Double) {
        self.testedCount = testedCount
        self.totalCount = totalCount
        self.currentCandidate = currentCandidate
        self.speed = speed
    }
}

public actor PasswordRecoveryEngine {
    private var isCancelled: Bool = false

    public init() {}

    public func cancel() {
        isCancelled = true
    }

    private var shouldStop: Bool {
        isCancelled || Task.isCancelled
    }

    public static let commonPasswords: [String] = [
        // Numbers
        "1234", "12345", "123456", "1234567", "12345678", "123456789", "0000", "1111", "9999", "8888",
        // Thai & Release favorites
        "clip", "cliphd", "hd", "vip", "vipclip", "chula", "cu", "thai", "thailand", "free",
        "set", "d1", "video", "rar", "winrar", "password", "pass", "admin", "secret", "love",
        // Common web & defaults
        "112233", "1212", "123123", "654321", "12344321", "012345", "000000", "111111",
        "qwerty", "abc123", "password123", "pass123", "1234pass", "master", "root", "user",
        "download", "forum", "share", "movie", "media", "backup", "archive", "unlock", "open",
        "2016", "2017", "2018", "2019", "2020", "2021", "2022", "2023", "2024", "2025", "2026",
        // Additional web/forum staples
        "www", "com", "net", "org", "co.th", "vk", "telegram", "mega", "gdrive",
        "full", "leak", "original", "raw", "master", "super", "private", "hidden"
    ]

    public func verifyPassword(password: String, archiveURL: URL) async -> PasswordTestResult {
        guard let unarPath = findBinary(named: "unar") else {
            return .binaryNotFound
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: unarPath)
        proc.arguments = ["-f", "-p", password, "-t", archiveURL.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return .invalid
        }

        if proc.terminationStatus == 0 {
            return .valid
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let combined = (String(data: stderrData, encoding: .utf8) ?? "") + " " + (String(data: stdoutData, encoding: .utf8) ?? "")
        let lower = combined.lowercased()

        if lower.contains("attempted to read more data") || lower.contains("unexpected end of archive") {
            return .corrupted("Archive data is incomplete or truncated.")
        }

        return .invalid
    }

    public func runRecovery(
        archiveURL: URL,
        strategy: RecoveryStrategy,
        onProgress: (@Sendable (RecoveryProgress) -> Void)? = nil
    ) async -> String? {
        isCancelled = false

        let candidates = generateCandidates(for: strategy)
        let total = candidates.count
        let startTime = Date()

        for (index, candidate) in candidates.enumerated() {
            if shouldStop {
                return nil
            }

            let result = await verifyPassword(password: candidate, archiveURL: archiveURL)
            let tested = index + 1
            let elapsed = max(Date().timeIntervalSince(startTime), 0.001)
            let speed = Double(tested) / elapsed

            onProgress?(RecoveryProgress(
                testedCount: tested,
                totalCount: total,
                currentCandidate: candidate,
                speed: speed
            ))

            if result == .valid {
                return candidate
            }
        }

        return nil
    }

    private func generateCandidates(for strategy: RecoveryStrategy) -> [String] {
        switch strategy {
        case .commonPasswords:
            return Self.commonPasswords
        case .numericPin(let length):
            let maxCount = Int(pow(10.0, Double(length)))
            return (0..<maxCount).map { String(format: "%0*d", length, $0) }
        case .customList(let list):
            return list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
    }

    private func findBinary(named name: String) -> String? {
        let bundlePaths = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin/\(name)").path,
            Bundle.main.resourceURL?.appendingPathComponent("bin/\(name)").path
        ].compactMap { $0 }

        for path in bundlePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let standardPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]

        for path in standardPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}
