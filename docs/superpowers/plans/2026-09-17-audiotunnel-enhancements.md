# AudioTunnel Standalone macOS App & Low-Latency Audio Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform AudioTunnel into a full macOS standalone desktop app with a dedicated `DashboardView` window and overhaul the audio streaming engine with an `AudioWorklet` + lock-free ring buffer for ultra-low latency, jitter-free playback.

**Architecture:** A dual-interface macOS app (`WindowGroup` + `MenuBarExtra`) powered by `AudioTunnelViewModel`. Audio is captured via `ScreenCaptureKit` or `AVAudioEngine` at 48kHz 16-bit PCM and streamed over WebSockets/TCP. Web clients play audio through a zero-GC `AudioWorklet` circular ring buffer with adaptive drift correction and wake lock.

**Tech Stack:** Swift 6 / SwiftUI (macOS 14.0+), ScreenCaptureKit, AVFoundation, Network.framework, WebAudio API (AudioWorklet), Python 3.

## Global Constraints

- macOS 14.0+ deployment target.
- Zero cloud / 100% offline local network operation.
- No external third-party CocoaPods or SPM packages (pure native Swift & standard Web APIs).
- Seamless coexistence of standalone App Window (`DashboardView`) and menu bar icon (`MenuBarExtra`).

---

### Task 1: Core Models & Audio Latency Presets

**Files:**
- Modify: `AudioTunnel/Sources/AudioTunnelCore/Models/AudioConfig.swift`
- Create: `AudioTunnel/Tests/AudioTunnelTests/AudioConfigTests.swift`

**Interfaces:**
- Produces: `enum LatencyProfile: String, CaseIterable, Identifiable, Sendable` with properties `targetBufferMs: Double`, `targetFrames: Int`, `label: String`.

- [ ] **Step 1: Write the failing unit test**

Create `AudioTunnel/Tests/AudioTunnelTests/AudioConfigTests.swift` testing `LatencyProfile` values and frame calculations.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path AudioTunnel --filter AudioConfigTests`  
Expected: FAIL due to missing `LatencyProfile`.

- [ ] **Step 3: Implement LatencyProfile in AudioConfig.swift**

Add `LatencyProfile` to `AudioConfig.swift` with `.ultraLow` (~25ms), `.balanced` (~60ms), and `.smooth` (~120ms).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path AudioTunnel --filter AudioConfigTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AudioTunnel/Sources/AudioTunnelCore/Models/AudioConfig.swift AudioTunnel/Tests/AudioTunnelTests/AudioConfigTests.swift
git commit -m "feat(AudioTunnel): add LatencyProfile model and config tests"
```

---

### Task 2: High-Performance AudioWorklet & Web Player Overhaul

**Files:**
- Modify: `AudioTunnel/Sources/AudioTunnelCore/Resources/WebAudioPlayer.swift`

**Interfaces:**
- Consumes: `LatencyProfile` configurations and 48kHz WebSocket audio stream.
- Produces: Updated `WebAudioPlayer.htmlContent` embedding an inline `AudioWorkletProcessor` (`"pcm-player-worklet"`), a circular ring buffer, drift correction, WakeLock API, and UI controls for latency profiles.

- [ ] **Step 1: Write inline AudioWorkletProcessor script and Blob loader**

In `WebAudioPlayer.swift`, replace `createBufferSource()` per chunk with an inline Worklet code loaded via `URL.createObjectURL(new Blob([...], { type: 'application/javascript' }))`.

- [ ] **Step 2: Implement lock-free Float32 circular ring buffer and dynamic drift correction**

Worklet reads 128 frames per process quantum. WebSocket pushes PCM Int16 -> Float32 into ring buffer. Worklet applies dynamic micro-resampling (skipping/interpolating 1 sample when buffer exceeds watermark) to hold steady latency.

- [ ] **Step 3: Add Screen Wake Lock API and Latency Profile buttons in UI**

Add `navigator.wakeLock.request('screen')` during playback. Add Latency selector buttons (⚡ Ultra-Low 25ms, ⚖️ Balanced 60ms, 🛡️ Smooth 120ms) and live buffer health monitor in the Web Player interface.

- [ ] **Step 4: Run tests to verify existing server tests still pass**

Run: `swift test --package-path AudioTunnel`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AudioTunnel/Sources/AudioTunnelCore/Resources/WebAudioPlayer.swift
git commit -m "feat(AudioTunnel): upgrade Web Player to AudioWorklet with adaptive ring buffer"
```

---

### Task 3: Standalone macOS App Window (`DashboardView`) & App Shell

**Files:**
- Create: `AudioTunnel/Sources/AudioTunnelCore/Views/DashboardView.swift`
- Modify: `AudioTunnel/Sources/AudioTunnelCore/ViewModels/AudioTunnelViewModel.swift`
- Modify: `AudioTunnel/Sources/AudioTunnelCore/Views/AudioTunnelMenuBarView.swift`
- Modify: `AudioTunnel/Sources/AudioTunnel/AudioTunnelApp.swift`

**Interfaces:**
- Consumes: `AudioTunnelViewModel`, `QRCodeHelper`, `LatencyProfile`.
- Produces: Standalone macOS app window (`DashboardView`), regular activation policy (Dock icon), permission inspection, and MenuBarExtra bridge.

- [ ] **Step 1: Enhance AudioTunnelViewModel**

Add permission check methods for Screen Recording (`CGPreflightScreenCaptureAccess()`, `CGRequestScreenCaptureAccess()`) and Microphone (`AVAudioApplication.shared.recordPermission`), latency profile property, and uptime tracking timer.

- [ ] **Step 2: Create DashboardView.swift**

Create a modern glassmorphic SwiftUI dashboard view (580x620) containing:
1. Header bar with branding, live status capsule, and listener count.
2. Permission warning card (if screen/mic access is missing) with a direct button to macOS System Settings.
3. Master broadcasting card with live RMS volume meter bar and Start/Stop toggle.
4. Audio source mode switcher (System Audio, Microphone, Test Tone).
5. Latency profile switcher (Ultra-Low, Balanced, Smooth).
6. Local IP & QR Code card with Copy URL and Open Browser buttons.
7. Telemetry footer with port, uptime, and zero-cloud indicator.

- [ ] **Step 3: Update AudioTunnelMenuBarView**

Add a prominent button: "Open Dashboard Window" that calls the environment `openWindow(id: "main")` and activates `NSApp`.

- [ ] **Step 4: Update AudioTunnelApp.swift**

Add `WindowGroup(id: "main")` housing `DashboardView(viewModel: viewModel)`, `.windowStyle(.hiddenTitleBar)`, and onAppear configure `NSApp.setActivationPolicy(.regular)`.

- [ ] **Step 5: Build and verify**

Run: `swift build --package-path AudioTunnel`  
Expected: Build successfully.

- [ ] **Step 6: Commit**

```bash
git add AudioTunnel/Sources/AudioTunnelCore/Views/DashboardView.swift AudioTunnel/Sources/AudioTunnelCore/ViewModels/AudioTunnelViewModel.swift AudioTunnel/Sources/AudioTunnelCore/Views/AudioTunnelMenuBarView.swift AudioTunnel/Sources/AudioTunnel/AudioTunnelApp.swift
git commit -m "feat(AudioTunnel): add standalone macOS DashboardView window and app lifecycle"
```

---

### Task 4: Windows Python Client Optimization & App Packaging

**Files:**
- Modify: `AudioTunnel/clients/windows/audiotunnel_receiver.py`
- Modify: `AudioTunnel/Resources/Info.plist`
- Modify: `AudioTunnel/scripts/package_app.sh`

**Interfaces:**
- Produces: Low-latency Python client with `TCP_NODELAY`, packaged `AudioTunnel.app` with proper bundle info and Dock icon support.

- [ ] **Step 1: Optimize audiotunnel_receiver.py**

Set `s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)` and use a non-blocking queue ring buffer with PyAudio / sounddevice stream for minimal delay.

- [ ] **Step 2: Update Info.plist & package_app.sh**

Configure `Info.plist` to allow normal app execution (`LSUIElement` false or omitted when running as full app), bundle identifier `com.audiotunnel.app`, and ensure `package_app.sh` produces an up-to-date `.app` bundle.

- [ ] **Step 3: Run package_app.sh and verify bundle**

Run: `bash AudioTunnel/scripts/package_app.sh`  
Expected: `AudioTunnel.app` packaged successfully.

- [ ] **Step 4: Commit**

```bash
git add AudioTunnel/clients/windows/audiotunnel_receiver.py AudioTunnel/Resources/Info.plist AudioTunnel/scripts/package_app.sh
git commit -m "feat(AudioTunnel): optimize Windows receiver and update app packaging"
```

---

### Task 5: End-to-End Verification & Walkthrough

- [ ] **Step 1: Run complete test suite**

Run: `swift test --package-path AudioTunnel`

- [ ] **Step 2: Launch and verify standalone app**

Run the compiled executable or inspect app startup and endpoints (`http://127.0.0.1:7070` and `/api/status`).

- [ ] **Step 3: Update documentation & create walkthrough**
