# DropMorph: Target File Size (MB) Design Specification

**Date:** 2026-09-24  
**Status:** Approved  
**Author:** Antigravity Team  

---

## 1. Overview & Motivation

DropMorph currently supports manual Quality adjustment (0.1 to 1.0) and fixed Scale Presets (`100%`, `75%`, `50%`, `25%`, `Max 1920px`, etc.). When users need to share files over email, government/corporate job portals, messaging apps (Discord/LINE/Slack), or upload systems with hard file size limits (e.g. `<= 2 MB`, `<= 5 MB`, `<= 25 MB`), guessing the right quality slider value requires frustrating trial and error.

This feature introduces a dedicated **Target Size (MB)** mode across all media types in DropMorph (Images, PDFs, and Videos). Users can pick from quick preset buttons (`1 MB`, `2 MB`, `5 MB`, `10 MB`, `25 MB`) or enter a custom target size in megabytes. DropMorph automatically tunes quality and dimension scaling to produce an output file guaranteed to be less than or equal to the target size while maximizing visual fidelity.

---

## 2. Requirements & Scope

1. **Comprehensive Media Coverage**:
   - **Images**: JPEG, WebP, HEIC, TIFF, PNG (via downscaling fallback).
   - **PDFs**: Single-page and multi-page documents re-rendered and compressed within the target budget.
   - **Videos**: MP4/MOV encoded to MP4 with exact average bitrate budgeting.
2. **UI & Control Bar (`SettingsBarView`)**:
   - Mode Toggle: Switch between **Quality (%)** and **Target Size (MB)**.
   - Target Size Preset Chips: `1 MB`, `2 MB`, `5 MB`, `10 MB`, `25 MB (Email/Discord)`.
   - Custom Stepper / Numeric Input: Supports precise input (e.g. `0.5`, `3.5`).
   - Clean, modern macOS SwiftUI design consistent with DropMorph's visual system.
3. **Accuracy & Quality Guarantee**:
   - If input file is already smaller than target size, preserve original quality.
   - Guarantee output file size is `<= targetBytes`.
   - Maximize visual clarity (never downscale resolution unless quality reduction alone is insufficient).

---

## 3. Architecture & Data Models

### 3.1 `ConversionSettings.swift`

Extend settings with `CompressionMode` and `targetSizeMB`:

```swift
public enum CompressionMode: String, CaseIterable, Identifiable, Sendable {
    case quality = "Quality"
    case targetSize = "Target Size"

    public var id: String { rawValue }
}

public struct ConversionSettings: Sendable {
    public var targetFormat: OutputFormat
    public var mode: CompressionMode
    public var quality: Double            // 0.1 to 1.0
    public var targetSizeMB: Double       // e.g. 1.0, 2.0, 5.0, 25.0
    public var resizePreset: ResizePreset
    public var stripMetadata: Bool
    public var customOutputFolder: URL?

    public var targetSizeBytes: Int64 {
        Int64(max(0.1, targetSizeMB) * 1024 * 1024)
    }

    public init(
        targetFormat: OutputFormat = .webp,
        mode: CompressionMode = .quality,
        quality: Double = 0.8,
        targetSizeMB: Double = 2.0,
        resizePreset: ResizePreset = .original,
        stripMetadata: Bool = true,
        customOutputFolder: URL? = nil
    ) {
        self.targetFormat = targetFormat
        self.mode = mode
        self.quality = quality
        self.targetSizeMB = targetSizeMB
        self.resizePreset = resizePreset
        self.stripMetadata = stripMetadata
        self.customOutputFolder = customOutputFolder
    }
}
```

---

## 4. UI Specification (`SettingsBarView.swift`)

In the controls row beneath the format selector:
1. **Mode Switcher**:
   - Capsule segmented control: `[ Quality (%) | Target Size (MB) ]`.
2. **Quality View** (when `mode == .quality`):
   - Existing Quality Slider (`0.1...1.0`) with percentage label (`80%`).
3. **Target Size View** (when `mode == .targetSize`):
   - Quick Preset Chips: `[1 MB] [2 MB] [5 MB] [10 MB] [25 MB]`.
   - Numeric input field / Stepper: `[ 2.0 ] MB` (allowing decimal inputs like `1.5` or `0.5`).
4. **Scale & Privacy Controls**:
   - `Scale` picker and `Strip EXIF` toggle remain accessible across both modes.

---

## 5. Compression Engines & Algorithms

### 5.1 Image Compression Engine (`ImageConverter.swift`)

When `settings.mode == .targetSize`:
1. **Pre-check**: If input file size is already `<= targetBytes`, perform conversion at high quality (`0.92`) without degradation.
2. **Binary Search Quality Optimization (In-Memory)**:
   - For lossy formats (`jpeg`, `heic`, `webp`):
   - Binary search over compression quality range `[0.05, 0.95]` (up to 4 iterations).
   - Encode into in-memory `Data` using `CGImageDestinationCreateWithData`.
   - Pick the highest quality where `data.count <= targetBytes`.
3. **Smart Downscaling Fallback**:
   - If at quality `0.15` the encoded size still exceeds `targetBytes`:
   - Compute required downscale factor: `scaleFactor = sqrt(Double(targetBytes) / Double(data.count)) * 0.92`.
   - Downscale the image via `CGContext` or `CGImageSourceCreateThumbnailAtIndex`.
   - Re-compress with balanced quality (`0.75`) to guarantee fitting within `targetBytes` with crisp downsampled edges rather than severe compression artifacts.
4. **For WebP (`cwebp`)**:
   - When using `cwebp` command line, pass `-size <targetBytes>` or computed quality and `-resize <w> <h>` if downscaled.

### 5.2 PDF Compression Engine (`PDFCompressor.swift`)

When `settings.mode == .targetSize`:
1. Calculate per-page byte budget: `perPageTarget = targetBytes / pageCount`.
2. Iterative canvas rasterization:
   - Estimate initial scale: `min(1.5, sqrt(Double(perPageTarget) / 150_000.0) * 1.5)`.
   - In-memory test compression: Render first 1-2 pages to evaluate compressed page size.
   - Adjust page scale and JPEG compression quality (`0.3 ... 0.85`) so the total `PDFDocument.dataRepresentation()` conforms to `<= targetBytes`.

### 5.3 Video Compression Engine (`VideoConverter.swift`)

When `settings.mode == .targetSize`:
1. Probe video duration via `AVURLAsset`.
2. Compute bitrate budget:
   - Total allowed bits: `totalBits = targetBytes * 8 * 0.90` (leaving 10% safety margin for MP4 container overhead).
   - Audio bitrate: allocated 96 kbps (or 64 kbps if `targetSizeMB < 2.0`).
   - Video bitrate: `videoBitrate = max(100_000, Int((totalBits / duration) - (audioBitrate)))`.
3. Auto-downscale resolution if bitrate is low:
   - `videoBitrate >= 2_000_000`: 1080p.
   - `800_000 <= videoBitrate < 2_000_000`: 720p.
   - `videoBitrate < 800_000`: 480p / 540p.
4. Export using `AVAssetWriter` configured with `AVVideoAverageBitRateKey: videoBitrate` and `AVVideoProfileLevelH264HighAutoLevel`.

---

## 6. Error Handling & Edge Cases

| Edge Case | Handling Strategy |
|---|---|
| Input file is already `< targetMB` | Keep high quality (0.92); do not degrade or bloat the file. |
| Extremely small target (e.g. 0.1 MB for 4K video) | Clamp minimum bitrate / resolution (360p, 120kbps); warn user if duration exceeds physical codec limits. |
| Non-lossy target formats (PNG, TIFF) | Cannot vary quality lossily; automatically scale dimensions down to satisfy target size. |
| Multi-file batch queue | Each item in queue calculates its own optimal parameters independently based on its source resolution and duration. |

---

## 7. Verification & Testing Plan

1. **Unit Tests (`EngineTests.swift`)**:
   - `testImageTargetSizeCompression()`: Verify image compressed to 500 KB and 1 MB is `<= targetBytes`.
   - `testImageTargetSizeDownscaleFallback()`: Verify massive test image downscales cleanly to fit small target (e.g. 200 KB).
   - `testPDFTargetSizeCompression()`: Verify multi-page PDF compresses to `<= targetBytes`.
   - `testVideoBitrateTargetSize()`: Verify video bitrate calculation matches duration and target size.
2. **Integration & UI Test**:
   - Verify `SettingsBarView` toggles correctly between Quality slider and Target Size preset chips.
   - Verify custom stepper value changes update `ConversionViewModel`.
   - Build macOS app bundle and test with real-world drag-and-drop.
