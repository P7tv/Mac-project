# DeskExtend 🖥️⚡️

**DeskExtend** เป็นแอปพลิเคชัน macOS พัฒนาด้วยภาษา **Swift 6 & SwiftUI** ที่แปลงคอมพิวเตอร์เครื่องอื่น (เช่น คอมพิวเตอร์ Windows ที่ต่อจอ DisplayPort อยู่) ให้กลายเป็น **"หน้าจอที่ 2 แบบแยกแท้ๆ (Extended Display)"** ของ Mac แบบ Real-time (60 FPS) โดยทำงานได้ **100% Offline (ไม่ต้องใช้อินเทอร์เน็ต)** และฝั่งคอมพิวเตอร์ปลายทาง **ไม่ต้องติดตั้งโปรแกรมใดๆ (Zero-Install)**

---

## 🌟 ฟีเจอร์เด่น (Key Features)

- 🖥️ **True Extended Display (จอแยกแท้ๆ):** ใช้ CoreGraphics `CGVirtualDisplay` สร้างจอระดับฮาร์ดแวร์ใน macOS จริง สามารถเข้าไปที่ `System Settings -> Displays` เพื่อจัดเรียงตำแหน่งหน้าจอ (วางไว้ทางซ้าย/ขวา/บน/ล่าง) ลากหน้าต่างโปรแกรม และเลื่อนเคอร์เซอร์เมาส์ของ Mac ข้ามจอได้อย่างเป็นธรรมชาติ
- ⚡️ **Real-Time 60 FPS (Ultra-Low Latency):** จับภาพเฟรมตรงจาก GPU และบีบอัดภาพแบบฮาร์ดแวร์ ส่งผ่าน Local WebSocket ความเร็วสูง ให้ความรู้สึกตอบสนองทันใจ (Latency < 20-30 ms)
- 🔌 **100% Offline & สายตรง (Direct Cable):**
  - **สายตรง (Direct Cable / เร็วที่สุด):** เสียบสาย LAN หรือสาย USB-C เชื่อมตรงระหว่าง Mac กับ PC (Link-Local IP `169.254.x.x`) จะได้ความเร็วระดับ Gigabit และ Latency ต่ำสุดๆ (5–15 ms)
  - **Wi-Fi เครือข่ายเดียวกัน:** ใช้งานได้ทันทีผ่าน Router ทั่วไป (แม้ไม่มีอินเทอร์เน็ตก็ตาม)
  - **Mac Hotspot:** เปิด Personal Hotspot จาก Mac ให้ PC เชื่อมตรงได้เลยโดยไม่ต้องมี Router
- 🌐 **Zero-Install ฝั่ง Windows:** คอมพิวเตอร์ Windows ไม่ต้องลงโปรแกรมอะไรเพิ่ม แค่เปิด Chrome หรือ Edge เข้า URL ที่ Mac แสดง แล้วกด **`F11`** เต็มจอ Monitor นั้นจะกลายเป็นจอที่สองของ Mac ทันที!

---

## 🚀 วิธีการใช้งาน (How to Use)

### 1. เปิดแอปบน Mac
ดับเบิลคลิกเปิด [DeskExtend.app](file:///Applications/DeskExtend.app) ในโฟลเดอร์ Applications หรือรันคำสั่ง:
```bash
open "/Applications/DeskExtend.app"
```

### 2. กดปุ่ม "Start Extended Display"
- หน้าจอจะเริ่มสร้างจอเสมือน และแสดงที่อยู่ IP (เช่น `http://192.168.1.50:8080` หรือ `http://169.254.x.x:8080`)

### 3. เปิดบนเครื่อง Windows
- บนคอมพิวเตอร์ Windows: เปิดเว็บเบราว์เซอร์ (Google Chrome, Microsoft Edge, หรือ Firefox)
- พิมพ์ URL ที่แสดงบนหน้าจอ Mac ลงในช่องแอดเดรส
- กด **`F11`** (หรือคลิกที่หน้าจอ) เพื่อเข้าสู่โหมด Fullscreen เต็มจอ
- **เรียบร้อย!** หน้าจอที่ต่อกับคอม Windows จะกลายเป็นจอที่สองของ Mac ทันที!

### 4. จัดตำแหน่งหน้าจอใน Mac
- ในแอป DeskExtend กดปุ่ม **"Arrange Displays in macOS"** หรือเข้าไปที่ *System Settings -> Displays*
- ลากไอคอนหน้าจอ DeskExtend ไปวางไว้ทางซ้ายหรือขวาของจอ Mac ตามตำแหน่งที่ตั้งโต๊ะจริง

---

## 🛠️ โครงสร้างโปรเจกต์ (Architecture)

```
DeskExtend/
├── DeskExtend.app/            # macOS App Bundle พร้อมใช้งานใน /Applications
├── Package.swift              # Swift Package Manager Manifest
├── Sources/
│   ├── DeskExtendBridge/      # Objective-C Bridge สำหรับ CGVirtualDisplay (CoreGraphics)
│   ├── DeskExtendCore/        # Logic & Core Services
│   │   ├── Models/            # DisplayConfig, DisplayResolution
│   │   ├── Services/          # VirtualDisplayManager, ScreenCaptureEngine, StreamServer, NetworkInterfaceHelper
│   │   ├── Resources/         # WebReceiver (Embedded Offline HTML5 Canvas Client)
│   │   ├── ViewModels/        # DeskExtendViewModel
│   │   └── Views/             # SwiftUI Glassmorphic UI (DashboardView, ConnectionCardView, DisplaySettingsBar)
│   └── DeskExtend/            # Executable App Entry Point & MenuBarExtra
├── Tests/
│   └── DeskExtendTests/       # Automated Unit Tests
├── Resources/
│   └── Info.plist, AppIcon.icns
└── scripts/
    └── package_app.sh         # Script สำหรับ build release & codesign .app
```
