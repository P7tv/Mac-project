# DeskExtend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS application that creates a hardware-level virtual secondary display (`CGVirtualDisplay`) and streams it over local network or direct cable to a Windows PC browser in real-time (60 FPS, < 30ms latency) without internet or software installation on Windows.

**Architecture:** Standalone Swift Package Manager project inside `DeskExtend/`. Decomposed into CoreGraphics virtual display management (`VirtualDisplayManager`), GPU screen capture (`ScreenCaptureEngine`), embedded zero-dependency HTTP & WebSocket server (`StreamServer`), embedded HTML5 Canvas receiver, and a SwiftUI glassmorphic dashboard.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, CoreGraphics (`CGVirtualDisplay`), Network.framework (`NWListener`, `NWConnection`), ImageIO.

## Global Constraints
- Target platform: macOS 14.0+
- Must be located completely in the `DeskExtend/` subfolder alongside `DropMorph/`
- Zero third-party dependencies (100% native Apple SDKs)
- 100% offline capability: Zero external internet or CDN calls
- Zero installation required on the Windows receiver (standard browser F11 fullscreen)

---

### Task 1: Scaffolding & SPM Setup

**Files:**
- Create: `DeskExtend/Package.swift`
- Create: `DeskExtend/Sources/DeskExtend/DeskExtendApp.swift`
- Create: `DeskExtend/Sources/DeskExtendCore/DeskExtendCore.swift`
- Create: `DeskExtend/Tests/DeskExtendTests/DeskExtendTests.swift`

**Interfaces:**
- Produces: Executable `DeskExtend` and Library `DeskExtendCore`

- [ ] **Step 1: Write Package.swift**
- [ ] **Step 2: Write entry point and core info**
- [ ] **Step 3: Run swift build & swift test**
- [ ] **Step 4: Commit**

---

### Task 2: Virtual Display Engine & Tests

**Files:**
- Create: `DeskExtend/Sources/DeskExtendCore/Models/DisplayConfig.swift`
- Create: `DeskExtend/Sources/DeskExtendCore/Services/VirtualDisplayManager.swift`
- Create: `DeskExtend/Tests/DeskExtendTests/VirtualDisplayTests.swift`

**Interfaces:**
- Produces:
  - `struct DisplayConfig`: resolution (1920x1080, 2560x1440, 1280x720), refreshRate (60), hiDPI
  - `class VirtualDisplayManager`: `start(config: DisplayConfig) -> CGDirectDisplayID?`, `stop()`, `activeDisplayID: CGDirectDisplayID?`

- [ ] **Step 1: Write DisplayConfig model**
- [ ] **Step 2: Write unit test for VirtualDisplayManager**
- [ ] **Step 3: Implement VirtualDisplayManager using CGVirtualDisplay**
- [ ] **Step 4: Run test to verify virtual display creation & teardown**
- [ ] **Step 5: Commit**

---

### Task 3: Screen Capture & Frame Compression Engine

**Files:**
- Create: `DeskExtend/Sources/DeskExtendCore/Services/ScreenCaptureEngine.swift`

**Interfaces:**
- Produces:
  - `class ScreenCaptureEngine`: `startCapture(displayID: CGDirectDisplayID, fps: Int, quality: Double, onFrame: @escaping (Data) -> Void)`
  - `stopCapture()`

- [ ] **Step 1: Implement ScreenCaptureEngine using CGDisplayStream / CoreGraphics**
- [ ] **Step 2: Implement frame downsampling and hardware JPEG compression**
- [ ] **Step 3: Implement frame dropping queue to prevent backpressure latency**
- [ ] **Step 4: Run swift test & build**
- [ ] **Step 5: Commit**

---

### Task 4: Embedded Offline HTTP & WebSocket Server

**Files:**
- Create: `DeskExtend/Sources/DeskExtendCore/Services/StreamServer.swift`
- Create: `DeskExtend/Sources/DeskExtendCore/Services/NetworkInterfaceHelper.swift`
- Create: `DeskExtend/Sources/DeskExtendCore/Resources/WebReceiver.swift`

**Interfaces:**
- Produces:
  - `class StreamServer`: `start(port: UInt16 = 8080) throws`, `stop()`, `broadcastFrame(data: Data)`, `connectedClientsCount: Int`
  - `struct NetworkInterfaceHelper`: `getLocalIPAddresses() -> [NetworkAddress]` (Wi-Fi, Direct Cable link-local 169.254.x.x, Localhost)
  - `WebReceiver.html`: Self-contained HTML5 + JS canvas receiver

- [ ] **Step 1: Write NetworkInterfaceHelper for IP detection**
- [ ] **Step 2: Write self-contained WebReceiver HTML/JS in WebReceiver.swift**
- [ ] **Step 3: Implement StreamServer using NWListener (HTTP + WebSocket handshake & binary framing)**
- [ ] **Step 4: Run swift test & build**
- [ ] **Step 5: Commit**

---

### Task 5: State Management & ViewModel

**Files:**
- Create: `DeskExtend/Sources/DeskExtendCore/ViewModels/DeskExtendViewModel.swift`

**Interfaces:**
- Produces:
  - `@MainActor class DeskExtendViewModel: ObservableObject`
  - `@Published var isStreaming: Bool`
  - `@Published var selectedResolution: DisplayResolution`
  - `@Published var quality: Double`
  - `@Published var localIPs: [NetworkAddress]`
  - `@Published var connectedClients: Int`
  - `@Published var latestPreviewImage: NSImage?`
  - `func startStreaming()`, `func stopStreaming()`, `func openSystemDisplaySettings()`

- [ ] **Step 1: Implement DeskExtendViewModel wiring VirtualDisplay, CaptureEngine, and StreamServer**
- [ ] **Step 2: Run swift build**
- [ ] **Step 3: Commit**

---

### Task 6: Glassmorphic UI Dashboard

**Files:**
- Create: `DeskExtend/Sources/DeskExtendCore/Views/DashboardView.swift`
- Create: `DeskExtend/Sources/DeskExtendCore/Views/ConnectionCardView.swift`
- Create: `DeskExtend/Sources/DeskExtendCore/Views/DisplaySettingsBar.swift`
- Modify: `DeskExtend/Sources/DeskExtend/DeskExtendApp.swift`

**Interfaces:**
- Produces:
  - Complete native macOS UI with live preview, connection links, resolution pickers, and status indicators.

- [ ] **Step 1: Implement ConnectionCardView (shows URL, Copy button, IP type: Wi-Fi vs Direct Cable)**
- [ ] **Step 2: Implement DisplaySettingsBar (Resolution, Quality, FPS)**
- [ ] **Step 3: Implement DashboardView with live screen preview and Start/Stop toggle**
- [ ] **Step 4: Update DeskExtendApp entry point**
- [ ] **Step 5: Run swift build**
- [ ] **Step 6: Commit**

---

### Task 7: App Bundle Packaging & Installation

**Files:**
- Create: `DeskExtend/Resources/Info.plist`
- Create: `DeskExtend/scripts/package_app.sh`
- Create: `DeskExtend/README.md`

- [ ] **Step 1: Generate high-res AppIcon for DeskExtend**
- [ ] **Step 2: Write package_app.sh script**
- [ ] **Step 3: Compile release binary, package into DeskExtend.app, and install to /Applications**
- [ ] **Step 4: Run and verify live streaming**
- [ ] **Step 5: Commit & documentation**
