# RarPeek: Native macOS RAR & Archive Inspector/Extractor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI application (`RarPeek`) that inspects and extracts RAR (RAR4, RAR5, multi-part, encrypted) and other common archives with full preview, selective extraction, bundled self-contained binaries, and installs to `/Applications/RarPeek.app`.

**Architecture:** A standalone Swift package (`RarPeek`) with `RarPeekCore` framework and `RarPeek` executable. Uses `lsar` for fast in-memory JSON listing without disk writes and `unar` for robust extraction with progress and password callbacks. Bundles `unar` and `lsar` inside the app bundle for zero external dependencies. Modern SwiftUI + AppKit frontend with drag-and-drop, search filter, and selective extraction.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Combine, bundled `unar` & `lsar` engines.

## Global Constraints

- Complete standalone app: bundled engine binaries in `Contents/Resources/bin/` so end users require no prerequisites.
- Accurate RAR support: handles RAR4, RAR5, multi-part (`.part1.rar`), solid archives, and password encryption.
- Inspect before extract: users can view all files, sizes, and dates before extracting.
- Fully verified via automated tests in `RarPeekTests`.

---

### Task 1: Project Scaffolding & Package Setup

**Files:**
- Create: `RarPeek/Package.swift`
- Create: `RarPeek/Resources/Info.plist`
- Create: `RarPeek/scripts/package_app.sh`
- Create: `RarPeek/Resources/bin/` (copy `unar`, `lsar`)

**Interfaces:**
- Produces: Compilable Swift package with `RarPeek` and `RarPeekCore` targets and `RarPeekTests`.

- [ ] **Step 1: Create `RarPeek/Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RarPeek",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RarPeek", targets: ["RarPeek"]),
        .library(name: "RarPeekCore", targets: ["RarPeekCore"])
    ],
    targets: [
        .target(
            name: "RarPeekCore",
            dependencies: [],
            path: "Sources/RarPeekCore"
        ),
        .executableTarget(
            name: "RarPeek",
            dependencies: ["RarPeekCore"],
            path: "Sources/RarPeek"
        ),
        .testTarget(
            name: "RarPeekTests",
            dependencies: ["RarPeekCore"],
            path: "Tests/RarPeekTests"
        )
    ]
)
```

- [ ] **Step 2: Copy engine binaries to `RarPeek/Resources/bin/`**

Copy `/opt/homebrew/bin/unar` and `/opt/homebrew/bin/lsar` into `RarPeek/Resources/bin/` and ensure executable permissions (`chmod +x`).

- [ ] **Step 3: Create `RarPeek/Resources/Info.plist` and `scripts/package_app.sh`**

Setup Info.plist with document type associations for `.rar`, `.7z`, `.zip` and build packaging script.

- [ ] **Step 4: Verify package builds**

Run: `swift build --package-path "/Users/panpan/Mac project/RarPeek"`
Expected: Build complete.

- [ ] **Step 5: Commit changes**

```bash
git add RarPeek
git commit -m "feat(rarpeek): scaffold project with bundled unar and lsar binaries"
```

---

### Task 2: Models & Archive Inspection Data Architecture

**Files:**
- Create: `RarPeek/Sources/RarPeekCore/Models/ArchiveEntry.swift`
- Create: `RarPeek/Sources/RarPeekCore/Models/ArchiveInfo.swift`
- Create: `RarPeek/Sources/RarPeekCore/Models/ExtractionOptions.swift`
- Test: `RarPeek/Tests/RarPeekTests/ArchiveModelTests.swift`

**Interfaces:**
- Produces:
  - `struct ArchiveEntry: Identifiable, Sendable` (id, index, path, name, uncompressedSize, compressedSize, isDirectory, isEncrypted, date)
  - `struct ArchiveInfo: Identifiable, Sendable` (fileURL, formatName, totalEntries, totalUncompressedBytes, isEncrypted, entries)
  - `struct ExtractionOptions: Sendable` (targetFolder, password, selectedIndexes, overwritePolicy)

- [ ] **Step 1: Write test for Models in `ArchiveModelTests.swift`**

Test entry size formatting, ratio calculation, and path leaf extraction.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path "/Users/panpan/Mac project/RarPeek" --filter ArchiveModelTests`
Expected: FAIL (models not yet defined).

- [ ] **Step 3: Implement `ArchiveEntry.swift`, `ArchiveInfo.swift`, `ExtractionOptions.swift`**

Implement models with computed properties (`formattedSize`, `compressionRatio`, `filename`).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path "/Users/panpan/Mac project/RarPeek" --filter ArchiveModelTests`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add RarPeek/Sources/RarPeekCore/Models RarPeek/Tests/RarPeekTests
git commit -m "feat(rarpeek): implement ArchiveEntry, ArchiveInfo, and ExtractionOptions models"
```

---

### Task 3: ArchiveEngine Service (Listing & Extraction via `lsar` & `unar`)

**Files:**
- Create: `RarPeek/Sources/RarPeekCore/Services/ArchiveEngine.swift`
- Test: `RarPeek/Tests/RarPeekTests/ArchiveEngineTests.swift`

**Interfaces:**
- Produces:
  - `ArchiveEngine.inspectArchive(url:password:) async throws -> ArchiveInfo`
  - `ArchiveEngine.extractArchive(url:options:onProgress:) async throws -> URL`

- [ ] **Step 1: Write failing integration test in `ArchiveEngineTests.swift`**

Create a test archive using `7zz` / `zip` with known files, test inspection and extraction.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path "/Users/panpan/Mac project/RarPeek" --filter ArchiveEngineTests`
Expected: FAIL.

- [ ] **Step 3: Implement `ArchiveEngine.swift`**

- Locate `lsar` and `unar` via bundled path or fallback.
- Run `lsar -j` subprocess, parse JSON output into `ArchiveInfo` and `ArchiveEntry` array.
- Run `unar` with `-o`, `-p`, `-r`, and optional `-i` indexes for selective extraction.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path "/Users/panpan/Mac project/RarPeek" --filter ArchiveEngineTests`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add RarPeek/Sources/RarPeekCore/Services RarPeek/Tests/RarPeekTests
git commit -m "feat(rarpeek): implement ArchiveEngine with lsar and unar wrapper"
```

---

### Task 4: ViewModels & State Management

**Files:**
- Create: `RarPeek/Sources/RarPeekCore/ViewModels/ArchiveViewModel.swift`
- Test: `RarPeek/Tests/RarPeekTests/ArchiveViewModelTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor public final class ArchiveViewModel: ObservableObject`
  - Published properties: `currentArchive`, `selectedEntryIDs`, `searchFilter`, `isExtracting`, `extractionProgress`, `passwordInput`, `isShowingPasswordPrompt`, `filteredEntries`.
  - Methods: `loadArchive(url:)`, `extractAll()`, `extractSelected()`, `revealExtractedFolder()`.

- [ ] **Step 1: Write test for `ArchiveViewModel`**

Test search filtering, selection toggles, and state transitions.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path "/Users/panpan/Mac project/RarPeek" --filter ArchiveViewModelTests`
Expected: FAIL.

- [ ] **Step 3: Implement `ArchiveViewModel.swift`**

Connect `ArchiveEngine` calls with main thread published states and search filter logic.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path "/Users/panpan/Mac project/RarPeek" --filter ArchiveViewModelTests`
Expected: PASS.

- [ ] **Step 5: Commit changes**

```bash
git add RarPeek/Sources/RarPeekCore/ViewModels RarPeek/Tests/RarPeekTests
git commit -m "feat(rarpeek): implement ArchiveViewModel state management"
```

---

### Task 5: SwiftUI User Interface Components

**Files:**
- Create: `RarPeek/Sources/RarPeekCore/Views/ArchiveDropZoneView.swift`
- Create: `RarPeek/Sources/RarPeekCore/Views/ArchiveInspectorView.swift`
- Create: `RarPeek/Sources/RarPeekCore/Views/ArchiveEntryRowView.swift`
- Create: `RarPeek/Sources/RarPeekCore/Views/PasswordPromptView.swift`
- Create: `RarPeek/Sources/RarPeek/RarPeekApp.swift`

**Interfaces:**
- Beautiful macOS window with smooth transitions between Drop Zone and Inspector View.
- File tree list with checkboxes, system file icons, format badges, and action toolbar.

- [ ] **Step 1: Implement Views**

Build `ArchiveDropZoneView`, `ArchiveInspectorView`, `ArchiveEntryRowView`, `PasswordPromptView`, and `RarPeekApp`.

- [ ] **Step 2: Verify build compiles cleanly**

Run: `swift build --package-path "/Users/panpan/Mac project/RarPeek"`
Expected: Build complete with 0 errors.

- [ ] **Step 3: Commit changes**

```bash
git add RarPeek/Sources
git commit -m "feat(rarpeek): implement modern SwiftUI user interface views"
```

---

### Task 6: Packaging, Verification & Deployment to `/Applications/RarPeek.app`

**Files:**
- Target: `/Applications/RarPeek.app`

- [ ] **Step 1: Run full test suite**

Run: `swift test --package-path "/Users/panpan/Mac project/RarPeek"`
Expected: All tests pass.

- [ ] **Step 2: Package Release App Bundle**

Run: `cd "/Users/panpan/Mac project/RarPeek" && ./scripts/package_app.sh`

- [ ] **Step 3: Install to `/Applications/RarPeek.app`**

Copy bundle to `/Applications/RarPeek.app` and sign ad-hoc.

- [ ] **Step 4: Verify application launch**

Run `open /Applications/RarPeek.app` and verify running process.

- [ ] **Step 5: Commit release updates**

```bash
git add .
git commit -m "release(rarpeek): deploy RarPeek.app v1.0.0 to /Applications"
```
