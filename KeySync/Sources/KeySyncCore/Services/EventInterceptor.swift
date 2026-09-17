import Foundation
import CoreGraphics
import AppKit

public final class EventInterceptor: @unchecked Sendable {
    public private(set) var isControllingRemote: Bool = false
    public var edgeDetector: EdgeDetector
    public var targetScreenBounds: CGRect
    private var lastLocalPoint: CGPoint = .zero
    private let lock = NSLock()

    public var onControlStateChanged: (@Sendable (Bool) -> Void)?
    public var onEventIntercepted: (@Sendable (InputEvent) -> Void)?

    public init(
        edge: ScreenEdge = .right,
        screenBounds: CGRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    ) {
        self.edgeDetector = EdgeDetector(edge: edge)
        self.targetScreenBounds = screenBounds
    }

    public func updateEdge(_ edge: ScreenEdge) {
        lock.lock()
        defer { lock.unlock() }
        self.edgeDetector = EdgeDetector(edge: edge)
    }

    public func handleMouseMoved(to currentPoint: CGPoint) {
        lock.lock()
        let controlling = isControllingRemote
        let lastPoint = lastLocalPoint
        lastLocalPoint = currentPoint
        lock.unlock()

        if !controlling {
            if edgeDetector.hasHitEdge(point: currentPoint, in: targetScreenBounds) {
                setControllingRemote(true)
            }
        } else {
            // Check return condition
            if edgeDetector.hasReturnedFromEdge(point: currentPoint, in: targetScreenBounds) {
                setControllingRemote(false)
                return
            }

            // Calculate delta
            let dx = currentPoint.x - lastPoint.x
            let dy = currentPoint.y - lastPoint.y
            if abs(dx) > 0.1 || abs(dy) > 0.1 {
                let event = InputEvent.move(dx: dx, dy: dy)
                onEventIntercepted?(event)
            }
        }
    }

    public func setControllingRemote(_ active: Bool) {
        lock.lock()
        guard isControllingRemote != active else {
            lock.unlock()
            return
        }
        isControllingRemote = active
        lock.unlock()

        onControlStateChanged?(active)
    }

    public func triggerPanicRelease() {
        setControllingRemote(false)
    }
}
