import XCTest
@testable import GhostTranslateCore

final class TranslationPreviewGateTests: XCTestCase {
    func testNewerTicketRejectsAnOlderPreviewResponse() {
        var gate = LatestTranslationGate()
        let older = gate.issue()
        let newer = gate.issue()

        XCTAssertFalse(gate.accepts(older))
        XCTAssertTrue(gate.accepts(newer))
    }

    func testInvalidatingGateRejectsPendingResponse() {
        var gate = LatestTranslationGate()
        let pending = gate.issue()

        gate.invalidate()

        XCTAssertFalse(gate.accepts(pending))
    }
}
