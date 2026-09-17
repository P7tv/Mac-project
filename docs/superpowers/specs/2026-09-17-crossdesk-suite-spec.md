# CrossDesk Suite — Technical Specification

## Overview
CrossDesk Suite is a unified family of native macOS utility applications built with Swift and SwiftUI for Apple Silicon, designed to create a seamless, zero-cloud bridge between Mac, Windows, and mobile devices over local wireless networks.

The suite comprises 4 distinct, standalone applications:
1. **AirBridge**: Universal Wireless Clipboard & Instant Drop (Mac ⇄ Windows ⇄ Mobile)
2. **KeySync**: Wireless Mouse & Keyboard Sharing (Software KVM / Universal Control for Windows)
3. **AudioTunnel**: Ultra-Low Latency Wireless Audio Bridge (CoreAudio ⇄ Windows / WebAudio)
4. **QuickRecall**: 100% On-Device Neural OCR Screen Timeline & Semantic Search

---

## 1. AirBridge (Wireless Universal Clipboard & File Drop)

### 1.1 Goal
Provide seamless, bidirectional clipboard sync and drag-and-drop file transfer across Mac, Windows, and mobile devices over local Wi-Fi/Hotspot with zero internet, zero cloud storage, and pairing security.

### 1.2 Architecture
* **Mac Host (`AirBridge.app`):**
  * `NSPasteboard` listener with SHA-256 deduplication to detect new text, URLs, and images.
  * Embedded HTTP & RFC 6455 WebSocket server (`Network.framework` NWListener, Bonjour `_airbridge._tcp`).
  * PIN Verification Engine: 4-digit pairing code with ephemeral bearer tokens.
  * SwiftUI Menu Bar Popover with Drop Zone, Recent 10 Clipboard Feed, and QR Code display.
* **Mobile Web Portal:**
  * Self-contained responsive HTML5/CSS/JS client served on `http://airbridge.local:5050` or `http://<IP>:5050`.
  * Live clipboard feed, 1-click copy, and file/photo upload into Mac.
* **Windows Companion (`AirBridge-Windows`):**
  * Standalone lightweight executable running in Windows System Tray.
  * Subscribes to `WM_CLIPBOARDUPDATE` for seamless native `Ctrl+C` / `Ctrl+V` synchronization.

---

## 2. KeySync (Universal Mouse & Keyboard Control)

### 2.1 Goal
Allow a single mouse and keyboard connected to a Mac to seamlessly glide across screen borders and control a secondary Windows PC over local Wi-Fi without hardware switches.

### 2.2 Architecture
* **Mac Host (`KeySync.app`):**
  * `CGEventTap` to monitor cursor coordinates at active display edges.
  * Border Detection: When cursor passes defined screen edge (e.g. right border), Mac captures cursor, hides it locally, and redirects all keyboard/mouse inputs into an encrypted UDP/TCP stream.
  * Emergency Exit: Configurable hotkey (default: `Cmd + Escape`) to instantly release control back to Mac.
* **Windows Client (`KeySync-Windows`):**
  * Native Windows receiver using `SendInput` API for sub-millisecond mouse pointer interpolation and keystroke injection.

---

## 3. AudioTunnel (Low-Latency Audio Bridge)

### 3.1 Goal
Stream Mac system audio to Windows speakers/headphones or turn a phone into a wireless studio microphone for Mac with < 10ms latency.

### 3.2 Architecture
* **Mac Host (`AudioTunnel.app`):**
  * `ScreenCaptureKit` / `CoreAudio` HAL tap capturing uncompressed 48kHz 16-bit stereo PCM.
  * Audio streamer supporting both raw PCM (for LAN) and Opus compression (for Wi-Fi resilience).
* **Receiver:**
  * WebAudio API HTML5 client for zero-install browser listening.
  * Low-latency Windows WASAPI audio receiver client.

---

## 4. QuickRecall (Local AI Screen Memory & OCR Search)

### 4.1 Goal
Provide an offline "Rewind" search capability on Mac: remember everything seen on screen with searchable OCR and zero cloud dependency.

### 4.2 Architecture
* **Capture Engine:** Periodic lightweight perceptual diff capture (every 5-10s) using `ScreenCaptureKit`.
* **Neural OCR:** Apple Silicon Neural Engine (`VNRecognizeTextRequest`) recognizing Thai and English text with zero CPU penalty.
* **Storage:** Embedded SQLite with FTS5 (Full-Text Search) and encrypted thumbnail cache.
* **UI:** Spotlight-like quick launcher (`Cmd + Shift + Space`) with instant jump-to-time and copy-text features.
