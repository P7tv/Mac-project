import XCTest
import CoreGraphics
import AppKit
@testable import GhostTranslateCore

final class VisionOCREngineTests: XCTestCase {
    func testRecognizeTextFromSyntheticImage() async throws {
        let engine = VisionOCREngine()
        let size = NSSize(width: 350, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        let text = "GHOST TRANSLATE"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: NSColor.black
        ]
        NSString(string: text).draw(at: NSPoint(x: 20, y: 30), withAttributes: attrs)
        image.unlockFocus()
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("Failed to convert NSImage to CGImage")
            return
        }
        
        let recognized = try await engine.recognizeText(from: cgImage)
        XCTAssertTrue(recognized.uppercased().contains("GHOST") || recognized.uppercased().contains("TRANSLATE"),
                      "Expected recognized text to contain GHOST or TRANSLATE, got: \(recognized)")
    }
}
