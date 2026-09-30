import Foundation

public struct LatestTranslationGate {
    private var latestTicket: UInt64 = 0

    public init() {}

    @discardableResult
    public mutating func issue() -> UInt64 {
        latestTicket &+= 1
        return latestTicket
    }

    public func accepts(_ ticket: UInt64) -> Bool {
        ticket == latestTicket
    }

    public mutating func invalidate() {
        latestTicket &+= 1
    }
}
