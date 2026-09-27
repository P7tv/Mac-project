# Design Document: RarPeek Password Recovery Assistant

## 1. Overview
The **Password Recovery Assistant** is a built-in feature for **RarPeek** (macOS RAR and multi-archive manager) designed to help users unlock password-protected archives (RAR, 7Z, ZIP, etc.) when they have forgotten or misplaced the password.

Since modern archives employ cryptographic algorithms (AES-128 / AES-256) with no backdoors, unlocking requires testing candidate passwords. The assistant runs high-performance verification tasks in the background with native macOS UI feedback.

---

## 2. Architecture & Components

### 2.1 Backend: `PasswordRecoveryEngine` (Actor / Service)
- **Role**: Concurrently tests candidate passwords against an archive without extracting large payloads to disk.
- **Verification Mechanism**:
  - Uses `unar -f -p "<password>" -t "<archive_path>"` with output redirected to Pipe.
  - Return code `0` (`OK.`) confirms the correct password.
  - Return code `1` with decrunching / checksum / wrong password failure indicates invalid password.
  - Detection of truncated/corrupted archive errors (e.g., `Attempted to read more data than was available`) surfaces an immediate warning that the archive is incomplete.
- **Recovery Strategies**:
  1. **Top Common Passwords**: Curated built-in wordlist (~150 common passwords, default credentials, popular archive release strings, Thai/international forum defaults like `1234`, `123456`, `password`, `clip`, `vip`, `hd`, etc.).
  2. **Numeric PIN Attack**: Range-based generator for 4-digit (`0000`–`9999`) or 6-digit (`000000`–`999999`) numbers.
  3. **Custom Clues / Wordlist**: User-provided list of words, names, or candidate strings (comma or newline separated).
- **Concurrency & Control**:
  - Swift concurrency (`Task` & `TaskGroup` or async stream) allowing graceful Pause, Resume, and Cancellation.
  - Live performance metrics reporting: attempts count, total count, elapsed time, candidates/sec, and current candidate string.

### 2.2 ViewModel: `PasswordRecoveryViewModel`
- Manages state of the recovery process:
  - `selectedMode`: `.common`, `.numericPin`, `.customWords`
  - `pinLength`: 4 or 6 digits
  - `customWordsInput`: multiline String
  - `status`: `.idle`, `.running`, `.paused`, `.found(String)`, `.exhausted`, `.error(String)`
  - `progress`: Double (0.0 to 1.0)
  - `testedCount`: Int
  - `totalCount`: Int
  - `currentCandidate`: String
  - `speed`: Double (candidates per second)
- Actions:
  - `startRecovery()`
  - `cancelRecovery()`
  - `applyFoundPassword()`: transfers discovered password to `ArchiveViewModel.passwordInput` and triggers archive extraction/loading.

### 2.3 UI: `PasswordRecoverySheet`
- **Presentation**:
  - Presented as a sheet from `PasswordPromptView` (via a *"⚡ Recover Password"* button) and from `ArchiveInspectorView` toolbar badge.
- **Sections**:
  - Mode Picker: Top Common | Numeric PIN | Custom Words
  - Options panel per mode (e.g. 4-digit vs 6-digit toggle, text editor for custom words)
  - Status display card with active progress indicator, elapsed time, current candidate
  - Found banner (vibrant green with copy & instant unlock button)
  - Action buttons: Start, Cancel / Close

---

## 3. Data Flow
1. User encounters encrypted archive and opens `PasswordRecoverySheet`.
2. User picks mode (default: Top Common) and clicks **Start Recovery**.
3. `PasswordRecoveryViewModel` feeds candidate stream to `PasswordRecoveryEngine`.
4. Engine tests candidates in background, publishing updates to the main actor.
5. If found:
   - Play system feedback sound.
   - Display success screen with the found password.
   - Button "Apply & Unlock Archive" automatically unlocks the archive and opens contents in RarPeek.
6. If corrupted/truncated archive detected:
   - Alert informs user that the archive is incomplete (e.g. missing parts or cut-off download).

---

## 4. Testing & Verification
- Unit tests for `PasswordRecoveryEngine` verifying:
  - Detection of correct password on encrypted test archives.
  - Rejection of incorrect passwords.
  - Proper cancellation of running tasks.
- UI build & integration test in `RarPeek`.
