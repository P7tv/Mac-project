import XCTest
import CoreGraphics
@testable import DeskExtendCore

final class VirtualDisplayTests: XCTestCase {
    func testVirtualDisplayLifecycle() throws {
        let manager = VirtualDisplayManager()
        XCTAssertFalse(manager.isRunning)
        XCTAssertNil(manager.activeDisplayID)

        let config = DisplayConfig(resolution: .fullHD, refreshRate: 60.0)
        let displayID = manager.start(config: config)

        XCTAssertNotNil(displayID)
        XCTAssertTrue(manager.isRunning)
        XCTAssertEqual(manager.activeDisplayID, displayID)

        // Verify that macOS acknowledges this display in the online display list
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount)
        XCTAssertTrue(onlineDisplays.prefix(Int(displayCount)).contains(displayID!))

        // Stop display
        manager.stop()
        XCTAssertFalse(manager.isRunning)
        XCTAssertNil(manager.activeDisplayID)
    }
}
