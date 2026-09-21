# Smart Biblio - Premium RFID Library Management System (.exe Windows)

![Platform](https://img.shields.io/badge/Platform-Windows%2011%20x64-blue)
![Framework](https://img.shields.io/badge/Framework-Flutter%203.44-02569B?logo=flutter)
![Language](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart)
![Hardware](https://img.shields.io/badge/Hardware-Fongwah%20U1--CU--71%20UHF%20RFID-00D2FF)
![Database](https://img.shields.io/badge/Database-SQLite%20FFI-003B57?logo=sqlite)
![Tests](https://img.shields.io/badge/Tests-34%20Passing%20(9%20Suites)-10B981)

Smart Biblio is a commercial-grade, standalone Windows desktop application (`smart_biblio.exe`) designed for university and institutional libraries. It seamlessly integrates with the **Fongwah U1-CU-71 UHF RFID Reader/Writer** via high-speed native 64-bit C-bindings (`E7umf.dll`), backed by a built-in Virtual RFID Simulator for development and testing.

---

## Key Features

### 1. Student Touchscreen Self-Service Kiosk
- **Dark Glassmorphic UI**: High-framerate responsive interface with custom electromagnetic wave radar animation.
- **Contactless Student Card Tap**: Instant recognition of student RFID cards (`EPC / UID`).
- **Interactive Multi-Tag Borrowing**: Real-time continuous antenna scanning with dynamic status badges (`Available`, `Already Borrowed`, `Limit Exceeded`).
- **Rapid Multi-Tag Returns**: Drop-off scanning with automatic active loan resolution and overdue fine calculations.
- **Session Security**: 45-second inactivity auto-countdown with warning beeps and instant reset/exit.
- **Interactive Simulation Dock**: Collapsible testing dock to simulate student card taps, book placements, and clear fields without physical hardware attached.

### 2. Librarian Back-Office Management Suite (`Ctrl+Shift+A`, PIN: `1234`)
- **Executive Operations Dashboard**: Real-time KPI tiles (total books, active loans, overdue items, registered students) with live hardware status and an event audit trail.
- **Catalog & Physical Copies**: Searchable catalog with expandable copies, barcode mapping, and RFID EPC assignments.
- **Student Directory & Card Issuance**: Student management with card assignment and instant replacement for lost cards.
- **Circulation & Fines Center**: Status-based loan tracking, one-click 14-day renewals (`[ RENEW (+14D) ]`), and fine settlement (`[ MARK PAID ]` / `[ WAIVE ]`).
- **RFID Diagnostics & Encoding Center**:
  - Direct hardware actions (`uhf_action`): Beep buzzer (`0x01`), Green LED (`0x04`), Red LED (`0x02`), Yellow LED (`0x08`).
  - Raw Gen2 memory bank inspector (`uhf_read`): Inspect EPC, TID, USER, and Reserved banks.
  - UHF Tag Writer & Encoder: Burn 24-character hex EPCs onto physical tag labels with immediate write verification and batch conveyor mode.
  - Real-Time Smart Shelf Inventory Scanner: Live 4-way classification (`Present`, `Missing`, `Misplaced`, `Unknown`) with percentage completion badges.
- **Governance & Data Exports**:
  - Configurable lending policies, fine rates, timeout preferences, and reader defaults.
  - Full audit trail with action filtering and keyword search.
  - One-click CSV export center for Audit Logs, Circulation Reports, and Catalog Inventory.

---

## Hardware Integration Architecture

- **Driver Binding**: Dart FFI (`package:ffi`) directly communicates with 64-bit `E7umf.dll` (`uhf_connect`, `uhf_disconnect`, `uhf_inventory`, `uhf_read`, `uhf_write`, `uhf_action`).
- **Tag Debouncer**: Dual-window debouncing prevents duplicate RFID read storms during continuous scanning.
- **Virtual RFID Simulator**: Graceful automatic fallback when physical reader is disconnected, ensuring the software runs on any PC.

---

## Getting Started & Building

### Prerequisites
- Windows 10/11 x64
- Flutter 3.44.0+ (with Windows desktop support enabled)
- Visual Studio 2022/2026 C++ tools

### Running in Development Mode
```powershell
cd smart_biblio
flutter run -d windows
```

### Running Automated Test Suites (34 Tests)
```powershell
cd smart_biblio
flutter test
```

### Compiling Standalone Release Executable
```powershell
cd smart_biblio
flutter build windows --release
```

The compiled standalone executable and bundled libraries will be generated in:
```
smart_biblio/build/windows/x64/runner/Release/
├── smart_biblio.exe
├── E7umf.dll
├── sqlite3.dll
├── flutter_windows.dll
└── data/
```

---

## License
Proprietary / Commercial University Library Management System.
