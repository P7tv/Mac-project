# Deep Developer & Package Cleaner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Equip SweepSpace with deep scanning and cleaning of coding packages, libraries, build artifacts (`node_modules`, `.build`, `target`, `venv`), and global developer caches (Gradle 16GB, CoreSimulator 5.7GB, Go, npm, pip).

**Architecture:** Extend `ScanRuleCatalog` and `DiskScanEngine` to traverse project roots for dependency directories and expand global tool rules, then update the Developer tab in `MainDashboardView` with categorized filters and safety messaging.

**Tech Stack:** Swift, SwiftUI, AppKit, Foundation.

---

### Task 1: Expand Global Developer Cache Rules in `ScanRuleCatalog.swift`

**Files:**
- Modify: `SweepSpace/Sources/SweepSpaceCore/Services/ScanRuleCatalog.swift`
- Test: `SweepSpace/Tests/SweepSpaceTests/EngineTests.swift`

- [ ] **Step 1: Add rules for Gradle, CoreSimulator, Go, Cargo, pip, and Maven**
- [ ] **Step 2: Update unit tests in `EngineTests.swift`**
- [ ] **Step 3: Run tests to verify they pass**
- [ ] **Step 4: Commit changes**

---

### Task 2: Project-Level Dependency Scanner in `DiskScanEngine.swift`

**Files:**
- Modify: `SweepSpace/Sources/SweepSpaceCore/Services/DiskScanEngine.swift`
- Test: `SweepSpace/Tests/SweepSpaceTests/EngineTests.swift`

- [ ] **Step 1: Implement `scanProjectDependencies` targeting `node_modules`, `.build`, `target`, `venv`, `Pods`**
- [ ] **Step 2: Add unit tests verifying project dependency discovery and size calculation**
- [ ] **Step 3: Run tests to verify they pass**
- [ ] **Step 4: Commit changes**

---

### Task 3: Developer Tab UI & Filtering in `SweepSpaceCore`

**Files:**
- Modify: `SweepSpace/Sources/SweepSpaceCore/Views/MainDashboardView.swift`
- Modify: `SweepSpace/Sources/SweepSpaceCore/ViewModels/SweepSpaceViewModel.swift`

- [ ] **Step 1: Add developer dependency filtering helpers to `SweepSpaceViewModel`**
- [ ] **Step 2: Enhance the Developer Tab in `MainDashboardView` with Project Dependencies breakdown and sub-filter pills**
- [ ] **Step 3: Test build and compilation**
- [ ] **Step 4: Commit changes**

---

### Task 4: Packaging, Full Verification & Deployment to `/Applications/SweepSpace.app`

**Files:**
- Target: `/Applications/SweepSpace.app`

- [ ] **Step 1: Run full automated test suite (`swift test`)**
- [ ] **Step 2: Run `./scripts/package_app.sh` and install to `/Applications/SweepSpace.app`**
- [ ] **Step 3: Launch `/Applications/SweepSpace.app` and verify live operation**
- [ ] **Step 4: Commit final changes**
