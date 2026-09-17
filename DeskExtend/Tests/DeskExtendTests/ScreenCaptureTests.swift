import XCTest
import CoreGraphics
@testable import DeskExtendCore

final class ScreenCaptureTests: XCTestCase {
    func testInvalidFrameRateDoesNotStartCapture() async {
        let engine = ScreenCaptureEngine()
        for fps in [0, -1, 121] {
            do {
                try await engine.startCapture(displayID: 0, fps: fps) { _, _ in
                    XCTFail("Invalid configuration must not emit frames")
                }
                XCTFail("Invalid frame rate must fail")
            } catch ScreenCaptureError.invalidFrameRate {
                // Validation must happen before requesting screen access.
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testMissingPermissionFailsInsteadOfGeneratingPlaceholder() async throws {
        guard !ScreenCaptureEngine.hasScreenRecordingPermission() else {
            throw XCTSkip("Screen recording is already authorized for the test process")
        }
        let engine = ScreenCaptureEngine()
        do {
            try await engine.startCapture(displayID: 0) { _, _ in
                XCTFail("Denied capture must not emit placeholder frames")
            }
            XCTFail("Missing permission must fail")
        } catch ScreenCaptureError.permissionRequired {
            // No synthetic stream may be reported as a successful capture.
        }
    }
}
