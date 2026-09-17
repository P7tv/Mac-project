import Foundation

public struct DeviceSession: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let deviceName: String
    public let deviceType: String
    public let ipAddress: String
    public let connectedAt: Date
    public var isAuthorized: Bool
    public let token: String

    public init(
        id: UUID = UUID(),
        deviceName: String,
        deviceType: String,
        ipAddress: String,
        connectedAt: Date = Date(),
        isAuthorized: Bool = false,
        token: String = UUID().uuidString
    ) {
        self.id = id
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.ipAddress = ipAddress
        self.connectedAt = connectedAt
        self.isAuthorized = isAuthorized
        self.token = token
    }
}
