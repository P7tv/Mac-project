# GhostTranslate Design Specification

**Date:** 2026-10-01  
**Status:** Approved  
**Author:** Antigravity & User  
**Target Platform:** macOS 13.0+ (Ventura, Sonoma, Sequoia)  
**Primary AI Engine:** SCB 10X Typhoon AI (`typhoon-v2.5-30b-a3b-instruct`)  

---

## 1. Executive Summary

**GhostTranslate** is a native macOS translation and interview assistant application that provides real-time speech subtitles, screen OCR translation, and AI interview talking points. 

Its standout capability is **Stealth Overlay (Ghost Window)**: the translation HUD is displayed on the user's screen but is strictly hidden from screen sharing software (Zoom, Google Meet, Microsoft Teams, Slack, Discord, OBS, QuickTime, and ScreenCaptureKit) by configuring macOS WindowServer layer sharing rules.

---

## 2. Core Capabilities & Features

### 2.1 Stealth Window (Ghost Overlay)
- Built using `NSPanel` / `NSWindow` with `styleMask = [.borderless, .nonactivatingPanel]`, `level = .floating`.
- **Screen Sharing Invisibility**: `window.sharingType = .none`. macOS WindowServer excludes this window from any window-list capture or screen recording stream.
- **Click-Through Mode**: Toggleable `ignoresMouseEvents = true` so the user can interact with code, browser, or IDE beneath the overlay.
- **HUD Controls**: Transparency slider (0% to 90%), draggable title bar / pin button, font size adjustments.

### 2.2 Input Sources
1. **Live Audio Stream (Speech-to-Text)**:
   - Captures microphone or system audio using `AVAudioEngine`.
   - On-device speech recognition via Apple `SFSpeechRecognizer` (`en-US`, `th-TH`, etc.).
   - Emits streaming partial and final transcript segments.
2. **Screen OCR Snip**:
   - Triggered via global hotkey (`⌘ + ⌥ + O`).
   - Crosshair overlay allows user to drag a selection rectangle over any movie subtitle, PDF, terminal, or presentation.
   - Apple Vision framework (`VNRecognizeTextRequest`) extracts text locally in < 50ms.

### 2.3 AI Intelligence Engine (Typhoon AI)
- **Model**: `typhoon-v2.5-30b-a3b-instruct` via `https://api.opentyphoon.ai/v1/chat/completions`.
- **Response Speed**: ~0.30s latency for translations; ~1.2s for structured interview talking points.
- **Mode 1 - Subtitle Translation**:
  - Translates speech fragments into concise, natural Thai subtitles with low latency.
- **Mode 2 - Interview Co-pilot / Prompter**:
  - Ingests interviewer question.
  - Generates:
    1. Question summary in Thai.
    2. 3 actionable bullet points (key talking points, structured frameworks like STAR/metrics).
    3. English response keywords to guide natural speaking.
- **Fallback / Multi-Engine**: Offline fallback or custom API key configuration in settings.

### 2.4 User Interface Modes
- **Dual Display Modes**:
  1. *Subtitle Bar Mode*: Horizontal floating bar positioned near screen bottom for movie / lecture / meeting subtitles.
  2. *Interview Prompter Mode*: Vertical sidebar / HUD card positioned near webcam / screen corner with question breakdown and bullet points.
- **Global Hotkeys**:
  - `⌘ + ⌥ + G`: Toggle Overlay visibility.
  - `⌘ + ⌥ + M`: Toggle Mode (Subtitle Bar ↔ Interview Prompter).
  - `⌘ + ⌥ + O`: Screen OCR Snip.
  - `⌘ + ⌥ + C`: Toggle Click-through.

---

## 3. Architecture & Unit Boundaries

```
GhostTranslate
├── App
│   ├── GhostTranslateApp.swift          // App lifecycle & MenuBar Extra
│   └── AppState.swift                   // Shared reactive state
├── Core
│   ├── Window
│   │   ├── GhostPanel.swift             // Custom NSPanel with sharingType = .none
│   │   └── WindowManager.swift          // Positioning, click-through, mode transitions
│   ├── Audio
│   │   └── AudioTranscriptionEngine.swift // AVAudioEngine + SFSpeechRecognizer
│   ├── OCR
│   │   ├── ScreenSnipper.swift          // Interactive selection overlay
│   │   └── VisionOCREngine.swift        // VNRecognizeTextRequest wrapper
│   └── AI
│       ├── TyphoonService.swift         // OpenAI-compatible Typhoon API client
│       └── Prompts.swift                // Optimized prompts for subtitles & interview
└── UI
    ├── HUD
    │   ├── SubtitleBarView.swift        // Horizontal subtitle bar
    │   ├── InterviewPrompterView.swift  // Teleprompter cards with bullet points
    │   └── GhostHUDContainerView.swift  // Container with drag & opacity controls
    ├── Settings
    │   └── SettingsView.swift           // Typhoon API key, audio input, hotkey guide
    └── SnipOverlay
        └── SelectionOverlayWindow.swift // Interactive screen capture rect
```

---

## 4. Error Handling & Edge Cases

1. **Microphone Permission Denied**:
   - Gracefully display permission banner in Settings with direct button to `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`.
2. **Typhoon API Network Timeout / Invalid Key**:
   - Provide visual status indicator (Green = Connected, Yellow = Reconnecting, Red = Key Error).
   - Display raw transcription if AI translation is temporarily delayed.
3. **Screen Capture Permissions**:
   - Request `CGRequestScreenCaptureAccess()` cleanly for OCR feature.
4. **Window Capture Verification**:
   - Unit test and manual verification tool to ensure `sharingType == .none` is active.

---

## 5. Verification Strategy

1. **Unit Tests**:
   - `TyphoonServiceTests`: Payload generation, SSE parsing, mock completion handling.
   - `VisionOCREngineTests`: Image OCR text extraction with sample test image.
   - `GhostPanelTests`: Verify `sharingType == .none` and mouse event handling.
2. **Application Packaging**:
   - Compile release binary using `swift build -c release`.
   - Package into `/Applications/GhostTranslate.app` with AppIcon and Info.plist.
   - Verify stealth behavior and live Typhoon translation.
