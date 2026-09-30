import XCTest
import AppKit
@testable import GhostTranslateCore

@MainActor
final class GhostPanelTests: XCTestCase {
    func testGhostPanelIsInvisibleToScreenSharing() {
        let panel = GhostPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200))
        XCTAssertEqual(panel.sharingType, .none, "GhostPanel sharingType must be .none to stay invisible to Zoom/Meet")
        XCTAssertEqual(panel.level, .floating, "GhostPanel must float above normal windows")
    }

    func testClickThroughToggle() {
        let panel = GhostPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200))
        panel.setClickThrough(true)
        XCTAssertTrue(panel.ignoresMouseEvents)
        panel.setClickThrough(false)
        XCTAssertFalse(panel.ignoresMouseEvents)
    }

    func testOpacityControl() {
        let panel = GhostPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200))
        panel.setHUDAlpha(0.75)
        XCTAssertEqual(panel.alphaValue, 0.75, accuracy: 0.001)
    }
}
