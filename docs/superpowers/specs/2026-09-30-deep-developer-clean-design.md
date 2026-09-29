# Design Specification: SweepSpace Deep Developer & Package Cleaner

## 1. Overview
This enhancement equips **SweepSpace** with deep scanning capabilities tailored for developers. It detects and cleans both **Global Environment & Package Caches** (Gradle, iOS Simulators, Go, Python, Rust, npm) and **Project-Level Dependencies & Build Artifacts** (`node_modules`, `.build`, `target`, `venv`) across the user's workspace, safely unlocking 20GB–80GB+ of storage.

---

## 2. Architecture & Components

### 2.1 Domain Classification
1. **Global Package & Tooling Caches** (Safe to clear; tools recreate automatically):
   - **Gradle / Java**: `~/.gradle/caches`, `~/.m2/repository`
   - **iOS Simulator Runtimes & Devices**: `~/Library/Developer/CoreSimulator/Devices`, `~/Library/Developer/CoreSimulator/Caches`
   - **Go**: `~/go/pkg/mod`, `~/.cache/go-build`
   - **Python**: `~/.cache/pip`, `~/Library/Caches/pypoetry`
   - **Rust**: `~/.cargo/registry`, `~/.cargo/git`
   - **Node.js**: `~/.npm`, `~/.yarn/berry/cache`, `~/.pnpm-store`
   - **Xcode**: `DerivedData`, `Archives`, `iOS DeviceSupport`
   - **Homebrew**: `~/Library/Caches/Homebrew`

2. **Project-Level Dependencies & Artifacts** (Safe to remove; reconstructible via package managers):
   - `node_modules` (JavaScript / TypeScript / Web)
   - `.build` (Swift Package Manager)
   - `target` (Rust Cargo)
   - `venv` / `.venv` (Python Virtual Environments)
   - `Pods` (CocoaPods)
   - Search Roots: `~` up to depth 4 (excluding system / Library / Applications).

### 2.2 Core Engine Updates (`ScanRuleCatalog` & `DiskScanEngine`)
- Added dedicated rules for all global package caches with individual size reporting.
- Added recursive project dependency scanner:
  - Scans user home directories for directories named `node_modules`, `.build`, `target`, `venv`, `.venv`, `Pods`.
  - Skips internal hidden tooling directories (`.git`, `.vscode`, `.cursor/extensions`, Library).
  - Categorizes items under `developerJunk` or sub-category `projectDependencies`.
  - Calculates directory size and file count asynchronously.

### 2.3 UI & UX Enhancements
- Dedicated **Developer Space** tab:
  - Section 1: **Global Package & Tool Caches** (Gradle, Simulator, Xcode, npm, Go).
  - Section 2: **Project Dependencies** (`node_modules`, `.build`, `venv` listed with project parent folder name and exact path).
  - Reassurance badge: *"Source code is 100% safe. Only installed packages and build caches are cleaned."*
  - Select all / individual item checkboxes.
  - "Reveal in Finder" button.

---

## 3. Testing & Safety
- Whitelist protection prevents deletion of root or user home directory.
- Deletion uses `FileManager.default.removeItem` for caches or `trashItem` for project dependencies.
- Unit tests verify scanning of project dependencies and calculation of sizes.
