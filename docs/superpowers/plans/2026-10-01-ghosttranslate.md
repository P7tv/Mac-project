# GhostTranslate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and package GhostTranslate, a native macOS stealth subtitle translation and interview assistant powered by SCB 10X Typhoon AI, strictly invisible to Zoom, Meet, Teams, and screen capture software.

**Architecture:** A standalone native Swift/SwiftUI application composed of `GhostTranslateCore` and an executable target. It uses `NSPanel` with `sharingType = .none` for screen-share invisibility, Apple Vision for on-device screen OCR, `SFSpeechRecognizer` for real-time audio transcription, and an async HTTP client for Typhoon AI (`typhoon-v2.5-30b-a3b-instruct`).

**Tech Stack:** Swift 5.9+, macOS 13.0+, SwiftUI, AppKit, AVFoundation, Speech, Vision, Typhoon AI REST API.

## Global Constraints
- Target platform: macOS 13.0+
- Primary AI Engine: SCB 10X Typhoon (`typhoon-v2.5-30b-a3b-instruct`)
- Stealth Window requirement: Must set `NSWindow.sharingType = .none`
- No third-party binary dependencies (Pure Swift & Apple frameworks)
- Application bundle installed to: `/Applications/GhostTranslate.app`

---

### Task 1: Project Scaffolding & Package.swift

**Files:**
- Create: `GhostTranslate/Package.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/GhostTranslateCore.swift`
- Create: `GhostTranslate/Tests/GhostTranslateTests/GhostTranslateCoreTests.swift`

**Interfaces:**
- Produces: `GhostTranslateCore` module and `GhostTranslateTests` target.

- [ ] **Step 1: Write the failing test**
Create `GhostTranslate/Tests/GhostTranslateTests/GhostTranslateCoreTests.swift`:
```swift
import XCTest
@testable import GhostTranslateCore

final class GhostTranslateCoreTests: XCTestCase {
    func testVersionString() {
        XCTAssertEqual(GhostTranslateCore.version, "1.0.0")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**
Run: `swift test --package-path GhostTranslate`
Expected: FAIL (missing module / Package.swift).

- [ ] **Step 3: Create Package.swift and core placeholder**
Create `GhostTranslate/Package.swift`:
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhostTranslate",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GhostTranslateCore", targets: ["GhostTranslateCore"]),
        .executable(name: "GhostTranslate", targets: ["GhostTranslateAppTarget"])
    ],
    targets: [
        .target(
            name: "GhostTranslateCore",
            dependencies: [],
            path: "Sources/GhostTranslateCore"
        ),
        .executableTarget(
            name: "GhostTranslateAppTarget",
            dependencies: ["GhostTranslateCore"],
            path: "Sources/GhostTranslateAppTarget"
        ),
        .testTarget(
            name: "GhostTranslateTests",
            dependencies: ["GhostTranslateCore"],
            path: "Tests/GhostTranslateTests"
        )
    ]
)
```
Create `GhostTranslate/Sources/GhostTranslateCore/GhostTranslateCore.swift`:
```swift
import Foundation

public enum GhostTranslateCore {
    public static let version = "1.0.0"
}
```

- [ ] **Step 4: Run test to verify it passes**
Run: `swift test --package-path GhostTranslate`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add GhostTranslate
git commit -m "feat(scaffold): initialize GhostTranslate package structure"
```

---

### Task 2: Stealth Window System (GhostPanel & GhostWindowManager)

**Files:**
- Create: `GhostTranslate/Sources/GhostTranslateCore/Window/GhostPanel.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/Window/GhostWindowManager.swift`
- Test: `GhostTranslate/Tests/GhostTranslateTests/GhostPanelTests.swift`

**Interfaces:**
- Produces:
  - `class GhostPanel: NSPanel` with `sharingType = .none`, `ignoresMouseEvents` support, floating level.
  - `class GhostWindowManager: ObservableObject` managing panel positioning, opacity, mode switching, and visibility.

- [ ] **Step 1: Write the failing test**
Create `GhostTranslate/Tests/GhostTranslateTests/GhostPanelTests.swift`:
```swift
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
}
```

- [ ] **Step 2: Run test to verify it fails**
Run: `swift test --package-path GhostTranslate --filter GhostPanelTests`
Expected: FAIL (GhostPanel not defined).

- [ ] **Step 3: Implement GhostPanel and GhostWindowManager**
Implement `GhostPanel.swift` and `GhostWindowManager.swift`. Ensure:
- `sharingType = .none`
- `styleMask = [.borderless, .nonactivatingPanel]`
- `isOpaque = false`
- `backgroundColor = .clear`
- `hasShadow = false`
- Method `setClickThrough(_ enabled: Bool)`
- Method `setHUDOpacity(_ opacity: Double)`

- [ ] **Step 4: Run test to verify it passes**
Run: `swift test --package-path GhostTranslate --filter GhostPanelTests`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add GhostTranslate/Sources/GhostTranslateCore/Window GhostTranslate/Tests/GhostTranslateTests/GhostPanelTests.swift
git commit -m "feat(window): implement GhostPanel with sharingType .none for stealth screen share"
```

---

### Task 3: Typhoon AI Service (TyphoonService)

**Files:**
- Create: `GhostTranslate/Sources/GhostTranslateCore/AI/TyphoonModels.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/AI/TyphoonService.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/AI/Prompts.swift`
- Test: `GhostTranslate/Tests/GhostTranslateTests/TyphoonServiceTests.swift`

**Interfaces:**
- Produces:
  - `struct TyphoonMessage`, `struct TyphoonRequest`, `struct TyphoonResponse`
  - `class TyphoonService`:
    - `func translate(text: String, targetLanguage: String) async throws -> String`
    - `func generateInterviewPrompts(question: String) async throws -> InterviewAnswer`
    - `func streamTranslate(text: String) -> AsyncThrowingStream<String, Error>`

- [ ] **Step 1: Write the failing test**
Create `GhostTranslate/Tests/GhostTranslateTests/TyphoonServiceTests.swift`:
```swift
import XCTest
@testable import GhostTranslateCore

final class TyphoonServiceTests: XCTestCase {
    func testRequestPayloadEncoding() throws {
        let request = TyphoonRequest(
            model: "typhoon-v2.5-30b-a3b-instruct",
            messages: [
                TyphoonMessage(role: "system", content: "You are a translator."),
                TyphoonMessage(role: "user", content: "Hello world")
            ],
            maxTokens: 100,
            temperature: 0.3
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["model"] as? String, "typhoon-v2.5-30b-a3b-instruct")
    }

    func testResponseParsing() throws {
        let jsonString = """
        {
            "id": "chatcmpl-test",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "สวัสดีชาวโลก"}
            }]
        }
        """
        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(TyphoonResponse.self, from: data)
        XCTAssertEqual(response.choices.first?.message.content, "สวัสดีชาวโลก")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**
Run: `swift test --package-path GhostTranslate --filter TyphoonServiceTests`
Expected: FAIL.

- [ ] **Step 3: Implement TyphoonModels, TyphoonService, and Prompts**
Implement models, async HTTP requests using `URLSession`, streaming SSE support, and prompt templates for Subtitles and Interview Co-pilot.

- [ ] **Step 4: Run test to verify it passes**
Run: `swift test --package-path GhostTranslate --filter TyphoonServiceTests`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add GhostTranslate/Sources/GhostTranslateCore/AI GhostTranslate/Tests/GhostTranslateTests/TyphoonServiceTests.swift
git commit -m "feat(ai): implement TyphoonService client for translation and interview assistance"
```

---

### Task 4: Screen OCR Engine (VisionOCREngine & ScreenSnipper)

**Files:**
- Create: `GhostTranslate/Sources/GhostTranslateCore/OCR/VisionOCREngine.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/OCR/ScreenSnipper.swift`
- Test: `GhostTranslate/Tests/GhostTranslateTests/VisionOCREngineTests.swift`

**Interfaces:**
- Produces:
  - `class VisionOCREngine`: `func recognizeText(from image: CGImage) async throws -> String`
  - `class ScreenSnipper`: Displays transparent overlay to select rect, captures area via `CGWindowListCreateImage`, and invokes OCR.

- [ ] **Step 1: Write the failing test**
Create `GhostTranslate/Tests/GhostTranslateTests/VisionOCREngineTests.swift`:
```swift
import XCTest
import CoreGraphics
import AppKit
@testable import GhostTranslateCore

final class VisionOCREngineTests: XCTestCase {
    func testRecognizeTextFromSyntheticImage() async throws {
        let engine = VisionOCREngine()
        // Create an NSImage with text "GHOST TRANSLATE"
        let size = NSSize(width: 300, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSString(string: "GHOST TRANSLATE").draw(at: NSPoint(x: 20, y: 30), withAttributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.black
        ])
        image.unlockFocus()
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("Failed to create CGImage")
            return
        }
        
        let recognized = try await engine.recognizeText(from: cgImage)
        XCTAssertTrue(recognized.contains("GHOST") || recognized.contains("TRANSLATE"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**
Run: `swift test --package-path GhostTranslate --filter VisionOCREngineTests`
Expected: FAIL.

- [ ] **Step 3: Implement VisionOCREngine and ScreenSnipper**
Use `VNRecognizeTextRequest` with `.accurate` recognition level and automatic language recognition.

- [ ] **Step 4: Run test to verify it passes**
Run: `swift test --package-path GhostTranslate --filter VisionOCREngineTests`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add GhostTranslate/Sources/GhostTranslateCore/OCR GhostTranslate/Tests/GhostTranslateTests/VisionOCREngineTests.swift
git commit -m "feat(ocr): implement VisionOCREngine for on-device screen text capture"
```

---

### Task 5: Audio Capture & Speech Transcription Engine

**Files:**
- Create: `GhostTranslate/Sources/GhostTranslateCore/Audio/AudioTranscriptionEngine.swift`
- Test: `GhostTranslate/Tests/GhostTranslateTests/AudioTranscriptionTests.swift`

**Interfaces:**
- Produces:
  - `class AudioTranscriptionEngine: ObservableObject`:
    - `@Published var transcript: String`
    - `@Published var isRecording: Bool`
    - `func startTranscription(locale: Locale) throws`
    - `func stopTranscription()`

- [ ] **Step 1: Write the unit test**
Create `GhostTranslate/Tests/GhostTranslateTests/AudioTranscriptionTests.swift`:
```swift
import XCTest
@testable import GhostTranslateCore

final class AudioTranscriptionTests: XCTestCase {
    func testEngineInitialization() {
        let engine = AudioTranscriptionEngine()
        XCTAssertFalse(engine.isRecording)
        XCTAssertTrue(engine.transcript.isEmpty)
    }
}
```

- [ ] **Step 2: Implement AudioTranscriptionEngine**
Implement `AVAudioEngine` tap and `SFSpeechRecognizer` request pipeline with error handling.

- [ ] **Step 3: Run test to verify it passes**
Run: `swift test --package-path GhostTranslate --filter AudioTranscriptionTests`
Expected: PASS.

- [ ] **Step 4: Commit**
```bash
git add GhostTranslate/Sources/GhostTranslateCore/Audio GhostTranslate/Tests/GhostTranslateTests/AudioTranscriptionTests.swift
git commit -m "feat(audio): implement real-time speech transcription engine"
```

---

### Task 6: UI Components (Subtitle Bar, Interview Prompter, Settings)

**Files:**
- Create: `GhostTranslate/Sources/GhostTranslateCore/UI/SubtitleBarView.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/UI/InterviewPrompterView.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/UI/GhostHUDContainerView.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/UI/SettingsView.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/State/AppState.swift`

**Interfaces:**
- Produces:
  - `AppState`: Coordinates audio transcription, Typhoon API calls, UI modes, and settings.
  - `GhostHUDContainerView`: Hosts either `SubtitleBarView` or `InterviewPrompterView` with drag handle, click-through button, opacity controls.
  - `SettingsView`: API key input, model selection, hotkey reference.

- [ ] **Step 1: Implement AppState**
Manage state, transcription debouncing, Typhoon translation requests, and persistence in `UserDefaults`.

- [ ] **Step 2: Implement SubtitleBarView & InterviewPrompterView**
Render modern glassmorphic UI with vibrant Thai typography, real-time typing animation, and bullet points.

- [ ] **Step 3: Implement GhostHUDContainerView & SettingsView**
Include mode switch button, opacity slider, drag controls, and click-through toggle.

- [ ] **Step 4: Verify Compilation**
Run: `swift build --package-path GhostTranslate`
Expected: SUCCESS.

- [ ] **Step 5: Commit**
```bash
git add GhostTranslate/Sources/GhostTranslateCore/UI GhostTranslate/Sources/GhostTranslateCore/State
git commit -m "feat(ui): implement SubtitleBar, InterviewPrompter HUD, and Settings views"
```

---

### Task 7: Executable Application, MenuBar Controller & Hotkeys

**Files:**
- Create: `GhostTranslate/Sources/GhostTranslateAppTarget/main.swift`
- Create: `GhostTranslate/Sources/GhostTranslateAppTarget/GhostTranslateApp.swift`
- Create: `GhostTranslate/Sources/GhostTranslateAppTarget/MenuBarController.swift`
- Create: `GhostTranslate/Sources/GhostTranslateCore/Window/HotkeyManager.swift`

**Interfaces:**
- Produces:
  - Standalone executable initializing `NSApplication`, `MenuBarController`, and global hotkeys.

- [ ] **Step 1: Implement HotkeyManager**
Use `NSEvent.addGlobalMonitorForEvents` and local monitors for `⌘+⌥+G`, `⌘+⌥+M`, `⌘+⌥+O`, `⌘+⌥+C`.

- [ ] **Step 2: Implement MenuBarController & App Lifecycle**
Create Status Item with Ghost icon, quick status toggle, mode picker, and preferences menu.

- [ ] **Step 3: Build Executable**
Run: `swift build --package-path GhostTranslate`
Expected: SUCCESS.

- [ ] **Step 4: Commit**
```bash
git add GhostTranslate/Sources/GhostTranslateAppTarget GhostTranslate/Sources/GhostTranslateCore/Window/HotkeyManager.swift
git commit -m "feat(app): implement MenuBar controller, hotkeys, and app entry point"
```

---

### Task 8: App Icon, Packaging & Installation to /Applications

**Files:**
- Create: `GhostTranslate/scripts/generate_icon.py`
- Create: `GhostTranslate/scripts/package_app.sh`
- Create: `GhostTranslate/Resources/Info.plist`
- Create: `GhostTranslate/Resources/GhostTranslate.entitlements`

**Interfaces:**
- Produces:
  - `/Applications/GhostTranslate.app` with AppIcon and entitlements (Microphone, Speech Recognition, Screen Capture).

- [ ] **Step 1: Create Info.plist and entitlements**
Configure `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, and `LSUIElement = true` (Menu Bar app).

- [ ] **Step 2: Create generate_icon.py and build app icon**
Generate sleek glassmorphic ghost icon with translation glyphs (`.icns`).

- [ ] **Step 3: Create and run package_app.sh**
Build release binary, construct `.app` bundle structure, copy icon, and install to `/Applications/GhostTranslate.app`.

- [ ] **Step 4: Verify Installation and Stealth Window**
Launch `/Applications/GhostTranslate.app`, verify process runs, verify `sharingType == .none`, and test live Typhoon translation.

- [ ] **Step 5: Commit**
```bash
git add GhostTranslate/scripts GhostTranslate/Resources
git commit -m "feat(package): add icon generator, packaging script, and install to /Applications"
```
