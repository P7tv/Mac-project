import Foundation

public struct RecallConfig: Sendable, Equatable {
    public var sampleIntervalSeconds: Double
    public var retentionDays: Int
    public var excludedApps: Set<String>
    public var isPaused: Bool
    public var diffThreshold: Int // 0..64 bit Hamming distance

    public init(
        sampleIntervalSeconds: Double = 5.0,
        retentionDays: Int = 7,
        excludedApps: Set<String> = ["1Password", "Bitwarden", "Keychain Access", "Passwords"],
        isPaused: Bool = false,
        diffThreshold: Int = 4
    ) {
        self.sampleIntervalSeconds = sampleIntervalSeconds
        self.retentionDays = retentionDays
        self.excludedApps = excludedApps
        self.isPaused = isPaused
        self.diffThreshold = diffThreshold
    }
}
