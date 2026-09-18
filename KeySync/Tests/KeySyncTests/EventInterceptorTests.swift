import XCTest
import CoreGraphics
@testable import KeySyncCore

final class EventInterceptorTests: XCTestCase {
    func testInputEventFactoryMethods() {
        let clickEvent = InputEvent.click(button: 0, isDown: true)
        XCTAssertEqual(clickEvent.type, .mouseDown)
        XCTAssertEqual(clickEvent.button, 0)

        let upEvent = InputEvent.click(button: 1, isDown: false)
        XCTAssertEqual(upEvent.type, .mouseUp)
        XCTAssertEqual(upEvent.button, 1)

        let scrollEvent = InputEvent.scroll(dx: 0, dy: -5.0)
        XCTAssertEqual(scrollEvent.type, .mouseScroll)
        XCTAssertEqual(scrollEvent.dy, -5.0)

        let keyEvent = InputEvent.key(keyCode: 49, modifiers: 0, isDown: true)
        XCTAssertEqual(keyEvent.type, .keyDown)
        XCTAssertEqual(keyEvent.keyCode, 49)
    }

    func testEdgeDetectorAllEdges() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let topDetector = EdgeDetector(edge: .top, threshold: 3.0)
        XCTAssertTrue(topDetector.hasHitEdge(point: CGPoint(x: 500, y: 1), in: screen))
        XCTAssertFalse(topDetector.hasHitEdge(point: CGPoint(x: 500, y: 50), in: screen))

        let bottomDetector = EdgeDetector(edge: .bottom, threshold: 3.0)
        XCTAssertTrue(bottomDetector.hasHitEdge(point: CGPoint(x: 500, y: 1079), in: screen))
        XCTAssertFalse(bottomDetector.hasHitEdge(point: CGPoint(x: 500, y: 500), in: screen))
    }

    func testVirtualCursorMovementAndBoundaryReturn() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let interceptor = EventInterceptor(edge: .right, screenBounds: screen)

        // 1. Hit right edge -> transitions to controlling remote
        interceptor.handleMouseMoved(to: CGPoint(x: 1919, y: 500))
        XCTAssertTrue(interceptor.isControllingRemote)

        // 2. Move deep into remote screen (dx = +300)
        interceptor.handleMouseMoved(to: CGPoint(x: 1919 + 300, y: 500))
        XCTAssertTrue(interceptor.isControllingRemote)

        // 3. Move back to the left on remote (dx = -200) -> Still controlling remote! (Not returned prematurely)
        interceptor.handleMouseMoved(to: CGPoint(x: 1919 + 100, y: 500))
        XCTAssertTrue(interceptor.isControllingRemote)

        // 4. Push past the left boundary (dx = -150) -> User actively pushed past 0 -> Returns to Mac
        interceptor.handleMouseMoved(to: CGPoint(x: 1919 - 50, y: 500))
        XCTAssertFalse(interceptor.isControllingRemote)
    }
}
