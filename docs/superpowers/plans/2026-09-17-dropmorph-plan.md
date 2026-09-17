# DropMorph Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS drag-and-drop image conversion, compression, and PDF merging utility in Swift/SwiftUI with both a Glassmorphic floating window and Menu Bar integration.

**Architecture:** A standalone Swift Package Manager project inside the `DropMorph/` subdirectory. Decoupled into core processing engines (`ImageConverter`, `PDFMerger`), reactive state view model (`ConversionViewModel`), and modern SwiftUI views with macOS vibrancy materials and window management.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, ImageIO (`CGImageSource`/`CGImageDestination`), UniformTypeIdentifiers, PDFKit.

## Global Constraints
- Target platform: macOS 14.0+ (Tested on macOS 15.0 Sequoia, Swift 6.2)
- Must be contained completely within the `DropMorph/` folder so additional projects can reside in the workspace root
- Strictly zero external third-party dependencies (100% native Apple SDKs)
- Hardware-accelerated local processing (no cloud dependencies, runs 100% offline)

---

### Task 1: Project Scaffolding & SPM Package Setup

**Files:**
- Create: `DropMorph/Package.swift`
- Create: `DropMorph/Sources/DropMorph/DropMorphApp.swift`
- Create: `DropMorph/Tests/DropMorphTests/DropMorphTests.swift`

**Interfaces:**
- Produces: Executable package `DropMorph` targeting macOS 14.0+

- [ ] **Step 1: Create Package.swift**
Create the SPM package file configured with an executable target `DropMorph` and a test target `DropMorphTests`.

- [ ] **Step 2: Create initial placeholder main entry point**
Create `DropMorphApp.swift` with minimal SwiftUI `App` lifecycle.

- [ ] **Step 3: Verify build**
Run: `swift build` inside `DropMorph/`
Expected: Build succeeds with 0 errors.

- [ ] **Step 4: Commit**
Run: `git add DropMorph/ && git commit -m "feat(scaffold): initialize DropMorph SPM project"`

---

### Task 2: Core Models & Settings

**Files:**
- Create: `DropMorph/Sources/DropMorph/Models/OutputFormat.swift`
- Create: `DropMorph/Sources/DropMorph/Models/ConversionSettings.swift`
- Create: `DropMorph/Sources/DropMorph/Models/ConversionItem.swift`

**Interfaces:**
- Produces:
  - `enum OutputFormat: String, CaseIterable, Identifiable`: `.webp`, `.png`, `.jpeg`, `.heic`, `.pdf`, `.tiff` with `utType: UTType`, `fileExtension: String`, `displayName: String`
  - `struct ConversionSettings`: `quality: Double`, `scaleFactor: Double`, `maxDimension: CGFloat?`, `stripMetadata: Bool`, `targetFormat: OutputFormat`, `outputDirectory: URL?`
  - `class ConversionItem: Identifiable, ObservableObject`: `id: UUID`, `inputURL: URL`, `outputURL: URL?`, `status: Status` (`.pending`, `.converting`, `.success`, `.failed(String)`), `originalSize: Int64`, `convertedSize: Int64?`

- [ ] **Step 1: Write OutputFormat.swift**
Define the supported output formats with their respective `UTType` constants and icon names.

- [ ] **Step 2: Write ConversionSettings.swift**
Define user-configurable conversion properties with default values (quality = 0.8, scaleFactor = 1.0, stripMetadata = true).

- [ ] **Step 3: Write ConversionItem.swift**
Define model representing an item in the conversion queue, formatted file sizes, and savings percentage calculation.

- [ ] **Step 4: Verify build**
Run: `swift build` inside `DropMorph/`
Expected: Build succeeds.

- [ ] **Step 5: Commit**
Run: `git add DropMorph/Sources/DropMorph/Models/ && git commit -m "feat(models): add OutputFormat, ConversionSettings, and ConversionItem"`

---

### Task 3: ImageIO & PDFKit Conversion Engine with Automated Tests

**Files:**
- Create: `DropMorph/Sources/DropMorph/Services/ImageConverter.swift`
- Create: `DropMorph/Sources/DropMorph/Services/PDFMerger.swift`
- Create: `DropMorph/Tests/DropMorphTests/EngineTests.swift`

**Interfaces:**
- Produces:
  - `ImageConverter.convert(inputURL: URL, outputFormat: OutputFormat, settings: ConversionSettings) throws -> URL`
  - `PDFMerger.mergeToPDF(imageURLs: [URL], outputURL: URL) throws -> URL`

- [ ] **Step 1: Write failing unit test in EngineTests.swift**
Create a test that generates a synthetic test `CGImage`, saves it to disk as PNG, calls `ImageConverter.convert` to WebP and JPEG, and calls `PDFMerger.mergeToPDF`.

- [ ] **Step 2: Run test to verify it fails**
Run: `swift test` inside `DropMorph/`
Expected: FAIL with "cannot find ImageConverter in scope"

- [ ] **Step 3: Implement ImageConverter.swift**
Implement image decoding using `CGImageSourceCreateWithURL`, resize/downsample calculation, quality parameter binding via `kCGImageDestinationLossyCompressionQuality`, and file output via `CGImageDestinationCreateWithURL`.

- [ ] **Step 4: Implement PDFMerger.swift**
Implement multi-image PDF compilation using `PDFDocument` and `PDFPage(image:)`.

- [ ] **Step 5: Run tests to verify all pass**
Run: `swift test` inside `DropMorph/`
Expected: PASS all tests.

- [ ] **Step 6: Commit**
Run: `git add DropMorph/Sources/DropMorph/Services/ DropMorph/Tests/ && git commit -m "feat(engine): implement ImageConverter and PDFMerger with tests"`

---

### Task 4: ConversionViewModel & State Management

**Files:**
- Create: `DropMorph/Sources/DropMorph/ViewModels/ConversionViewModel.swift`

**Interfaces:**
- Consumes: `ImageConverter`, `PDFMerger`, `ConversionItem`, `ConversionSettings`
- Produces:
  - `class ConversionViewModel: ObservableObject`
  - `@Published var queue: [ConversionItem]`
  - `@Published var settings: ConversionSettings`
  - `@Published var isProcessing: Bool`
  - `@Published var isPinnedOnTop: Bool`
  - `func handleDroppedURLs(_ urls: [URL])`
  - `func processQueue()`
  - `func mergeQueueToPDF()`
  - `func clearQueue()`
  - `func toggleAlwaysOnTop()`

- [ ] **Step 1: Implement ConversionViewModel**
Write the view model with async queue execution, concurrency throttling, and total bytes saved calculation.

- [ ] **Step 2: Verify build**
Run: `swift build` inside `DropMorph/`
Expected: Build succeeds.

- [ ] **Step 3: Commit**
Run: `git add DropMorph/Sources/DropMorph/ViewModels/ && git commit -m "feat(viewmodel): implement ConversionViewModel"`

---

### Task 5: Glassmorphic UI Components & Dashboard

**Files:**
- Create: `DropMorph/Sources/DropMorph/Views/DropZoneView.swift`
- Create: `DropMorph/Sources/DropMorph/Views/QueueItemRowView.swift`
- Create: `DropMorph/Sources/DropMorph/Views/SettingsBarView.swift`
- Create: `DropMorph/Sources/DropMorph/Views/DashboardView.swift`

**Interfaces:**
- Consumes: `ConversionViewModel`
- Produces:
  - `DropZoneView`: Interactive drop target with animated hover borders and file intake
  - `QueueItemRowView`: Individual conversion card with thumbnail, size diff, progress indicator, and reveal in Finder button
  - `SettingsBarView`: Quality slider, format picker pills, resize selector
  - `DashboardView`: Complete main window view layout

- [ ] **Step 1: Implement DropZoneView.swift**
Design a visual dropzone with drop target listeners (`.dropDestination`), SF Symbols, and pulsing hover animation.

- [ ] **Step 2: Implement QueueItemRowView.swift**
Design a row item showing original image thumbnail, filename, status badge, savings pill (e.g. `-64%`), and action buttons (Finder reveal, delete).

- [ ] **Step 3: Implement SettingsBarView.swift**
Design modern horizontal controls for format selection, quality slider, and resize menu.

- [ ] **Step 4: Implement DashboardView.swift**
Compose the window header (title, pin button, stats pill), central content (empty dropzone or queue list), and bottom actions ("Convert All", "Merge PDF", "Clear").

- [ ] **Step 5: Verify build**
Run: `swift build` inside `DropMorph/`
Expected: Build succeeds.

- [ ] **Step 6: Commit**
Run: `git add DropMorph/Sources/DropMorph/Views/ && git commit -m "feat(ui): implement modern glassmorphic dashboard views"`

---

### Task 6: Menu Bar Integration & Window Management

**Files:**
- Create: `DropMorph/Sources/DropMorph/Views/MenuBarPopoverView.swift`
- Modify: `DropMorph/Sources/DropMorph/DropMorphApp.swift`

**Interfaces:**
- Produces:
  - `MenuBarExtra` accessory item with drop capability and quick format switch
  - Floating window level manager (`NSWindow.level = .floating`)

- [ ] **Step 1: Implement MenuBarPopoverView.swift**
Create a compact popover for the Menu Bar with quick dropzone and format selector.

- [ ] **Step 2: Wire App entry point with MenuBarExtra & WindowGroup**
Update `DropMorphApp.swift` with both `MenuBarExtra("DropMorph", systemImage: "arrow.triangle.2.circlepath.circle.fill")` and the primary `WindowGroup`.

- [ ] **Step 3: Verify build**
Run: `swift build` inside `DropMorph/`
Expected: Build succeeds.

- [ ] **Step 4: Commit**
Run: `git add DropMorph/Sources/DropMorph/ && git commit -m "feat(app): configure hybrid MenuBarExtra and window management"`

---

### Task 7: App Bundle Packaging & End-to-End Verification

**Files:**
- Create: `DropMorph/scripts/package_app.sh`
- Create: `DropMorph/Resources/Info.plist`

- [ ] **Step 1: Create Info.plist & packaging script**
Create a standalone `.app` packager script that compiles release binary, embeds `Info.plist`, creates `DropMorph.app`, and allows double-clicking or moving to `/Applications`.

- [ ] **Step 2: Run build and package script**
Run: `chmod +x DropMorph/scripts/package_app.sh && ./DropMorph/scripts/package_app.sh`
Expected: `DropMorph.app` generated successfully.

- [ ] **Step 3: Run automated tests**
Run: `swift test` inside `DropMorph/`
Expected: All tests pass.

- [ ] **Step 4: Final commit & Walkthrough documentation**
Create walkthrough documentation and commit.
