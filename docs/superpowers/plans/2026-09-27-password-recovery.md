# Password Recovery Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, multi-threaded Password Recovery Assistant into RarPeek to help users recover or test forgotten passwords on encrypted archives (RAR, 7Z, ZIP) with live UI feedback.

**Architecture:** A lightweight actor-based `PasswordRecoveryEngine` that tests candidates in the background using `unar -f -p <candidate> -t <archive>`, bound to a `PasswordRecoveryViewModel` and presented in a sleek macOS `PasswordRecoverySheet`.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Process/unar CLI engine.

## Global Constraints
- Platform: macOS 13.0+ (Apple Silicon native)
- Uses bundled or system `unar` with `-f -t` non-destructive test mode
- Graceful cancellation and task isolation
- Responsive UI without blocking the MainActor

---

### Task 1: Core Engine (`PasswordRecoveryEngine`) & Unit Tests

**Files:**
- Create: `RarPeek/Sources/RarPeekCore/Services/PasswordRecoveryEngine.swift`
- Test: `RarPeek/Tests/RarPeekTests/PasswordRecoveryEngineTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum PasswordTestResult: Equatable, Sendable {
      case valid
      case invalid
      case corrupted(String)
      case binaryNotFound
  }

  public enum RecoveryStrategy: Sendable {
      case commonPasswords
      case numericPin(length: Int) // 4 or 6 digits
      case customList([String])
  }

  public struct RecoveryProgress: Sendable {
      public let testedCount: Int
      public let totalCount: Int
      public let currentCandidate: String
      public let speed: Double // candidates/sec
  }

  public final class PasswordRecoveryEngine: @unchecked Sendable { ... }
  ```

- [ ] **Step 1: Write the failing unit tests for `PasswordRecoveryEngine`**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `PasswordRecoveryEngine.swift`**
- [ ] **Step 4: Run unit tests to verify they pass**
- [ ] **Step 5: Commit changes**

---

### Task 2: ViewModel (`PasswordRecoveryViewModel`) & `ArchiveViewModel` Integration

**Files:**
- Create: `RarPeek/Sources/RarPeekCore/ViewModels/PasswordRecoveryViewModel.swift`
- Modify: `RarPeek/Sources/RarPeekCore/ViewModels/ArchiveViewModel.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor
  public final class PasswordRecoveryViewModel: ObservableObject {
      @Published public var selectedStrategy: RecoveryStrategyType = .common
      @Published public var pinLength: Int = 4
      @Published public var customWordsText: String = ""
      @Published public var isRunning: Bool = false
      @Published public var progress: Double = 0.0
      @Published public var testedCount: Int = 0
      @Published public var totalCount: Int = 0
      @Published public var currentCandidate: String = ""
      @Published public var candidatesPerSecond: Double = 0.0
      @Published public var foundPassword: String? = nil
      @Published public var statusMessage: String = ""
      @Published public var errorMessage: String? = nil

      public func startRecovery(for archiveURL: URL) async
      public func cancel()
  }
  ```

- [ ] **Step 1: Write `PasswordRecoveryViewModel.swift`**
- [ ] **Step 2: Connect `ArchiveViewModel` to show `isShowingRecoverySheet` and receive `foundPassword`**
- [ ] **Step 3: Run unit tests to verify compilation and behavior**
- [ ] **Step 4: Commit changes**

---

### Task 3: UI (`PasswordRecoverySheet`) & Inspector Integration

**Files:**
- Create: `RarPeek/Sources/RarPeekCore/Views/PasswordRecoverySheet.swift`
- Modify: `RarPeek/Sources/RarPeekCore/Views/PasswordPromptView.swift`
- Modify: `RarPeek/Sources/RarPeekCore/Views/ArchiveInspectorView.swift`

- [ ] **Step 1: Create `PasswordRecoverySheet.swift` with mode selector, progress gauge, candidate ticker, and found alert**
- [ ] **Step 2: Add "⚡ Recover Password" button to `PasswordPromptView.swift`**
- [ ] **Step 3: Add recovery sheet presentation and toolbar button to `ArchiveInspectorView.swift`**
- [ ] **Step 4: Test build and UI rendering**
- [ ] **Step 5: Commit changes**

---

### Task 4: Packaging, Test Suite & Deployment to `/Applications/RarPeek.app`

**Files:**
- Build script: `RarPeek/scripts/package_app.sh`
- Target: `/Applications/RarPeek.app`

- [ ] **Step 1: Run full test suite (`swift test`)**
- [ ] **Step 2: Run `./scripts/package_app.sh` to package app bundle**
- [ ] **Step 3: Sync new app bundle to `/Applications/RarPeek.app`**
- [ ] **Step 4: Verify binary launch and commit final artifacts**
