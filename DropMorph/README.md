# DropMorph 🌀

**DropMorph** เป็นแอปพลิเคชัน macOS Native แบบ Hybrid (Floating Dashboard + Menu Bar) พัฒนาด้วยภาษา **Swift 6 & SwiftUI** สำหรับแปลงไฟล์รูปภาพ ย่อขนาด บีบอัดไฟล์ และรวมรูปภาพเป็น PDF ได้อย่างรวดเร็วผ่านการลากวาง (Drag & Drop) โดยทำงานบนเครื่อง 100% ออฟไลน์ มีความเป็นส่วนตัวสูง

---

## ✨ ฟีเจอร์หลัก (Key Features)

- 🚀 **Drag & Drop ฉับไว:** ลากไฟล์ภาพเดี่ยว หลายไฟล์ หรือทั้งโฟลเดอร์มาวางเพื่อแปลงอัตโนมัติ
- 🔄 **รองรับหลากหลายฟอร์แมต:**
  - **WebP:** แปลงภาพสำหรับเว็บไซต์ ขนาดเล็ก คมชัด
  - **HEIC:** ฟอร์แมตประสิทธิภาพสูงของ Apple
  - **JPEG:** ปรับระดับ Quality ได้ตั้งแต่ 10% ถึง 100%
  - **PNG:** บันทึกแบบ Lossless รักษาความโปร่งใส
  - **PDF:** รวมหลายภาพเข้าด้วยกันเป็นไฟล์ PDF หน้าเดียวหรือหลายหน้า
  - **ICNS:** แปลงรูปเป็น Mac App Icon สำหรับนักพัฒนา
- 📏 **ปรับสเกล & ย่อขนาด:** Presets 100%, 75%, 50%, 25%, Max 1920px, Max 1280px
- 🛡️ **Strip Metadata:** ตัวเลือกลบข้อมูล EXIF / พิกัด GPS ก่อนแชร์
- 📌 **Always on Top:** ปักหมุดหน้าต่างให้ลอยอยู่บนสุดของหน้าจอได้ ไม่ต้องสลับหน้าต่างไปมา
- 🍏 **Menu Bar Integration:** มีไอคอนบน Menu Bar สำหรับลากไฟล์แปลงด่วน

---

## 🛠️ วิธีการเปิดใช้งาน (How to Run)

### วิธีที่ 1: เปิดใช้งานผ่าน `.app` Bundle
แอปถูกคอมไพล์และแพ็กเกจไว้ในโฟลเดอร์ `DropMorph/` เรียบร้อยแล้ว:
```bash
open "DropMorph/DropMorph.app"
```
*(หรือสามารถลาก `DropMorph.app` ไปวางในโฟลเดอร์ `/Applications` ของเครื่องได้เลย)*

### วิธีที่ 2: รันผ่าน Swift Command Line (สำหรับ Development)
```bash
cd DropMorph
swift run
```

### วิธีที่ 3: รันการทดสอบ (Automated Unit Tests)
```bash
cd DropMorph
swift test
```

### วิธีที่ 4: Re-package แอปใหม่เมื่อมีการแก้ไขโค้ด
```bash
cd DropMorph
./scripts/package_app.sh
```

---

## 📂 โครงสร้างโฟลเดอร์ (Project Structure)

```
DropMorph/
├── DropMorph.app/             # macOS App Bundle พร้อมใช้งาน
├── Package.swift              # Swift Package Manager Manifest
├── Sources/
│   ├── DropMorph/             # Executable App Entry Point
│   │   └── DropMorphApp.swift # WindowGroup & MenuBarExtra Configuration
│   └── DropMorphCore/         # Core Framework
│       ├── Models/            # Data Models (OutputFormat, ConversionSettings, ConversionItem)
│       ├── Services/          # Hardware Engines (ImageConverter, PDFMerger)
│       ├── ViewModels/        # ConversionViewModel (State Management & Drag/Drop)
│       └── Views/             # SwiftUI Glassmorphic Views (Dashboard, DropZone, SettingsBar)
├── Tests/
│   └── DropMorphTests/        # Automated XCTest Suite
├── Resources/
│   └── Info.plist             # macOS App Metadata
└── scripts/
    └── package_app.sh         # Script สำหรับ build release & codesign .app
```

---

## 💡 สำหรับการสร้างแอปอื่นๆ เพิ่มเติมใน Workspace
โครงสร้างโฟลเดอร์หลัก `/Users/panpan/Mac project` ถูกออกแบบให้เป็น Multi-project Workspace:
- แต่ละแอปจะแยกอยู่ในโฟลเดอร์ของตัวเอง เช่น `DropMorph/`, `App2/`, `App3/`
- สามารถสร้างโปรเจกต์ใหม่ได้ตลอดเวลาโดยไม่ปะปนกับ `DropMorph`
