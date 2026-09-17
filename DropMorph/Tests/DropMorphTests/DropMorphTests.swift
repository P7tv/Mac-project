import XCTest
import DropMorphCore

final class DropMorphTests: XCTestCase {
    func testCoreInfo() {
        XCTAssertEqual(DropMorphCoreInfo.appName, "DropMorph")
    }
}
