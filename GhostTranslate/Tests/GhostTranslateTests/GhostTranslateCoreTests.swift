import XCTest
@testable import GhostTranslateCore

final class GhostTranslateCoreTests: XCTestCase {
    func testVersionString() {
        XCTAssertEqual(GhostTranslateCore.version, "1.0.0")
    }
}
