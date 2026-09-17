import XCTest
import CoreGraphics
@testable import KeySyncCore

final class EventTests: XCTestCase {
    func testInputEventSerialization() throws {
        let event = InputEvent.move(dx: 15.5, dy: -8.2)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

        XCTAssertEqual(decoded.type, .mouseMove)
        XCTAssertEqual(decoded.dx, 15.5)
        XCTAssertEqual(decoded.dy, -8.2)
    }

    func testEdgeDetectorRightEdge() {
        let detector = EdgeDetector(edge: .right, threshold: 3.0)
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // Inside screen
        XCTAssertFalse(detector.hasHitEdge(point: CGPoint(x: 1000, y: 500), in: screen))

        // Hit right boundary
        XCTAssertTrue(detector.hasHitEdge(point: CGPoint(x: 1918, y: 500), in: screen))
        XCTAssertTrue(detector.hasHitEdge(point: CGPoint(x: 1920, y: 500), in: screen))
    }

    func testEdgeDetectorLeftEdge() {
        let detector = EdgeDetector(edge: .left, threshold: 3.0)
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        XCTAssertFalse(detector.hasHitEdge(point: CGPoint(x: 50, y: 500), in: screen))
        XCTAssertTrue(detector.hasHitEdge(point: CGPoint(x: 2, y: 500), in: screen))
        XCTAssertTrue(detector.hasHitEdge(point: CGPoint(x: 0, y: 500), in: screen))
    }

    final class StateBox: @unchecked Sendable {
        var values: [Bool] = []
        let lock = NSLock()
        func append(_ val: Bool) {
            lock.lock()
            values.append(val)
            lock.unlock()
        }
        var last: Bool? {
            lock.lock()
            defer { lock.unlock() }
            return values.last
        }
    }

    func testEventInterceptorTransitions() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let interceptor = EventInterceptor(edge: .right, screenBounds: screen)

        let box = StateBox()
        interceptor.onControlStateChanged = { active in
            box.append(active)
        }

        XCTAssertFalse(interceptor.isControllingRemote)

        // Move to edge
        interceptor.handleMouseMoved(to: CGPoint(x: 1919, y: 500))
        XCTAssertTrue(interceptor.isControllingRemote)
        XCTAssertEqual(box.last, true)

        // Panic release
        interceptor.triggerPanicRelease()
        XCTAssertFalse(interceptor.isControllingRemote)
        XCTAssertEqual(box.last, false)
    }
}
