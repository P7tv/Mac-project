# SweepSpace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS disk cleaning application (**SweepSpace**) that scans and cleans system/app caches, developer junk (Xcode DerivedData, npm, CocoaPods, Homebrew), large files (>100MB/500MB/1GB), and trash with live visual disk gauges and safety guarantees.

**Architecture:** Swift 5.9+ SPM project with `SweepSpaceCore` (data models, multi-threaded `DiskScanEngine`, `DiskCleaner`, and `SweepSpaceViewModel`) and `SweepSpace` app with modern SwiftUI + AppKit UI.

**Tech Stack:** Swift, SwiftUI, AppKit, Combine, Foundation.

## Global Constraints
- Target platform: macOS 13.0+ (Apple Silicon native)
- Safe operations: non-reversible deletion must be guarded; default to `FileManager.default.trashItem`
- High performance: recursive directory scanning using asynchronous task groups without blocking UI
- Visual polish: modern macOS Dark/Light styling with vibrant accents, circular disk gauges, and responsive micro-animations

---

### Task 1: Project Setup & Core Models

**Files:**
- Create: `SweepSpace/Package.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Models/CleanableItem.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Models/CleaningCategory.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Models/DiskSpaceInfo.swift`
- Create: `SweepSpace/Tests/SweepSpaceTests/ModelTests.swift`

- [x] **Step 1: Create `SweepSpace/Package.swift`**
- [x] **Step 2: Create data models (`CleanableItem`, `CleaningCategory`, `DiskSpaceInfo`)**
- [x] **Step 3: Write and run unit tests for models**
- [x] **Step 4: Commit changes**

---

### Task 2: Core Services (`DiskSpaceCalculator`, `ScanRuleCatalog`, `DiskScanEngine`, `DiskCleaner`)

**Files:**
- Create: `SweepSpace/Sources/SweepSpaceCore/Services/DiskSpaceCalculator.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Services/ScanRuleCatalog.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Services/DiskScanEngine.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Services/DiskCleaner.swift`
- Create: `SweepSpace/Tests/SweepSpaceTests/EngineTests.swift`

- [x] **Step 1: Write `DiskSpaceCalculator.swift` to read active volume metrics**
- [x] **Step 2: Write `ScanRuleCatalog.swift` with safe paths for caches, developer junk, and large files**
- [x] **Step 3: Write `DiskScanEngine.swift` for multi-threaded recursive size scanning**
- [x] **Step 4: Write `DiskCleaner.swift` for safe trash/deletion**
- [x] **Step 5: Write unit tests in `EngineTests.swift` and verify they pass**
- [x] **Step 6: Commit changes**

---

### Task 3: ViewModel (`SweepSpaceViewModel`)

**Files:**
- Create: `SweepSpace/Sources/SweepSpaceCore/ViewModels/SweepSpaceViewModel.swift`
- Create: `SweepSpace/Tests/SweepSpaceTests/ViewModelTests.swift`

- [x] **Step 1: Implement `SweepSpaceViewModel.swift` with scanning, selection management, and cleaning execution**
- [x] **Step 2: Write unit tests for ViewModel scanning, selection toggling, and size calculations**
- [x] **Step 3: Run tests to verify they pass**
- [x] **Step 4: Commit changes**

---

### Task 4: User Interface (SwiftUI + AppKit)

**Files:**
- Create: `SweepSpace/Sources/SweepSpaceCore/Views/DiskHeroCardView.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Views/CategoryRowView.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Views/CleanableItemRowView.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Views/LargeFilesBrowserView.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Views/CleanSummaryView.swift`
- Create: `SweepSpace/Sources/SweepSpaceCore/Views/MainDashboardView.swift`
- Create: `SweepSpace/Sources/SweepSpace/SweepSpaceApp.swift`

- [x] **Step 1: Build `DiskHeroCardView` with circular disk gauge and quick stats**
- [x] **Step 2: Build `CategoryRowView` and `CleanableItemRowView` with item selection and size badges**
- [x] **Step 3: Build `LargeFilesBrowserView` with size/type filters and QuickLook integration**
- [x] **Step 4: Build `CleanSummaryView` with celebration animation and reclaimed space readout**
- [x] **Step 5: Assemble `MainDashboardView` and `SweepSpaceApp`**
- [x] **Step 6: Build application and verify compilation**
- [x] **Step 7: Commit changes**

---

### Task 5: Packaging, App Icon & Deployment to `/Applications/SweepSpace.app`

**Files:**
- Create: `SweepSpace/Resources/Info.plist`
- Create: `SweepSpace/scripts/package_app.sh`
- Target: `/Applications/SweepSpace.app`

- [x] **Step 1: Generate modern App Icon for SweepSpace**
- [x] **Step 2: Create Info.plist and package_app.sh**
- [x] **Step 3: Run full automated test suite (`swift test`)**
- [x] **Step 4: Package and install `/Applications/SweepSpace.app`**
- [x] **Step 5: Verify app execution and launch**
- [x] **Step 6: Commit all remaining changes**
