# 🗜️ RarPeek for macOS

**RarPeek** is a lightweight, modern, native macOS application designed to inspect and unpack WinRAR (`.rar`) archives and multi-format compressed files with zero external prerequisites.

---

## ✨ Features

- **Inspect Before You Extract (Peek Mode)**: Drag & drop any archive to instantly browse the folder tree, view individual file sizes, compression ratios, and modification dates without writing anything to disk.
- **Full RAR Compatibility**:
  - RAR v4 & RAR v5.
  - Multi-part archives (`.part1.rar`, `.part01.rar`, `.r00`).
  - Solid archives.
  - Password-protected archives with secure modal unlock dialog.
- **Multi-Format Support**: Also extracts `.7z`, `.zip`, `.tar.gz`, `.iso`, and more.
- **Selective or Full Extraction**:
  - `[ Extract All ]`: Unpack everything into your destination folder.
  - `[ Extract Selected ]`: Tick checkboxes to extract only the files you need.
- **Real-Time Search**: Quickly locate files in massive archives using the instant search filter.
- **100% Self-Contained**: Bundles native Apple Silicon extraction engines inside `Contents/Resources/bin/` — no Homebrew or terminal dependencies required for end-users.

---

## 🚀 Getting Started

1. Launch RarPeek from `/Applications/RarPeek.app`.
2. Drag and drop any `.rar` file into the window, or click **"Select Archive File..."** (or press `Cmd + O`).
3. Browse the files, choose your destination folder, and click **"Extract All"** or select individual files.
4. When extraction is complete, click **"Reveal in Finder"** to open your files immediately!

---

## 🛠️ Building & Packaging from Source

```bash
cd "RarPeek"
./scripts/package_app.sh
```
The packaged app will be generated at `RarPeek.app` and can be copied directly to `/Applications`.
