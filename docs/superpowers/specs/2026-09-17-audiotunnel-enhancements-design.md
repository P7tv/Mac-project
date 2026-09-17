# AudioTunnel - Standalone macOS Dashboard App & Low-Latency Audio Engine

**Status:** Approved  
**Date:** 2026-09-17  
**Platform:** macOS 14.0+ (Apple Silicon & Intel)  
**Target Path:** `AudioTunnel/` inside workspace  

---

## 1. Overview & Objectives

**AudioTunnel** is an ultra-low latency wireless audio bridge that broadcasts macOS system audio, microphone input, or audio streams to any browser or native client on the local network (PC, iPhone, Android, Linux).

This enhancement addresses two core user requirements:
1. **Standalone macOS App UI**: Transform AudioTunnel from a menu-bar-only utility into a full macOS desktop application featuring a dedicated modern glassmorphism `DashboardView` window (matching the design language of `DeskExtend` and `DropMorph`), complete with Dock icon support, permissions status handling, audio visualizers, and stream telemetry, while retaining the convenient `MenuBarExtra` companion.
2. **Audio Performance & Latency Optimization**: Completely overhaul the receiver playback pipeline:
   - Eliminate audio clicks, pops, and garbage collection (GC) stutter by replacing per-chunk `createBufferSource()` with an **`AudioWorklet` + Circular RingBuffer** architecture.
   - Eliminate clock drift latency accumulation with **Adaptive Jitter Buffer & Dynamic Drift Correction** (micro-resampling/playback rate scaling).
   - Provide user-selectable **Latency Profiles** (Ultra-Low ~25ms, Balanced ~60ms, Safe/Smooth ~120ms).
   - Include Screen Wake Lock support on mobile devices.
   - Enhance the Windows Python client (`audiotunnel_receiver.py`) with low-latency socket options (`TCP_NODELAY`) and ring buffer queuing.

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
│  │                        AudioTunnelViewModel                          │  │
│  │     (Source Switcher, Volume RMS, Listeners, Network IP, QR)         │  │
│  └───────────────┬──────────────────────────────────────▲───────────────┘  │
│                  │                                      │                  │
│                  ▼                                      │                  │
│  ┌───────────────────────────────┐     ┌────────────────┴───────────────┐  │
│  │      AudioCaptureEngine       │     │       AudioStreamServer        │  │
│  │ (ScreenCaptureKit / CoreAudio)│────►│  (HTTP + WebSocket Port 7070)  │  │
│  │  48kHz 16-bit Stereo PCM      │     │  Broadcast to WS & Raw TCP     │  │
│  └───────────────────────────────┘     └────────────────┬───────────────┘  │
└─────────────────────────────────────────────────────────┼──────────────────┘
                                                          │
                       Local Network (LAN / Wi-Fi)        │
                                                          ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                           Receivers (Clients)                              │
│                                                                            │
│  [Web Player] (Safari, Chrome on iPhone / Android / PC)                    │
│   ├── WebSocket Binary Stream (48kHz PCM)                                  │
│   ├── Lock-Free Circular RingBuffer                                        │
│   ├── AudioWorkletProcessor (Hardware-clock accurate sample pull)          │
│   ├── Adaptive Jitter Buffer & Micro-Drift Correction                      │
│   └── Screen Wake Lock API                                                 │
│                                                                            │
│  [Native Client] (Windows / Python `audiotunnel_receiver.py`)              │
│   ├── TCP Stream with TCP_NODELAY                                          │
│   └── Threaded RingBuffer with non-blocking audio sink                     │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Component Specifications

### 3.1 macOS Standalone App Window (`DashboardView.swift` & `AudioTunnelApp.swift`)
- **App Lifecycle & Window Management**:
  - `AudioTunnelApp.swift` defines a `WindowGroup(id: "main")` with `.windowStyle(.hiddenTitleBar)` and default size `580x620`.
  - When the dashboard window appears, dynamically configure `NSApp.setActivationPolicy(.regular)` so AudioTunnel appears in the macOS Dock and Cmd+Tab app switcher.
  - When opened from the menu bar, bring the dashboard window to front using `openWindow(id: "main")` and `NSApp.activate(ignoringOtherApps: true)`.
- **UI Sections in `DashboardView`**:
  1. **Header Bar**: App logo, gradient branding, Active/Stopped status badge, live connected listener count.
  2. **Permissions Banner**: Checks Screen Recording and Microphone permissions. If missing, displays an inline actionable banner with a button opening macOS System Settings directly.
  3. **Master Control Card**:
     - Large Play/Stop Broadcast toggle with smooth gradient animations.
     - Live stereo volume meter (RMS DB gauge with color gradient and numeric percentage).
     - Source mode selector: System Audio (ScreenCaptureKit), Microphone (AVAudioEngine), Test Generator (Sine Wave 440Hz).
  4. **Performance & Latency Mode Selector**:
     - Presets: Ultra-Low Latency (~25ms), Balanced (~60ms), Smooth Wi-Fi (~120ms).
  5. **Network Broadcast & Sharing Card**:
     - Prominently displays Local IP and Web Player URL (`http://<mac-ip>:7070`).
     - QR Code generator view for instant mobile camera pairing.
     - Buttons to "Copy Link" and "Open in Browser".
  6. **Stream Telemetry & Footer**:
     - Connected listeners, Uptime counter, Port status, Zero-cloud badge.

### 3.2 MenuBar Companion (`AudioTunnelMenuBarView.swift`)
- Quick access popover from macOS menu bar.
- Shows current status, quick Start/Stop broadcasting toggle, source switcher, volume meter, and a button to **"Open Dashboard Window"**.

### 3.3 Audio Engine & Web Player Overhaul (`WebAudioPlayer.swift`)
- **AudioWorklet Architecture**:
  - Migrate from `AudioBufferSourceNode` to an inline registered `AudioWorkletProcessor` (`"pcm-player-worklet"`).
  - Web worker/worklet receives PCM Int16 samples, converts to Float32 [-1.0, 1.0], and stores in a high-speed Float32 circular ring buffer.
  - On each quantum (`process(inputs, outputs, parameters)` 128 frames), reads directly from the ring buffer.
- **Adaptive Jitter Buffer & Drift Correction**:
  - Calculates target queue frames based on latency mode:
    - *Ultra-Low*: ~1,440 frames (~30ms)
    - *Balanced*: ~2,880 frames (~60ms)
    - *Smooth*: ~5,760 frames (~120ms)
  - If buffer depth drifts above target + threshold: gently adjusts playback rate (or skips a fractional frame per quantum) to eliminate accumulated delay without audible pitch jumps.
  - If buffer depth dips (underrun): soft zero-fill smoothing to prevent loud speaker pop.
- **Screen Wake Lock**:
  - Requests `navigator.wakeLock.request('screen')` on start to prevent mobile devices (iOS Safari / Android) from putting the screen or network radio to sleep while listening.
- **UI Enhancements in Web Player**:
  - Latency preset buttons (Ultra-Low / Balanced / Smooth).
  - Buffer health indicator and real-time buffer ms telemetry.
  - Real-time frequency spectrum visualizer.

### 3.4 Windows / Python Native Client (`audiotunnel_receiver.py`)
- Set `socket.IPPROTO_TCP, socket.TCP_NODELAY, 1` to disable Nagle's algorithm.
- Replace blocking queue with ring buffer and dynamic chunk sizing for PyAudio / sounddevice.

---

## 4. Packaging & Distribution

- Update `scripts/package_app.sh`:
  - Build release binary via `swift build -c release`.
  - Assemble standalone `AudioTunnel.app` with `Contents/MacOS/AudioTunnel`, `Contents/Info.plist`, and `Resources`.
  - Update `Info.plist` to support standard macOS application activation (`LSUIElement` omitted or set to `false` when window is opened).

---

## 5. Verification Plan

1. **Compilation & Build**:
   - `swift build` passes without errors.
   - Run existing and new test suites: `swift test`.
2. **App Window Functionality**:
   - Launch application, verify `DashboardView` opens as a standalone macOS window with Dock icon.
   - Verify MenuBarExtra opens and can activate/show the main window.
   - Verify Audio Source switching (System Audio, Microphone, Test Generator).
3. **Web Player Verification**:
   - Open Web Player in browser (`http://localhost:7070`).
   - Confirm AudioWorklet initializes cleanly without fallback errors.
   - Verify Audio stream plays smoothly with no clicks/pops.
   - Verify Latency mode switching works as intended.
