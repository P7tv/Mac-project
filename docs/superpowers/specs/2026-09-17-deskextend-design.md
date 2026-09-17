# DeskExtend - Real-Time Offline Virtual Display & Screen Extender for macOS

**Status:** Approved  
**Date:** 2026-09-17  
**Platform:** macOS 14.0+ (Apple Silicon & Intel)  
**Target Path:** `DeskExtend/` inside workspace  

---

## 1. Overview & Problem Statement

Users often have a secondary computer (such as a Windows PC) connected to a primary monitor via DisplayPort, but lack an HDMI cable/adapter or video capture card to connect their Mac directly to the monitor.

**DeskExtend** solves this by creating a true hardware-level secondary display (`CGVirtualDisplay`) on macOS and streaming it in real-time (60 FPS, ultra-low latency) to any web browser on the local network (such as Chrome or Edge on Windows).

### Key Constraints & Requirements:
- **True Extended Display:** The virtual monitor is recognized by macOS as a real secondary display in `System Settings -> Displays`. The user can arrange it (left, right, top, bottom), drag windows onto it, and the Mac mouse cursor naturally travels across screens.
- **100% Offline (Zero Internet Dependency):** All web assets, protocols, and streams execute strictly over the local network or direct cable link-local (`169.254.x.x`). No internet connection, cloud services, or external CDNs required.
- **Zero-Install Client for Windows:** The Windows machine requires no software installation; opening a browser tab in fullscreen (`F11`) turns the monitor into the Mac's second display.
- **Ultra-Low Latency:** Uses hardware-level frame capture (`ScreenCaptureKit`/`CGDisplayStream`) and lightweight binary streaming over WebSocket for responsive typing and mouse tracking.

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Mac (Host App)                        │
│                                                             │
│  [CGVirtualDisplay] ──► Spawns 1080p/1440p Secondary Display│
│           │                                                 │
│           ▼                                                 │
│  [ScreenCaptureEngine] ──► 60 FPS Zero-Copy Frame Capture   │
│           │                                                 │
│           ▼                                                 │
│  [LocalStreamServer] ──► Embedded HTTP + WebSocket Server   │
│           │              (Port 8080, Pure Swift Network)    │
└───────────┼─────────────────────────────────────────────────┘
            │ Local Network / Direct Cable (Ethernet/USB-C)
            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Windows PC (Monitor)                     │
│                                                             │
│  Chrome / Edge Browser (http://<mac-ip>:8080)               │
│  - F11 Fullscreen                                           │
│  - HTML5 Canvas2D / WebCodecs 60 FPS Render                 │
│  - Real-time Latency & FPS Monitor                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Core Modules & Specifications

### 3.1 Virtual Display Manager (`VirtualDisplayManager.swift`)
- Interacts with macOS CoreGraphics `CGVirtualDisplayDescriptor`, `CGVirtualDisplaySettings`, `CGVirtualDisplayMode`, and `CGVirtualDisplay`.
- Supported Modes:
  - `1920x1080 @ 60Hz` (Default)
  - `2560x1440 @ 60Hz` (2K)
  - `1280x720 @ 60Hz` (High performance)
- Emits `displayID` when active.
- Automatically cleans up and destroys virtual display when stopped or app quits.

### 3.2 Screen Capture Engine (`ScreenCaptureEngine.swift`)
- Captures frames from the virtual `CGDirectDisplayID`.
- Uses `CGDisplayStream` and `ScreenCaptureKit` for hardware-accelerated frame delivery.
- Frame compression: Fast Turbo JPEG encoding with adjustable quality (0.6 - 0.85) to guarantee under 20-30ms transmission time over Wi-Fi / direct cable.
- Smart frame-skipping: If network backpressure occurs, old unconsumed frames are dropped to preserve real-time interactivity.

### 3.3 Embedded Stream Server (`StreamServer.swift`)
- Swift native TCP/HTTP/WebSocket server using Apple's `Network.framework` (`NWListener`).
- Serves self-contained client files (`index.html`, `app.js`, `style.css`) directly from memory with zero external requests.
- Accepts WebSocket connections at `/stream`.
- Broadcasts binary frame packets: `[Header: 1B][Timestamp: 8B][ImageData]`.
- Network Discovery helper: Detects active network interfaces:
  - Wi-Fi (e.g. `192.168.1.X`)
  - Direct Cable / Thunderbolt / USB-C link (`169.254.X.X`)
  - Localhost (`127.0.0.1`)

### 3.4 Web Client (`web/index.html`)
- Ultra-responsive, black-background HTML5 canvas.
- Automatic reconnection if Wi-Fi glitches.
- Press `F` or double-click to toggle Fullscreen.
- Live stats HUD (FPS counter, Ping/Latency in ms, Resolution).

### 3.5 macOS Host UI (`DashboardView.swift`)
- Modern glassmorphic SwiftUI dashboard.
- Active toggle: "Start Extended Display" / "Stop".
- Network Address Cards: Shows active IPs with "Copy Link" and QR code for instant phone/tablet/laptop pairing.
- Resolution & Refresh Rate selector.
- Live Mini Preview of the virtual screen.
- Quick button: "Open macOS Display Settings" to arrange monitor position (left/right/top).

---

## 4. Technology Stack
- **Language:** Swift 6.2 (Strict Concurrency safe)
- **Frameworks:** SwiftUI, AppKit, CoreGraphics (`CGVirtualDisplay`), ScreenCaptureKit, Network.framework (`NWListener`, `NWConnection`), ImageIO
- **Packaging:** Swift Package Manager + `.app` Bundle installer in `/Applications/DeskExtend.app`
