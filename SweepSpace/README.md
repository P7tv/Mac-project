# 🧹 SweepSpace

**SweepSpace** is a high-performance native macOS disk cleaner and storage optimizer built with Swift and SwiftUI. It enables you to reclaim gigabytes of storage space by safely scanning and cleaning system caches, developer junk, large files, and trash with one-click simplicity and visual disk gauges.

---

## ✨ Features

- **⚡ 1-Click Smart Clean**: Instantly scans your Mac storage and cleans safe system/app caches, developer junk, and trash.
- **📊 Visual Storage Gauge**: Radial gauge displaying total capacity, used space, free space, and potential recoverable space.
- **🧹 Curated Cleaning Domains**:
  - **System & App Cache**: `~/Library/Caches`, system logs, temporary files, crash reports.
  - **Developer Space Hogs**: Xcode DerivedData, Archives, iOS DeviceSupport, SPM caches, CocoaPods caches, Homebrew caches, npm & pnpm caches.
  - **Large & Old Files**: Fast multi-threaded search across `Downloads`, `Documents`, `Movies`, and `Desktop` for files > 100MB, > 500MB, and > 1GB with filters for Videos, Archives, and Disk Images.
  - **Trash & Leftovers**: Clean user trash and orphaned data.
- **🛡️ Built-in Safety Whitelist**: Never touches system directories, user roots, or critical files. Large user files are safely moved to the Trash by default.
- **🔍 Granular Control**: Expand any category to see individual apps and files, toggle checkboxes, and click "Reveal in Finder".

---

## 🛠️ Build & Install

```bash
cd "SweepSpace"
./scripts/package_app.sh
cp -R SweepSpace.app /Applications/
```

Or run directly:
```bash
open /Applications/SweepSpace.app
```

---

## 🧪 Testing

```bash
swift test --package-path "SweepSpace"
```
