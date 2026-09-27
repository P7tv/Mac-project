import XCTest
@testable import RarPeekCore

final class RarPeekTests: XCTestCase {
    func testCoreVersion() {
        XCTAssertEqual(RarPeekCore.version, "1.0.0")
    }
}
