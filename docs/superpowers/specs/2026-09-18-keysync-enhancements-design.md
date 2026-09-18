# KeySync - Universal Keyboard & Mouse Sharing (Hybrid KVM & Standalone macOS App)

**Status:** Approved  
**Date:** 2026-09-18  
**Platform:** macOS 14.0+ (Apple Silicon & Intel)  
**Target Path:** `KeySync/` inside workspace  

---

## 1. Overview & Objectives

**KeySync** allows a single mouse and keyboard connected to a Mac to seamlessly control a secondary Windows PC over local Wi-Fi or direct cable, functioning like Apple Universal Control for Windows.

This enhancement addresses four critical requirements:
1. **Standalone macOS App UI (`DashboardView.swift`)**: Transform KeySync into a full desktop application featuring a modern glassmorphic dashboard window (matching `DeskExtend`, `AudioTunnel`, and `DropMorph`), Dock icon support (`LSUIElement = false`), interactive display layout arrangement (Left/Right/Top/Bottom), and live event telemetry.
2. **System-Level Event Interception (`CGEventTap`)**: Replace passive event monitoring with active `CGEventTap` interception. When the cursor transitions to Windows:
   - Locks/parks the Mac mouse cursor at the screen edge (`CGWarpMouseCursorPosition`) to prevent unintended interaction with Mac applications.
   - Captures and forwards all mouse movement deltas, mouse clicks (Left, Right, Middle down/up), scroll wheel events, and keyboard keystrokes (key down/up and modifiers).
   - Suppresses events from being processed by macOS while controlling the remote PC.
3. **Hybrid Interaction Model**:
   - **Seamless Edge Gliding**: Cursor naturally glides across the configured screen edge to enter the PC and glides back to return.
   - **Emergency / Hotkey Switcher**: `Cmd + Esc` (or panic release button) immediately returns control to Mac.
4. **App Icon & Packaging**: Generate a professional macOS Big Sur / Sonoma squircle `AppIcon.icns` for KeySync and update `package_app.sh` to install `/Applications/KeySync.app`.
5. **Windows Client Optimization (`keysync_client.py`)**: Support full mouse clicks, scroll, and keystroke injection with `TCP_NODELAY` and auto-reconnection.

---

## 2. System Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              macOS Host App                                │
│                                                                            │
│  ┌───────────────────────┐             ┌────────────────────────────────┐  │
│  │     DashboardView     │             │          MenuBarExtra          │  │
│  │  (macOS App Window)   │◄───────────►│       (Status Bar Icon)        │  │
│  └───────────┬───────────┘             └────────────────┬───────────────┘  │
│              │                                          │                  │
│              ▼                                          ▼                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                          KeySyncViewModel                            │  │
│  │    (Accessibility Status, Edge Selector, Event Monitor, Panic Esc)   │  │
│  └───────────────┬──────────────────────────────────────▲───────────────┘  │
│                  │                                      │                  │
│                  ▼                                      │                  │
│  ┌───────────────────────────────┐     ┌────────────────┴───────────────┐  │
│  │       EventInterceptor        │     │         KeySyncServer          │  │
│  │   (CGEventTap & Edge Warper)  │────►│   (Low-Latency TCP Port 6060)  │  │
│  │   Mouse Clicks, Keys, Scroll  │     │   TCP_NODELAY Input Dispatch   │  │
│  └───────────────────────────────┘     └────────────────┬───────────────┘  │
└─────────────────────────────────────────────────────────┼──────────────────┘
                                                          │
                       Local Network (LAN / Wi-Fi)        │
                                                          ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                        Windows PC (Target Device)                          │
│                                                                            │
│  [keysync_client.py]                                                       │
│   ├── TCP Socket Client (TCP_NODELAY)                                      │
│   ├── InputEvent Deserializer (JSON / binary payload)                      │
│   ├── Mouse Pointer Interpolation (relative dx, dy)                        │
│   ├── Mouse Clicks & Wheel Injection (pynput / SendInput)                  │
│   └── Keyboard Keystroke Dispatch (Virtual Keys & Modifiers)               │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Component Specifications

### 3.1 macOS Standalone App Window (`DashboardView.swift` & `KeySyncApp.swift`)
- **Window Specifications**:
  - Size: 580x640, `.windowStyle(.hiddenTitleBar)`, native vibrancy glassmorphic material.
  - `NSApp.setActivationPolicy(.regular)` on dashboard launch to enable Dock icon and application switcher.
- **UI Sections**:
  1. **Header Bar**: App icon, gradient branding, Active/Idle status badge, client connection status.
  2. **Accessibility Permission Warning Card**:
     - Preflights `AXIsProcessTrusted()`.
     - If permission is missing, shows an actionable warning banner with a button opening `System Settings -> Privacy & Security -> Accessibility`.
  3. **Interactive Screen Arrangement Card**:
     - Visual mockup showing Mac display and Windows display side-by-side.
     - 4 Edge buttons (Left, Right, Top, Bottom) to change screen layout dynamically.
  4. **Connection & Instructions Card**:
     - Local IP address, Port 6060, QR Code.
     - One-click "Copy Windows Command" (`python keysync_client.py <mac-ip>`).
  5. **Live Event Monitor & Control State**:
     - Shows current controlling state: "Controlling Mac" vs "Controlling Windows".
     - Real-time indicator displaying the last intercepted event (e.g. `🖱️ Left Click`, `📜 Scroll Up`, `⌨️ Key: Space`).
  6. **Emergency Release Button**:
     - Big prominent button to immediately force cursor release back to Mac, plus shortcut hint (`Cmd + Esc`).

### 3.2 System-Level Event Interception (`EventInterceptor.swift`)
- **Event Tap Configuration**:
  - Creates a Mach port event tap via `CGEvent.tapCreate` for events:
    - `.mouseMoved`, `.leftMouseDown`, `.leftMouseUp`, `.rightMouseDown`, `.rightMouseUp`, `.otherMouseDown`, `.otherMouseUp`
    - `.scrollWheel`
    - `.keyDown`, `.keyUp`, `.flagsChanged`
- **Control States**:
  - `isControllingRemote == false`:
    - Checks cursor location against target screen edge.
    - If cursor hits boundary (with a small overshoot threshold) and client is connected, triggers transition:
      - Sets `isControllingRemote = true`.
      - Warps cursor to edge boundary (`CGWarpMouseCursorPosition`).
  - `isControllingRemote == true`:
    - Generates corresponding `InputEvent` (move, click, scroll, key).
    - Dispatches event to `KeySyncServer`.
    - Returns `nil` to suppress the event from propagating to macOS applications.
    - If mouse movement delta pulls back from edge, or emergency hotkey (`Cmd + Esc` / `Esc`) is pressed:
      - Sets `isControllingRemote = false`.
      - Warps cursor slightly inward so it doesn't immediately re-trigger edge gliding.

### 3.3 App Icon Generation (`AppIcon.icns`)
- Create a 1024x1024 master icon matching the macOS Big Sur/Sonoma squircle style:
  - Deep obsidian & indigo metallic background.
  - Glowing violet/purple cyber keyboard keycap and sleek cursor glide trail.
- Build an `.iconset` with all standard macOS resolutions (16x16 up to 512x512@2x) and compile into `KeySync/Resources/AppIcon.icns` via `iconutil`.
- Update `Info.plist` with `<key>CFBundleIconFile</key><string>AppIcon</string>`.

### 3.4 Windows Client (`keysync_client.py`)
- Python 3 client with `pynput` / `pyautogui` / Windows `SendInput`.
- Enables `TCP_NODELAY`.
- Handles mouse relative movement, button down/up, scroll wheel, and key codes.
- Auto-reconnect loop on network drop.

---

## 4. Verification Plan

1. **Compilation & Build**:
   - `swift build --package-path KeySync` passes without error.
   - Run existing and new test suites: `swift test --package-path KeySync`.
2. **App Window & Menu Bar**:
   - Launch app, verify `DashboardView` opens as standalone window with Dock icon and app icon.
   - Verify Accessibility check triggers and reflects permissions.
   - Verify screen edge arrangement switcher.
3. **Event Interception Verification**:
   - Verify mouse, click, scroll, and keyboard events are properly captured.
   - Verify `Cmd + Esc` panic release returns control instantly.
4. **App Packaging**:
   - Run `bash KeySync/scripts/package_app.sh`, verify `/Applications/KeySync.app` exists and contains `AppIcon.icns`.
