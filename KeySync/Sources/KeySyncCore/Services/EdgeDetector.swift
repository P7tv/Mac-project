import Foundation
import CoreGraphics

public enum ScreenEdge: String, Codable, CaseIterable, Identifiable, Sendable {
    case right = "Right"
    case left = "Left"
    case top = "Top"
    case bottom = "Bottom"

    public var id: String { rawValue }
}

public struct EdgeDetector: Sendable {
    public let edge: ScreenEdge
    public let threshold: CGFloat

    public init(edge: ScreenEdge = .right, threshold: CGFloat = 3.0) {
        self.edge = edge
        self.threshold = threshold
    }

    public func hasHitEdge(point: CGPoint, in screenBounds: CGRect) -> Bool {
        switch edge {
        case .right:
            return point.x >= (screenBounds.maxX - threshold)
        case .left:
            return point.x <= (screenBounds.minX + threshold)
        case .top:
            return point.y <= (screenBounds.minY + threshold)
        case .bottom:
            return point.y >= (screenBounds.maxY - threshold)
        }
    }

    public func hasReturnedFromEdge(point: CGPoint, in screenBounds: CGRect) -> Bool {
        switch edge {
        case .right:
            return point.x < (screenBounds.maxX - threshold * 4)
        case .left:
            return point.x > (screenBounds.minX + threshold * 4)
        case .top:
            return point.y > (screenBounds.minY + threshold * 4)
        case .bottom:
            return point.y < (screenBounds.maxY - threshold * 4)
        }
    }
}
