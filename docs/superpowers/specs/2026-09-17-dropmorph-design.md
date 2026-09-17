# DropMorph - macOS Quick Drag & Drop Media Converter

**Status:** Approved  
**Date:** 2026-09-17  
**Platform:** macOS 14.0+ (Tested on macOS 15 Sequoia / Swift 6.2)  
**Target Path:** `DropMorph/` inside workspace  

---

## 1. Overview & Goal

DropMorph is an ultra-fast, native macOS utility designed to eliminate the friction of converting, resizing, compressing images, and merging photos into PDFs. Instead of relying on slow web converters, privacy-invasive online tools, or heavy photo editing software, DropMorph provides a sleek, drag-and-drop experience that executes 100% locally on Apple Silicon / macOS.

The app adopts a **Hybrid** form factor:
1. **Menu Bar Accessory (`MenuBarExtra`):** Resides unobtrusively in the macOS menu bar for rapid single-file drop conversions and status checks.
2. **Glassmorphic Floating Dashboard:** A compact, polished floating window with translucent vibrancy (`.ultraThinMaterial`), "Always on Top" pin toggle, batch queue list, quality slider, format picker, and conversion statistics (space saved, dimensions).

---

## 2. Core Features & Capabilities

### 2.1 Drag & Drop Engine
- Native macOS drag-and-drop handling using SwiftUI `.dropDestination(for:action:)` and `onDrop`.
- Visual drop state animation with spring physics, glowing borders, and file count indicators.
- Accepts single images, multiple images, and folders containing images.

### 2.2 Image Conversion & Optimization
- **Supported Input Formats:** PNG, JPEG, WebP, HEIC, TIFF, GIF, BMP.
- **Supported Output Formats:**
  - **WebP:** Modern, ultra-compact web image format.
  - **PNG:** Lossless format with alpha transparency preservation.
  - **JPEG:** Universal format with configurable compression quality.
  - **HEIC:** Apple high-efficiency format.
  - **PDF (Single or Merged):** Convert image(s) to a standard PDF document.
- **Quality Slider:** 10% to 100% (default 80% for optimal balance of sharpness vs file size).
- **Dimension Resizing:**
  - Original (100%)
  - Scaled Presets: 75%, 50%, 25%
  - Max Dimension constraint (e.g. 1920px, 1280px, 800px).
- **Privacy Mode (Strip Metadata):** Option to strip EXIF, GPS location, and camera camera metadata during conversion.

### 2.3 Multi-Image to PDF Merge
- When 2 or more images are dropped with the "Merge to PDF" mode selected, DropMorph orders the pages and compiles them into a clean, multi-page vector-wrapped PDF using `PDFKit`.

### 2.4 Output & Workflow Integration
- **Output Destination:**
  - Same folder as original file (with suffix, e.g., `photo_converted.webp`)
  - User-selected custom destination directory (e.g., `~/Downloads` or `~/Desktop`)
- **Action Buttons per item:**
  - "Reveal in Finder"
  - "Quick Look" preview
  - "Copy to Clipboard"
  - Clear item / Clear all

---

## 3. UI/UX Specifications

### 3.1 Design System & Aesthetic
- **Mac-Native Visuals:** Uses SF Pro font hierarchy, SF Symbols 6 icons, smooth Apple-style spring animations.
- **Glassmorphism:** Background styling using `material` translucent blur (`NSVisualEffectView` / `.background(.ultraThinMaterial)`).
- **Theme Support:** Fully adaptive to macOS Dark Mode and Light Mode.
- **Micro-Interactions:** Haptic feedback (`NSHapticFeedbackManager`), scale bounce on file drop, animated progress rings during batch processing.

### 3.2 Floating Dashboard Structure
- **Top Navigation Bar:**
  - App icon & title ("DropMorph")
  - "Pin on Top" toggle button (locks window level to `.floating` or resets to `.normal`)
  - Output format segmented picker (`WebP`, `PNG`, `JPG`, `PDF`, `HEIC`)
- **Central Dropzone / Queue View:**
  - *Empty State:* Glowing dotted drop area with SF Symbol arrow, "Drop images here to convert", and quick preset pills.
  - *Active Queue State:* Scrollable list of conversion cards showing thumbnail, original name, old file size -> new file size, percentage saved badge (e.g., `-68%`), and "Reveal" button.
- **Bottom Control Bar:**
  - Quality slider (with percentage label)
  - Resize options dropdown
  - Action buttons: "Convert All", "Merge to PDF", "Clear"

### 3.3 Menu Bar Quick Drop Popover
- Compact dropzone with status count.
- Quick format buttons.
- Button to summon the main floating dashboard window.

---

## 4. Technical Architecture

### 4.1 Technologies
- **Language:** Swift 6.2 (Strict Concurrency safe)
- **Frameworks:**
  - `SwiftUI`: Declarative UI and state management
  - `AppKit`: Native window level management (`NSWindow.level`), MenuBar integration, pasteboard handling
  - `ImageIO` (`CGImageSource`, `CGImageDestination`): Fast, low-memory C-level image manipulation and hardware-accelerated encoding/decoding
  - `UniformTypeIdentifiers` (`UTType`): Accurate MIME/Type resolution
  - `PDFKit` (`PDFDocument`, `PDFPage`): Native PDF generation
- **Build System:** Swift Package Manager (`Package.swift` executable target) with standalone App bundle launcher script. This allows building and running directly without needing complicated manual project generation, while being fully importable into Xcode.

### 4.2 Module Breakdown
```
DropMorph/
├── Package.swift                  # SPM Configuration
├── Sources/
│   └── DropMorph/
│       ├── DropMorphApp.swift     # App entry point, Window & MenuBarExtra definition
│       ├── Models/
│       │   ├── ConversionItem.swift   # Task model (URL, status, sizes, outputURL)
│       │   ├── OutputFormat.swift     # Enum for WebP, PNG, JPEG, HEIC, PDF
│       │   └── ConversionSettings.swift # Quality, scale, metadata settings
│       ├── Services/
│       │   ├── ImageConverter.swift   # ImageIO encoding/decoding engine
│       │   └── PDFMerger.swift        # PDFKit compilation engine
│       ├── ViewModels/
│       │   └── ConversionViewModel.swift # Observable state, drop handler, queue orchestration
│       └── Views/
│           ├── DashboardView.swift    # Main glassmorphic window
│           ├── DropZoneView.swift     # Interactive drag-and-drop target
│           ├── QueueListView.swift    # Card list of conversion items
│           ├── SettingsBarView.swift  # Quality slider, format buttons
│           └── MenuBarPopoverView.swift # Compact menu bar interface
└── Tests/
    └── DropMorphTests/
        └── ImageConverterTests.swift  # Unit tests for image conversion & PDF generation
```

### 4.3 Error Handling & Edge Cases
- Corrupted or non-image files dropped: gracefully mark item with an alert icon and error message ("Unsupported format").
- Read-only directories: detect and redirect output to `~/Downloads` with an informative banner.
- Extremely large images: use downsampling via `CGImageSourceCreateThumbnailAtIndex` to avoid out-of-memory crashes.

---

## 5. Verification & Testing
- Unit tests validating:
  - PNG to WebP conversion and size reduction.
  - JPEG compression with different quality ratios (e.g. 50% vs 90%).
  - Multi-image merge to PDF document page count verification.
- Manual verification:
  - Dragging files into Dropzone and verifying generated output in Finder.
  - Toggling "Always on Top" pin.
  - Testing Menu Bar icon interactions.
