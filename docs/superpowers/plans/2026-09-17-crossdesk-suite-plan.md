# CrossDesk Suite Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the CrossDesk Suite—4 native macOS Apple Silicon utility applications (AirBridge, KeySync, AudioTunnel, QuickRecall) enabling zero-cloud, 100% wireless cross-platform synergy between Mac, Windows, and mobile devices.

**Architecture:** Each application lives as an independent, standalone project in `/Users/panpan/Mac project/` following the proven SPM package + macOS `.app` bundle architecture. High-performance communication is implemented using Apple `Network.framework`, `ScreenCaptureKit`, `CoreAudio`, and `Vision` with zero cloud external dependencies.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Network.framework (NWListener, Bonjour mDNS), CryptoKit (AES-GCM, SHA-256), ScreenCaptureKit, CoreAudio, Vision (VNRecognizeTextRequest), SQLite3 / FTS5, HTML5 Canvas/WebSockets.

## Global Constraints
- Target platform: macOS 14.0+ (Apple Silicon M-Series).
- 100% Offline: zero external cloud endpoints, zero tracking, works on local Wi-Fi / Hotspot.
- Standalone: Each project must have its own Swift Package, automated XCTest test suite, and packaging script (`scripts/package_app.sh`).
- Code style: Pure Swift with strict concurrency compliance, glassmorphic SwiftUI styling with SF Symbols.

---

## Roadmap Overview
1. **Project 1: AirBridge** (Wireless Universal Clipboard & Drop Zone)
2. **Project 2: KeySync** (Virtual Mouse & Keyboard Edge Gliding)
3. **Project 3: AudioTunnel** (Ultra-Low Latency CoreAudio Bridge)
4. **Project 4: QuickRecall** (Local AI Neural OCR Screen Memory)

---

# Phase 1: AirBridge Implementation

### Task 1.1: Project Scaffolding & Core Architecture
**Files:**
- Create: `/Users/panpan/Mac project/AirBridge/Package.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridgeCore/Models/ClipboardItem.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridgeCore/Models/DeviceSession.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Tests/AirBridgeTests/ModelTests.swift`

- [ ] **Step 1: Write failing model serialization tests**
- [ ] **Step 2: Run `swift test` in AirBridge to verify failure**
- [ ] **Step 3: Implement ClipboardItem (Text, URL, Image, File) with SHA-256 hashing and JSON codable**
- [ ] **Step 4: Run `swift test` to verify passing**
- [ ] **Step 5: Commit changes**

---

### Task 1.2: Pasteboard Observer Engine (`ClipboardWatcher`)
**Files:**
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridgeCore/Services/ClipboardWatcher.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Tests/AirBridgeTests/ClipboardWatcherTests.swift`

- [ ] **Step 1: Write test for pasteboard change detection and deduplication**
- [ ] **Step 2: Implement polling observer on `NSPasteboard.general.changeCount` with debounce**
- [ ] **Step 3: Extract string, RTF, PNG image data, and file URLs**
- [ ] **Step 4: Verify test passes with mock pasteboard**
- [ ] **Step 5: Commit changes**

---

### Task 1.3: Security & 4-Digit Pairing Manager (`SecurityManager`)
**Files:**
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridgeCore/Security/SecurityManager.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Tests/AirBridgeTests/SecurityTests.swift`

- [ ] **Step 1: Write tests for PIN generation, timing-safe validation, and session bearer tokens**
- [ ] **Step 2: Implement SecurityManager with CryptoKit AES-GCM support and authorization gates**
- [ ] **Step 3: Run `swift test` to verify zero unauthorized access**
- [ ] **Step 4: Commit changes**

---

### Task 1.4: Embedded HTTP & WebSocket Server (`AirBridgeServer`)
**Files:**
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridgeCore/Services/AirBridgeServer.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridgeCore/Resources/MobileWebPortal.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Tests/AirBridgeTests/ServerTests.swift`

- [ ] **Step 1: Write integration tests for HTTP mobile web delivery and WebSocket sync**
- [ ] **Step 2: Implement NWListener with Bonjour service `_airbridge._tcp`**
- [ ] **Step 3: Implement MobileWebPortal (HTML5/CSS/JS with QR code pairing, 1-click copy, file upload)**
- [ ] **Step 4: Verify full bidirectional text transfer over WebSocket**
- [ ] **Step 5: Commit changes**

---

### Task 1.5: macOS Menu Bar App UI & Packaging
**Files:**
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridge/AirBridgeApp.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridgeCore/Views/MenuBarView.swift`
- Create: `/Users/panpan/Mac project/AirBridge/Sources/AirBridgeCore/Views/DropZoneView.swift`
- Create: `/Users/panpan/Mac project/AirBridge/scripts/package_app.sh`

- [ ] **Step 1: Build MenuBarExtra with QR code generation (CoreImage CIFilter.qrCodeGenerator)**
- [ ] **Step 2: Add Recent Clipboard Feed and Drag-and-Drop file landing zone**
- [ ] **Step 3: Create App bundle, sign ad-hoc, and install to `/Applications/AirBridge.app`**
- [ ] **Step 4: Verify end-to-end launch and Menu Bar icon display**
- [ ] **Step 5: Commit changes**

---

### Task 1.6: Windows Tray Companion Client (`AirBridge-Windows`)
**Files:**
- Create: `/Users/panpan/Mac project/AirBridge/clients/windows/airbridge_tray.py` (or Go/C# single-file)
- Create: `/Users/panpan/Mac project/AirBridge/clients/windows/README.md`

- [ ] **Step 1: Implement Windows clipboard listener and WebSocket client**
- [ ] **Step 2: Add system tray icon with pairing PIN entry and status indicator**
- [ ] **Step 3: Test bidirectional sync with Mac host**
- [ ] **Step 4: Commit changes**

---

# Phase 2: KeySync Implementation (Virtual KVM)

### Task 2.1: Cursor Edge Detection & Event Interception
**Files:**
- Create: `/Users/panpan/Mac project/KeySync/Package.swift`
- Create: `/Users/panpan/Mac project/KeySync/Sources/KeySyncCore/Services/EdgeDetector.swift`
- Create: `/Users/panpan/Mac project/KeySync/Sources/KeySyncCore/Services/EventInterceptor.swift`

- [ ] **Step 1: Implement `CGEventTap` for mouse coordinate tracking along display edges**
- [ ] **Step 2: Implement boundary transition logic and emergency escape hotkey (`Cmd + Esc`)**
- [ ] **Step 3: Unit test event serialization to binary packets**

### Task 2.2: Ultra-Low Latency UDP/TCP Network Transport
**Files:**
- Create: `/Users/panpan/Mac project/KeySync/Sources/KeySyncCore/Network/KeySyncServer.swift`
- Create: `/Users/panpan/Mac project/KeySync/clients/windows/keysync_client.py`

- [ ] **Step 1: Implement sub-millisecond UDP packet stream for mouse delta X/Y and keycodes**
- [ ] **Step 2: Implement Windows `SendInput` receiver with cursor smoothing**

### Task 2.3: Menu Bar App & Display Arrangement UI
**Files:**
- Create: `/Users/panpan/Mac project/KeySync/Sources/KeySyncCore/Views/DisplayArrangerView.swift`
- Create: `/Users/panpan/Mac project/KeySync/scripts/package_app.sh`

- [ ] **Step 1: Build interactive display arranger (drag Windows screen to left/right of Mac)**
- [ ] **Step 2: Package and install `/Applications/KeySync.app`**

---

# Phase 3: AudioTunnel Implementation (Wireless Audio)

### Task 3.1: CoreAudio & ScreenCaptureKit Audio Capture
**Files:**
- Create: `/Users/panpan/Mac project/AudioTunnel/Package.swift`
- Create: `/Users/panpan/Mac project/AudioTunnel/Sources/AudioTunnelCore/Services/AudioCaptureEngine.swift`

- [ ] **Step 1: Capture 48kHz 16-bit stereo system audio samples via ScreenCaptureKit / CoreAudio tap**
- [ ] **Step 2: Buffer and packetize PCM frames with timestamping**

### Task 3.2: Low-Latency Audio Streaming Server & WebAudio Receiver
**Files:**
- Create: `/Users/panpan/Mac project/AudioTunnel/Sources/AudioTunnelCore/Services/AudioStreamServer.swift`
- Create: `/Users/panpan/Mac project/AudioTunnel/Sources/AudioTunnelCore/Resources/WebAudioPlayer.swift`

- [ ] **Step 1: Implement WebSocket audio broadcast with adaptive jitter buffer**
- [ ] **Step 2: Build WebAudio API player (`AudioWorklet`) for instant browser listening**
- [ ] **Step 3: Package and install `/Applications/AudioTunnel.app`**

---

# Phase 4: QuickRecall Implementation (On-Device AI Memory)

### Task 4.1: Screen Sampling & Perceptual Diff Engine
**Files:**
- Create: `/Users/panpan/Mac project/QuickRecall/Package.swift`
- Create: `/Users/panpan/Mac project/QuickRecall/Sources/QuickRecallCore/Services/ScreenSampler.swift`

- [ ] **Step 1: Capture periodic display thumbnails every 5-10s using ScreenCaptureKit**
- [ ] **Step 2: Perceptual hash comparison to discard duplicate static frames**

### Task 4.2: Apple Vision Neural OCR & SQLite FTS5 Indexing
**Files:**
- Create: `/Users/panpan/Mac project/QuickRecall/Sources/QuickRecallCore/Services/NeuralOCREngine.swift`
- Create: `/Users/panpan/Mac project/QuickRecall/Sources/QuickRecallCore/Storage/IndexDatabase.swift`

- [ ] **Step 1: Run `VNRecognizeTextRequest` on Apple Silicon Neural Engine (Thai + English)**
- [ ] **Step 2: Store text tokens and bounding boxes in SQLite with FTS5 virtual tables**

### Task 4.3: Quick Spotlight Search UI & Hotkey Trigger
**Files:**
- Create: `/Users/panpan/Mac project/QuickRecall/Sources/QuickRecallCore/Views/RecallSearchView.swift`
- Create: `/Users/panpan/Mac project/QuickRecall/scripts/package_app.sh`

- [ ] **Step 1: Build floating search bar (`Cmd + Shift + Space`) with instant thumbnail preview**
- [ ] **Step 2: Package and install `/Applications/QuickRecall.app`**
