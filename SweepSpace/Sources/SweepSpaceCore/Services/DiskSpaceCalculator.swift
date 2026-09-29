import Foundation

public struct DiskSpaceCalculator: Sendable {
    public init() {}

    public static func currentDiskSpace(for url: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskSpaceInfo {
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])

            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)

            return DiskSpaceInfo(
                totalCapacityBytes: total,
                freeCapacityBytes: free,
                recoverableBytes: 0
            )
        } catch {
            return DiskSpaceInfo(totalCapacityBytes: 0, freeCapacityBytes: 0, recoverableBytes: 0)
        }
    }
}
