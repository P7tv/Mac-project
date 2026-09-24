# 🧠 Codex ⟷ Antigravity Orchestrator

ระบบสั่งการโค้ดแบบ **Architect-Worker Pattern** ที่ให้ **OpenAI Codex** ทำหน้าที่เป็นมันสมองหลัก (วางแผน / แตกงาน) และควบคุม **Google Antigravity (`agy`)** ให้ทำหน้าที่เป็น Worker ลงมือแก้ไขโค้ดและรันเทสต์ในเครื่อง เพื่อประหยัด Token สูงสุด

---

## ⚡ ทำไมสถาปัตยกรรมนี้ถึงช่วยประหยัด Token ได้ 60-80%?

| รูปแบบเดิม (Monolithic Chat) | ระบบนี้ (Codex ⟷ Antigravity Orchestrator) |
|---|---|
| คุยในแชตยาวต่อเนื่อง ประวัติแชต + โค้ดสะสมจนบวมเป็นแสน Token | **Stateless Sessions**: แต่ละ Subtask เปิด session ใหม่ โค้ดเก่าไม่สะสม |
| ทุกคำถามต้องส่งบริบทและโค้ดทั้งหมดซ้ำทุกรอบ | **Token-Light Manifest**: Codex อ่านเฉพาะโครงสร้างโฟลเดอร์ ไม่ต้องโหลดทั้งไฟล์ |
| เสีย Token ให้ Terminal Log และผล Compile ยาวๆ | **Local Worker Filtering**: Antigravity เทสต์ในเครื่อง ส่งกลับแค่ Status สั้นๆ |

---

## 🚀 สถาปัตยกรรมการทำงาน (Architecture Flow)

```
[ User ป้อนโจทย์ใหญ่ ]
          │
          ▼
   [ 🧠 Codex ]  <--- อ่านเฉพาะ Directory Tree + Manifest สรุป
   (Master Architect)
          │
          ├─► สร้าง ExecutionPlan (JSON) แตกเป็น Task 1, 2, 3...
          │
          ▼
   [ ⚡ Antigravity ] <--- ได้รับ Prompt เฉพาะ Task ปัจจุบัน (Session ใหม่เสมอ)
   (Worker: agy CLI)
          │
          ├─► ลงมือแก้ไขไฟล์ตามเป้าหมาย
          ├─► รันคำสั่ง Verification (เช่น swift test, pytest)
          └─► รายงานสถานะ "SUCCESS (1.2s)" กลับมา
          │
          ▼
   [ 📊 Token Economy Report ]
   สรุปผลการรัน พร้อมคำนวณจำนวน Token ที่ประหยัดได้จริง
```

---

## 🛠️ การตั้งค่าเริ่มต้น (Setup)

1. เข้าไปยังโฟลเดอร์ `CodexOrchestrator`:
   ```bash
   cd "/Users/panpan/Mac project/CodexOrchestrator"
   ```

2. สร้างไฟล์ `.env` จาก `.env.example`:
   ```bash
   cp .env.example .env
   ```

3. ใส่ `OPENAI_API_KEY` ของคุณในไฟล์ `.env`:
   ```ini
   OPENAI_API_KEY=sk-your-openai-api-key-here
   CODEX_MODEL=gpt-4o
   AGY_PATH=/Users/panpan/.local/bin/agy
   ```

---

## 💻 ตัวอย่างการใช้งาน (Usage Examples)

### 1. สั่งงานพร้อมระบุโปรเจกต์เป้าหมาย:
```bash
python CodexOrchestrator/run.py "เพิ่มฟังก์ชันล้างประวัติการแปลงไฟล์ใน DropMorph" --target-dir "DropMorph"
```

### 2. โหมดทดลองวางแผนล่วงหน้า (Dry-run ไม่แก้ไฟล์จริง):
```bash
python CodexOrchestrator/run.py "ปรับ UI ปุ่มดาวน์โหลดใน AirBridge" --target-dir "AirBridge" --dry-run
```

### 3. โหมดอัตโนมัติเต็มรูปแบบ (Auto Mode ไม่ต้องรอกด Confirm):
```bash
python CodexOrchestrator/run.py "เขียน Unit Test เพิ่มสำหรับ PDFCompressor" --target-dir "DropMorph" --auto
```

---

## 📁 โครงสร้างโปรเจกต์
- `orchestrator.py`: หน้าตา CLI สวยงามด้วย Rich Console
- `planner.py`: เชื่อมต่อ OpenAI Codex เพื่อสแกนโปรเจกต์และวางแผนแบบ Structured JSON
- `worker.py`: ส่งคำสั่งย่อยให้ Antigravity (`agy` CLI) รันแบบ Headless อัตโนมัติ
- `token_tracker.py`: บันทึกการใช้งาน Token และคำนวณสถิติความประหยัด
- `config.py`: โหลดการตั้งค่าและ API Key
