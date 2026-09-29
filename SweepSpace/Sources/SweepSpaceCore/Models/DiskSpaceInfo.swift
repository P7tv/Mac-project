import Foundation

public struct DiskSpaceInfo: Equatable, Sendable {
    public let totalCapacityBytes: Int64
    public let freeCapacityBytes: Int64
    public let usedCapacityBytes: Int64
    public let recoverableBytes: Int64

    public init(
        totalCapacityBytes: Int64,
        freeCapacityBytes: Int64,
        recoverableBytes: Int64 = 0
    ) {
        self.totalCapacityBytes = max(totalCapacityBytes, 0)
        self.freeCapacityBytes = max(freeCapacityBytes, 0)
        self.usedCapacityBytes = max(totalCapacityBytes - freeCapacityBytes, 0)
        self.recoverableBytes = max(recoverableBytes, 0)
    }

    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalCapacityBytes, countStyle: .file)
    }

    public var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeCapacityBytes, countStyle: .file)
    }

    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedCapacityBytes, countStyle: .file)
    }

    public var formattedRecoverable: String {
        ByteCountFormatter.string(fromByteCount: recoverableBytes, countStyle: .file)
    }

    public var usedPercentage: Double {
        guard totalCapacityBytes > 0 else { return 0.0 }
        return min(max(Double(usedCapacityBytes) / Double(totalCapacityBytes), 0.0), 1.0)
    }

    public var recoverablePercentage: Double {
        guard totalCapacityBytes > 0 else { return 0.0 }
        return min(max(Double(recoverableBytes) / Double(totalCapacityBytes), 0.0), 1.0)
    }
}
