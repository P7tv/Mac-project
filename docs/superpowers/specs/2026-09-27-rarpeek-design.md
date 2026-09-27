# RarPeek: Native macOS RAR & Archive Inspector/Extractor Design Specification

**Date:** 2026-09-27  
**Status:** Approved  
**Author:** Antigravity Team  

---

## 1. Overview & Goals

macOS natively lacks support for RAR format archives (specifically RAR4, RAR5, solid archives, multi-part volumes, and password-protected RAR files). Existing third-party apps often either extract blindly without allowing users to see what is inside, or bombard users with ads and complex menus.

**RarPeek** is a lightweight, modern, native macOS application built with SwiftUI and AppKit. It allows users to:
1. **Peek First**: Drag & drop any `.rar` (or `.7z`, `.zip`, `.tar.gz`) archive to instantly inspect the file hierarchy, file count, compressed/uncompressed sizes, and modification dates before extracting anything to disk.
2. **Selective or Full Extraction**: Click "Extract All" or choose specific files/folders to extract directly.
3. **Robust Archive Coverage**: Seamlessly handles RAR5, multi-part archives (`.part1.rar`, `.r00`), and encrypted archives with interactive password prompt.
4. **Zero-Configuration Self-Contained Engine**: Bundles the required extraction engines inside `Contents/Resources/bin/` so end-users never need to install external packages or tools.

---

## 2. User Interface & Experience Design

### 2.1 Drop Zone Screen (Empty State)
- Clean, modern macOS drop area with subtle dashed borders and glassmorphism styling.
- Center icon: `doc.zipper` or archive icon with smooth hover animation.
- Text: *"Drop any RAR, 7Z, or ZIP archive here"* or *"Click to Browse Files"*.
- Supported format badges: `RAR5`, `RAR4`, `7Z`, `ZIP`, `TAR`, `ISO`.

### 2.2 Archive Inspector Screen
- **Top Toolbar**:
  - Archive name and badges (e.g. `RAR5 Archive`, `12 files • 45.2 MB`).
  - Search bar: Real-time filtering of files inside the archive.
  - Target destination picker (`Same Folder`, `Downloads`, `Choose Folder...`).
  - Action buttons:
    - `[ Extract All ]` (Primary accent button).
    - `[ Extract Selected ]` (Active when items are selected/checked).
- **Interactive File Table / Tree View**:
  - Columns:
    - Selection Checkbox.
    - File Icon (native macOS system icon for specific file type via `NSWorkspace`).
    - File Name / Path.
    - Size (formatted in KB/MB).
    - Compressed Size & Ratio.
    - Modified Date.
- **Password Modal Dialog**:
  - Appears automatically if the archive is encrypted or protected.
  - Secure input field with "Show Password" toggle and "Unlock" button.
- **Extraction Progress Modal / Banner**:
  - Live progress bar with extracted percentage, current file being unpacked, and remaining time.
  - Completion sheet with "Reveal in Finder" and "Open Folder" quick actions.

---

## 3. Architecture & Components

```
RarPeek/
├── Sources/
│   ├── RarPeek/
│   │   └── RarPeekApp.swift           # macOS App Lifecycle & Menu commands
│   └── RarPeekCore/
│       ├── Models/
│       │   ├── ArchiveEntry.swift     # Model representing a file/directory inside archive
│       │   ├── ArchiveInfo.swift      # Metadata (format, total size, file count, encrypted)
│       │   └── ExtractionOptions.swift# Target folder, password, overwrite policy
│       ├── Services/
│       │   ├── ArchiveEngine.swift    # Core engine orchestrator (unar / lsar / 7zz wrapper)
│       │   ├── ArchiveParser.swift    # Parses lsar/7zz JSON and text into ArchiveEntry tree
│       │   └── ExtractionTask.swift   # Async extraction runner with stdout stream parsing
│       ├── ViewModels/
│       │   └── ArchiveViewModel.swift # App state, selected items, progress, search filter
│       └── Views/
│           ├── ArchiveDropZoneView.swift
│           ├── ArchiveInspectorView.swift
│           ├── ArchiveEntryRowView.swift
│           └── PasswordPromptView.swift
├── Resources/
│   ├── Info.plist
│   ├── AppIcon.icns
│   └── bin/                           # Bundled native binaries (unar, lsar, 7zz)
├── Tests/
│   └── RarPeekTests/
│       ├── ArchiveParserTests.swift
│       └── ArchiveEngineTests.swift
└── scripts/
    └── package_app.sh                 # Releases RarPeek.app to /Applications
```

---

## 4. Archive Engine Implementation Strategy

### 4.1 Discovery & Fallback
The engine checks:
1. `Bundle.main.resourceURL/bin/` (Bundled binaries for production).
2. `/opt/homebrew/bin/` (Homebrew fallback).
3. System paths (`/usr/local/bin`, `/usr/bin`).

### 4.2 Inspection (List Operation)
Uses `lsar -j <archive_path>` (JSON output mode) or `7zz l -slt <archive_path>`:
- Retrieves clean structured JSON with file paths, sizes, dates, CRC, and encryption flags without extracting any bytes to disk.

### 4.3 Extraction Operation
Uses `unar` or `7zz x`:
- Destination directory parameter `-o <dest_dir>`.
- Password parameter `-p <password>` (if supplied).
- Selective file parameter (when extracting only chosen files).
- Real-time stdout progress monitoring.

---

## 5. Error Handling & Edge Cases

| Scenario | Handling |
|---|---|
| Password-protected archive | Parser detects `encrypted: true` -> triggers `isShowingPasswordDialog = true` before extraction. |
| Multi-part archives (`.part1.rar`) | Engine automatically detects sibling parts (`.part2.rar`, etc.) in the same folder. |
| Filename collisions | Options to Rename (`file (1).ext`) or Overwrite. |
| Damaged or invalid archive | Friendly error alert explaining corrupted archive or missing volume. |

---

## 6. Verification & Quality Gates

1. Unit tests verifying:
   - Archive info parsing (file counts, paths, directory hierarchies).
   - Password detection.
   - Size calculation and tree formatting.
2. End-to-end integration tests:
   - Creating sample RAR/ZIP archives and inspecting them.
   - Extracting to temp directory and verifying file contents and checksums.
3. Packaging test:
   - Bundle built and signed ad-hoc, installed to `/Applications/RarPeek.app`.
   - Verified launched and operational.
