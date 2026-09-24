# DropMorph Target File Size (MB) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement target file size selection (MB) for DropMorph across Images, PDFs, and Videos, enabling users to choose presets (`1 MB`, `2 MB`, `5 MB`, `10 MB`, `25 MB`) or custom MB limits with auto-converging compression algorithms and an intuitive UI.

**Architecture:** Extend `ConversionSettings` with `CompressionMode` and `targetSizeMB`. In `ImageConverter`, implement fast in-memory binary search quality convergence with smart dimension downscaling fallback. In `PDFCompressor`, implement per-page budget scaling. In `VideoConverter`, calculate exact dynamic average bitrates. In `SettingsBarView`, add a clean mode switcher with preset chips and custom numeric stepper.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, ImageIO, CoreGraphics, PDFKit, AVFoundation.

## Global Constraints

- Zero external third-party dependencies; native macOS Apple Silicon APIs only.
- Strict file size guarantee: output file size must be `<= targetBytes`.
- If input file is already `<= targetBytes`, preserve high quality without unnecessary degradation.
- All existing tests in `DropMorphTests` must pass without regressions.

---

### Task 1: Data Models & Settings Architecture

**Files:**
- Modify: `DropMorph/Sources/DropMorphCore/Models/ConversionSettings.swift`
- Test: `DropMorph/Tests/DropMorphTests/EngineTests.swift`

**Interfaces:**
- Produces:
  - `enum CompressionMode: String, CaseIterable, Identifiable, Sendable { case quality, targetSize }`
  - `ConversionSettings.mode: CompressionMode`
  - `ConversionSettings.targetSizeMB: Double`
  - `ConversionSettings.targetSizeBytes: Int64`

- [ ] **Step 1: Write the failing test for `ConversionSettings`**

Add in `DropMorph/Tests/DropMorphTests/EngineTests.swift`:
```swift
func testConversionSettingsTargetSizeMode() {
    var settings = ConversionSettings()
    XCTAssertEqual(settings.mode, .quality)
    XCTAssertEqual(settings.targetSizeMB, 2.0)
    XCTAssertEqual(settings.targetSizeBytes, 2 * 1024 * 1024)
    
    settings.mode = .targetSize
    settings.targetSizeMB = 0.5
    XCTAssertEqual(settings.targetSizeBytes, Int64(0.5 * 1024 * 1024))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph" --filter testConversionSettingsTargetSizeMode`
Expected: FAIL due to missing `mode` and `targetSizeMB`.

- [ ] **Step 3: Update `ConversionSettings.swift`**

Modify `DropMorph/Sources/DropMorphCore/Models/ConversionSettings.swift`:
```swift
import Foundation

public enum CompressionMode: String, CaseIterable, Identifiable, Sendable {
    case quality = "Quality"
    case targetSize = "Target Size"

    public var id: String { rawValue }
}

public struct ConversionSettings: Sendable {
    public var targetFormat: OutputFormat
    public var mode: CompressionMode
    public var quality: Double // 0.1 to 1.0
    public var targetSizeMB: Double // e.g. 1.0, 2.0, 5.0, 25.0
    public var resizePreset: ResizePreset
    public var stripMetadata: Bool
    public var customOutputFolder: URL?

    public var targetSizeBytes: Int64 {
        Int64(max(0.05, targetSizeMB) * 1024 * 1024)
    }

    public init(
        targetFormat: OutputFormat = .webp,
        mode: CompressionMode = .quality,
        quality: Double = 0.8,
        targetSizeMB: Double = 2.0,
        resizePreset: ResizePreset = .original,
        stripMetadata: Bool = true,
        customOutputFolder: URL? = nil
    ) {
        self.targetFormat = targetFormat
        self.mode = mode
        self.quality = quality
        self.targetSizeMB = targetSizeMB
        self.resizePreset = resizePreset
        self.stripMetadata = stripMetadata
        self.customOutputFolder = customOutputFolder
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph" --filter testConversionSettingsTargetSizeMode`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add DropMorph/Sources/DropMorphCore/Models/ConversionSettings.swift DropMorph/Tests/DropMorphTests/EngineTests.swift
git commit -m "feat(dropmorph): add CompressionMode and targetSizeMB to ConversionSettings"
```

---

### Task 2: Image Target Size Optimization Engine

**Files:**
- Modify: `DropMorph/Sources/DropMorphCore/Services/ImageConverter.swift`
- Test: `DropMorph/Tests/DropMorphTests/EngineTests.swift`

**Interfaces:**
- Consumes: `ConversionSettings.mode`, `ConversionSettings.targetSizeBytes`, `ConversionSettings.targetFormat`
- Produces: `ImageConverter.convert` respecting target size when `mode == .targetSize` via in-memory binary search and downscaling fallback.

- [ ] **Step 1: Write failing test for image target size compression**

Add to `DropMorph/Tests/DropMorphTests/EngineTests.swift`:
```swift
func testImageTargetSizeCompressionJPEG() throws {
    let inputURL = createTestImage(width: 1200, height: 1200, format: "png")
    let targetMB = 0.2 // 200 KB
    let settings = ConversionSettings(targetFormat: .jpeg, mode: .targetSize, targetSizeMB: targetMB)

    let outputURL = try ImageConverter.convert(inputURL: inputURL, settings: settings)
    let fileSize = (try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

    XCTAssertTrue(fileSize > 0)
    XCTAssertLessThanOrEqual(fileSize, settings.targetSizeBytes + 4096) // small tolerance for filesystem metadata
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph" --filter testImageTargetSizeCompressionJPEG`
Expected: FAIL or size exceeds 200 KB because targetSize is not yet implemented in `ImageConverter`.

- [ ] **Step 3: Implement target size logic in `ImageConverter.swift`**

In `DropMorph/Sources/DropMorphCore/Services/ImageConverter.swift`:
1. Check `settings.mode == .targetSize`:
   - If input file size is already `< settings.targetSizeBytes`, proceed with standard high quality (0.92).
   - Implement `findBestQuality(cgImage:format:targetBytes:sourceProps:)`:
     - Binary search in RAM using `CGImageDestinationCreateWithData` (4 iterations, testing `midQ` in `[0.05, 0.95]`).
   - If even at `q = 0.08` the size is `> settings.targetSizeBytes`:
     - Calculate `scale = sqrt(Double(settings.targetSizeBytes) / Double(data.count)) * 0.92`.
     - Downscale `cgImage` via `CGContext` or `renderScaledCGImage`.
     - Re-encode at `q = 0.75` with the resized CGImage.
2. For WebP, pass quality derived from target size or `-size` parameter to `cwebp`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph" --filter testImageTargetSizeCompressionJPEG`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add DropMorph/Sources/DropMorphCore/Services/ImageConverter.swift DropMorph/Tests/DropMorphTests/EngineTests.swift
git commit -m "feat(dropmorph): implement in-memory binary search target size image compression"
```

---

### Task 3: PDF Target Size Compression Engine

**Files:**
- Modify: `DropMorph/Sources/DropMorphCore/Services/PDFCompressor.swift`
- Test: `DropMorph/Tests/DropMorphTests/EngineTests.swift`

**Interfaces:**
- Consumes: `ConversionSettings.mode`, `ConversionSettings.targetSizeBytes`
- Produces: `PDFCompressor.compressPDF` producing output `<= targetSizeBytes`.

- [ ] **Step 1: Write failing test for PDF target size compression**

Add to `DropMorph/Tests/DropMorphTests/EngineTests.swift`:
```swift
func testPDFTargetSizeCompression() throws {
    let page1 = createTestImage(width: 800, height: 1000, format: "png")
    let page2 = createTestImage(width: 800, height: 1000, format: "png")
    let mergedPDF = tempDirectory.appendingPathComponent("sample.pdf")
    _ = try PDFMerger.mergeToPDF(imageURLs: [page1, page2], outputURL: mergedPDF, quality: 1.0)

    let targetMB = 0.3 // 300 KB
    let settings = ConversionSettings(targetFormat: .pdf, mode: .targetSize, targetSizeMB: targetMB)

    let compressedURL = try PDFCompressor.compressPDF(inputURL: mergedPDF, settings: settings)
    let fileSize = (try FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? Int64) ?? 0

    XCTAssertTrue(fileSize > 0)
    XCTAssertLessThanOrEqual(fileSize, settings.targetSizeBytes + 8192)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph" --filter testPDFTargetSizeCompression`
Expected: FAIL.

- [ ] **Step 3: Implement target size logic in `PDFCompressor.swift`**

In `PDFCompressor.swift`:
- When `settings.mode == .targetSize`:
  - Calculate `budgetPerPage = settings.targetSizeBytes / Int64(pageCount)`.
  - Calculate dynamic scale: `min(1.5, max(0.5, sqrt(Double(budgetPerPage) / 100_000.0) * 1.2))`.
  - Calculate dynamic JPEG quality: `min(0.85, max(0.2, Double(budgetPerPage) / 250_000.0))`.
  - Compile `PDFDocument` and check `dataRepresentation().count`.
  - If still `> settings.targetSizeBytes`, run a quick downscale adjustment pass on rasterized pages.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph" --filter testPDFTargetSizeCompression`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add DropMorph/Sources/DropMorphCore/Services/PDFCompressor.swift DropMorph/Tests/DropMorphTests/EngineTests.swift
git commit -m "feat(dropmorph): implement dynamic budget PDF target size compression"
```

---

### Task 4: Video Target Size Bitrate Budgeting

**Files:**
- Modify: `DropMorph/Sources/DropMorphCore/Services/VideoConverter.swift`
- Modify: `DropMorph/Sources/DropMorphCore/ViewModels/ConversionViewModel.swift`
- Test: `DropMorph/Tests/DropMorphTests/EngineTests.swift`

**Interfaces:**
- Consumes: `ConversionSettings.mode`, `ConversionSettings.targetSizeBytes`
- Produces: `VideoConverter.calculateTargetBitrate(durationSeconds:targetSizeBytes:) -> (videoBitrate: Int, audioBitrate: Int, targetResolution: CGSize)`

- [ ] **Step 1: Write test for video bitrate calculation**

Add to `DropMorph/Tests/DropMorphTests/EngineTests.swift`:
```swift
func testVideoTargetBitrateBudgeting() {
    let duration: Double = 60.0 // 1 minute video
    let targetMB = 10.0 // 10 MB
    let targetBytes = Int64(targetMB * 1024 * 1024)
    
    let budget = VideoConverter.calculateTargetBitrate(durationSeconds: duration, targetSizeBytes: targetBytes)
    
    XCTAssertGreaterThan(budget.videoBitrate, 500_000)
    XCTAssertLessThanOrEqual(budget.videoBitrate, 2_000_000)
    XCTAssertEqual(budget.audioBitrate, 96_000)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph" --filter testVideoTargetBitrateBudgeting`
Expected: FAIL.

- [ ] **Step 3: Implement bitrate budgeting in `VideoConverter.swift`**

Add helper method `calculateTargetBitrate` and integrate with `AVAssetExportSession` / custom export pipeline for video inputs when target format is video or converted to GIF.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph" --filter testVideoTargetBitrateBudgeting`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add DropMorph/Sources/DropMorphCore/Services/VideoConverter.swift DropMorph/Sources/DropMorphCore/ViewModels/ConversionViewModel.swift DropMorph/Tests/DropMorphTests/EngineTests.swift
git commit -m "feat(dropmorph): add dynamic bitrate budgeting for video target size"
```

---

### Task 5: UI Controls & Settings Bar

**Files:**
- Modify: `DropMorph/Sources/DropMorphCore/Views/SettingsBarView.swift`
- Modify: `DropMorph/Sources/DropMorphCore/Views/QueueItemRowView.swift`

**Interfaces:**
- Mode switcher capsule: `[ Quality (%) | Target Size (MB) ]`
- Preset chips: `1 MB`, `2 MB`, `5 MB`, `10 MB`, `25 MB`
- Stepper / custom text input for arbitrary decimal MB values

- [ ] **Step 1: Update `SettingsBarView.swift` with Mode Switcher & Target Size Controls**

Add:
- Capsule button picker for `viewModel.settings.mode` (`.quality` vs `.targetSize`).
- When in `.quality` mode: Show existing Quality Slider.
- When in `.targetSize` mode:
  - Preset chips (`1 MB`, `2 MB`, `5 MB`, `10 MB`, `25 MB`) with active highlight state.
  - Stepper & decimal text field `[ 2.0 ] MB` with formatted number display.

- [ ] **Step 2: Update `QueueItemRowView.swift`**

Display target MB badge if item is processed in target size mode (e.g. `≤ 2.0 MB`).

- [ ] **Step 3: Test UI compilation**

Run: `swift build --package-path "/Users/panpan/Mac project/DropMorph"`
Expected: Build succeeds with 0 errors.

- [ ] **Step 4: Commit changes**

```bash
git add DropMorph/Sources/DropMorphCore/Views/SettingsBarView.swift DropMorph/Sources/DropMorphCore/Views/QueueItemRowView.swift
git commit -m "feat(dropmorph): add Mode Switcher and Target Size preset chips to SettingsBarView"
```

---

### Task 6: Full Suite Verification & App Deployment

**Files:**
- Test: All tests in `DropMorphTests`
- Target: `/Applications/DropMorph.app`

- [ ] **Step 1: Run all unit tests**

Run: `swift test --package-path "/Users/panpan/Mac project/DropMorph"`
Expected: All tests pass cleanly.

- [ ] **Step 2: Build release application and bundle**

Run: `cd "/Users/panpan/Mac project/DropMorph" && ./scripts/package_app.sh`

- [ ] **Step 3: Install updated app to `/Applications/DropMorph.app`**

Ensure `/Applications/DropMorph.app` is updated with the new binary and resources.

- [ ] **Step 4: Commit final release updates**

```bash
git add .
git commit -m "release(dropmorph): deploy target file size (MB) feature"
```
