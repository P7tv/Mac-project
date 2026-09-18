# KeySync Standalone App & Hybrid Event Interception Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform KeySync into a full macOS desktop application with a modern `DashboardView` window, official `AppIcon.icns`, and an active `CGEventTap` event interception engine that securely and seamlessly shares mouse (moves, clicks, scrolls) and keyboard typing with Windows PC.

**Architecture:** Dual-interface app (`WindowGroup` + `MenuBarExtra`). Active event tap (`CGEvent.tapCreate`) intercepts and suppresses mouse and keyboard events while cursor is in remote mode, streaming `InputEvent` packets over low-latency TCP to Windows. Emergency release via `Cmd + Esc` or edge return.

**Tech Stack:** Swift 6 / SwiftUI (macOS 14.0+), CoreGraphics, ApplicationServices, Network.framework, Python 3 / pynput.

## Global Constraints

- macOS 14.0+ deployment target.
- Zero cloud / 100% offline local network operation.
- Standard macOS squircle icon (`AppIcon.icns`) matching macOS design guidelines.
- Accessibility permission handling with smooth inline UX.

---

### Task 1: App Icon Generation & Asset Creation

**Files:**
- Create: `KeySync/Resources/AppIcon.icns`
- Modify: `KeySync/Resources/Info.plist`

**Interfaces:**
- Produces: `KeySync/Resources/AppIcon.icns` with 16x16, 32x32, 128x128, 256x256, 512x512, and @2x resolutions.
- Produces: `Info.plist` with `CFBundleIconFile = AppIcon` and `LSUIElement = false`.

- [ ] **Step 1: Generate high-resolution master icon and build iconset**

Create a Python asset generator script using CoreGraphics/PIL or draw a high-resolution 1024x1024 image of the KeySync icon (obsidian metallic rounded squircle with glowing indigo/purple keycap and neon cursor trail), resize to standard iconset resolutions, and compile with `iconutil -c icns`.

- [ ] **Step 2: Update Info.plist**

Set `<key>CFBundleIconFile</key><string>AppIcon</string>` and `<key>LSUIElement</key><false/>`.

- [ ] **Step 3: Verify icon bundle**

Verify file exists: `file KeySync/Resources/AppIcon.icns`.

- [ ] **Step 4: Commit**

```bash
git add KeySync/Resources/AppIcon.icns KeySync/Resources/Info.plist
git commit -m "feat(KeySync): generate AppIcon.icns and configure regular app execution"
```

---

### Task 2: Core Event Interception Engine with CGEventTap

**Files:**
- Modify: `KeySync/Sources/KeySyncCore/Services/EventInterceptor.swift`
- Modify: `KeySync/Sources/KeySyncCore/ViewModels/KeySyncViewModel.swift`
- Create: `KeySync/Tests/KeySyncTests/EventInterceptorTests.swift`

**Interfaces:**
- Produces: Active event tap capturing:
  - Mouse moves, Left/Right/Middle clicks (down/up)
  - Scroll wheel (vertical & horizontal)
  - Key down, Key up, and modifier flags
- Produces: Cursor edge parking via `CGWarpMouseCursorPosition` when `isControllingRemote == true`.
- Produces: Accessibility permission preflight (`AXIsProcessTrusted()`).

- [ ] **Step 1: Write unit tests for EventInterceptor and EdgeDetector**

Create `KeySync/Tests/KeySyncTests/EventInterceptorTests.swift` testing event creation, edge transitions, and panic release.

- [ ] **Step 2: Run test to verify initial status**

Run: `swift test --package-path KeySync --filter EventInterceptorTests`

- [ ] **Step 3: Implement CGEventTap in EventInterceptor.swift**

Upgrade `EventInterceptor.swift` to use `CGEvent.tapCreate` for complete event suppression and event forwarding, and edge warping to park cursor on Mac border.

- [ ] **Step 4: Update KeySyncViewModel.swift with Accessibility Check**

Add `@Published public var hasAccessibilityPermission: Bool`, `checkPermissions()`, `requestAccessibilityPermission()`, and bind event interceptor callbacks to `KeySyncServer`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path KeySync`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add KeySync/Sources/KeySyncCore/Services/EventInterceptor.swift KeySync/Sources/KeySyncCore/ViewModels/KeySyncViewModel.swift KeySync/Tests/KeySyncTests/EventInterceptorTests.swift
git commit -m "feat(KeySync): implement CGEventTap event interception and accessibility checks"
```

---

### Task 3: Standalone macOS App Window (`DashboardView`) & App Lifecycle

**Files:**
- Create: `KeySync/Sources/KeySyncCore/Views/DashboardView.swift`
- Modify: `KeySync/Sources/KeySyncCore/Views/KeySyncMenuBarView.swift`
- Modify: `KeySync/Sources/KeySync/KeySyncApp.swift`

**Interfaces:**
- Produces: Standalone macOS app window (`DashboardView`), 580x640 with frosted glassmorphism:
  - Header with app icon and live client status badge.
  - Accessibility permission warning banner with direct button.
  - Interactive screen layout switcher (Left, Right, Top, Bottom) with dual monitor visualizer.
  - Connection card with Local IP, Port, QR Code, and copyable client command.
  - Live Event Inspector telemetry card showing the last intercepted event.
  - Emergency Panic Release button (`Esc`).
- Produces: `KeySyncApp.swift` `WindowGroup(id: "main")` and menu bar "Open KeySync App" bridge.

- [ ] **Step 1: Create DashboardView.swift**

Implement SwiftUI view with all sections, modern typography, gradient styling, and reactive bindings to `KeySyncViewModel`.

- [ ] **Step 2: Update KeySyncMenuBarView.swift**

Add "Open KeySync App" button that triggers window activation.

- [ ] **Step 3: Update KeySyncApp.swift**

Add `WindowGroup(id: "main")` housing `DashboardView(viewModel: viewModel)`, `.windowStyle(.hiddenTitleBar)`, and onAppear configure `NSApp.setActivationPolicy(.regular)`.

- [ ] **Step 4: Build and verify compilation**

Run: `swift build --package-path KeySync`  
Expected: Build complete.

- [ ] **Step 5: Commit**

```bash
git add KeySync/Sources/KeySyncCore/Views/DashboardView.swift KeySync/Sources/KeySyncCore/Views/KeySyncMenuBarView.swift KeySync/Sources/KeySync/KeySyncApp.swift
git commit -m "feat(KeySync): add standalone macOS DashboardView window and app shell"
```

---

### Task 4: Windows Client Optimization & App Packaging

**Files:**
- Modify: `KeySync/clients/windows/keysync_client.py`
- Modify: `KeySync/scripts/package_app.sh`

**Interfaces:**
- Produces: Upgraded `keysync_client.py` with `TCP_NODELAY`, full click/scroll/keyboard dispatch, auto-reconnect.
- Produces: Packaged `/Applications/KeySync.app` containing `AppIcon.icns`.

- [ ] **Step 1: Upgrade keysync_client.py**

Implement mouse clicks (left, right, middle), mouse scroll, and keystrokes using `pynput` / `ctypes.windll.user32.SendInput` with `TCP_NODELAY`.

- [ ] **Step 2: Update package_app.sh**

Ensure `package_app.sh` copies `AppIcon.icns` to `Resources/AppIcon.icns` in the bundle, signs with `codesign`, and copies to `/Applications/KeySync.app`.

- [ ] **Step 3: Run package_app.sh and verify bundle**

Run: `bash KeySync/scripts/package_app.sh`  
Expected: Successfully packaged and installed.

- [ ] **Step 4: Commit**

```bash
git add KeySync/clients/windows/keysync_client.py KeySync/scripts/package_app.sh
git commit -m "feat(KeySync): optimize Windows receiver and finalize app packaging"
```

---

### Task 5: AudioTunnel Icon Bonus & Final Suite Verification

**Files:**
- Create: `AudioTunnel/Resources/AppIcon.icns`
- Modify: `AudioTunnel/Resources/Info.plist`
- Modify: `AudioTunnel/scripts/package_app.sh`

**Interfaces:**
- Produces: Official `AudioTunnel/Resources/AppIcon.icns` (cyan/blue headphones theme) and re-packages `/Applications/AudioTunnel.app`.

- [ ] **Step 1: Generate AudioTunnel AppIcon.icns**

Generate matching 1024x1024 macOS squircle icon for AudioTunnel and compile to `AudioTunnel/Resources/AppIcon.icns`.

- [ ] **Step 2: Update AudioTunnel Info.plist and package_app.sh**

Set `<key>CFBundleIconFile</key><string>AppIcon</string>` and run `bash AudioTunnel/scripts/package_app.sh`.

- [ ] **Step 3: Run all test suites across the project**

Run: `swift test --package-path KeySync` and `swift test --package-path AudioTunnel`.

- [ ] **Step 4: Commit**

```bash
git add AudioTunnel/Resources/AppIcon.icns AudioTunnel/Resources/Info.plist AudioTunnel/scripts/package_app.sh
git commit -m "feat(AudioTunnel): add official AppIcon.icns and re-package app"
```
