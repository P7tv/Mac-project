# Design Specification: SweepSpace (All-in-One Mac Disk Cleaner)

## 1. Overview
**SweepSpace** is a modern, high-performance, native macOS disk cleaner and storage optimizer application built with Swift and SwiftUI. It empowers users to analyze disk usage, recover gigabytes of storage space, and safely remove system/app caches, developer junk, large/old files, and trash with one-click simplicity and granular control.

---

## 2. Core Architecture & Components

### 2.1 Backend / Services
- **`DiskSpaceCalculator`**:
  - Uses `FileManager` and `URLResourceKey` (`volumeAvailableCapacityForImportantUsageKey`, `volumeTotalCapacityKey`) to read active volume metrics.
  - Computes disk breakdown: Total space, Used space, Free space, and Recoverable space.
- **`DiskScanEngine`**:
  - Multi-threaded asynchronous scanning engine using Swift Concurrency (`TaskGroup`).
  - Scans target paths and computes file/folder sizes recursively without blocking the main actor.
- **`ScanRuleCatalog`**:
  - Curated, safety-verified rule-sets categorized into 4 domains:
    1. **System & App Caches**:
       - `~/Library/Caches/*`
       - `~/Library/Logs/*`
       - Temporary directories and crash reports
    2. **Developer Junk**:
       - Xcode DerivedData (`~/Library/Developer/Xcode/DerivedData`)
       - Xcode iOS DeviceSupport & Archives
       - CocoaPods cache (`~/Library/Caches/CocoaPods`)
       - SPM cache (`~/Library/Caches/org.swift.swiftpm`)
       - Homebrew cache (`~/Library/Caches/Homebrew`)
       - Node package manager cache (`~/.npm`, `~/.yarn/cache`, `~/.pnpm-store`)
       - Docker build caches (if detected)
    3. **Large & Old Files**:
       - Scans `~/Downloads`, `~/Documents`, `~/Movies`, etc. for files > 100MB, > 500MB, > 1GB.
       - Attributes: File type (Videos, Disk Images `.dmg/.iso`, Archives `.zip/.rar/.7z`, Documents), size, and last modified date.
    4. **Trash & Leftovers**:
       - User Trash (`~/.Trash`)
       - Orphaned application support folders
- **`DiskCleaner`**:
  - Executes deletion operations with safety guards:
    - Default mode: Move to Trash (`FileManager.default.trashItem`) for safe reversibility.
    - Optional mode: Permanent delete for system caches / DerivedData.
    - Safety whitelist: Never deletes system roots (`/System`, `/Library`, `/Applications`, or user home roots).

### 2.2 ViewModel: `SweepSpaceViewModel`
- Manages scan state (`idle`, `scanning`, `scanned`, `cleaning`, `cleaned`).
- Aggregates categorized scan results:
  - `cacheItems: [CleanableItem]`
  - `developerItems: [CleanableItem]`
  - `largeFileItems: [CleanableItem]`
  - `trashItems: [CleanableItem]`
- Tracks selection state, total selected bytes, and cleanup progress.
- Provides functions:
  - `startScan()`
  - `cleanSelected()`
  - `toggleItemSelection(id:)`
  - `selectAll(category:)`
  - `deselectAll(category:)`
  - `revealInFinder(url:)`
  - `quickLookItem(url:)`

### 2.3 UI Components (SwiftUI + AppKit)
- **`SweepSpaceApp`**: Native macOS window with customizable toolbar and sleek modern translucent backdrop (`NSVisualEffectView`).
- **`DiskHeroCard`**:
  - Circular / Radial ring progress indicator showing disk usage.
  - Large stat readout: "X GB Recoverable".
  - One-click **"⚡ Smart Clean"** action button.
- **`CategoryCardView`**:
  - Collapsible cards for each category with badges (item count, total size).
  - List of child items with path, size badge, and checkbox.
- **`LargeFilesBrowserView`**:
  - Size filter pills: All | >100MB | >500MB | >1GB.
  - Type filter pills: All | Media | Archives | Disk Images.
  - Sort by Size / Date.
- **`CleanSummarySheet`**:
  - Post-clean celebration with exact space recovered and updated disk stats.

---

## 3. Data Flow
1. User launches SweepSpace -> `DiskSpaceCalculator` loads total/used/free disk metrics.
2. User clicks "Scan" (or auto-scans on launch) -> `DiskScanEngine` scans predefined rules in parallel.
3. Live progress updates show scanning categories and discovered gigabytes.
4. Results displayed with pre-selected safe categories (System Cache & Developer DerivedData checked by default; Large Files unchecked by default for manual review).
5. User clicks "Clean Selected" -> `DiskCleaner` removes selected items, updates disk stats, and shows space reclaimed.

---

## 4. Testing & Verification
- Unit tests:
  - `DiskSpaceCalculatorTests`: verify capacity calculation.
  - `ScanRuleCatalogTests`: verify safety filters and paths.
  - `DiskCleanerTests`: verify safe deletion in sandbox temporary directories.
- Integration tests:
  - Package into `/Applications/SweepSpace.app`.
  - Verify app launches and scans accurately.
