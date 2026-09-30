# Live Speech Chunking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show low-latency translation previews while accumulating enough sentence context to replace them with coherent final translations.

**Architecture:** AudioTranscriptionEngine emits immutable recognition snapshots with session and stream identities plus timed segment metadata. SpeechChunker reconciles cumulative snapshots into an open sentence, pause previews, and finalized sentences; AppState owns the pause/checkpoint timers and latest-request gate. TyphoonService receives the previous completed sentence as context but is instructed to translate only the current sentence.

**Tech Stack:** Swift 5.9, macOS 13+, SwiftUI, Speech, NaturalLanguage, Foundation, XCTest, TyphoonService/URLSession.

## Global Constraints

- English and Thai are the primary languages. Japanese and Chinese remain secondary supported languages.
- Use speech timing and language boundaries rather than a fixed word-count threshold.
- Keep memory in RAM and bounded to the current sentence plus one completed sentence of context.
- Use a 350 ms pause preview and a four-second preview checkpoint.
- Replace older previews and ignore translation responses that arrive out of order.
- Do not add third-party dependencies or persist transcript/translation memory.
- Keep the app's macOS 13 minimum deployment target and Swift tools 5.9.

---

## Workspace Note

The Git repository root is /Users/panpan/Mac project; the Swift package is /Users/panpan/Mac project/GhostTranslate. Run Swift commands from GhostTranslate and git add/commit commands from the repository root. The working tree already has uncommitted edits in AudioTranscriptionEngine.swift, SpeechChunker.swift, AppState.swift, SpeechChunkerTests.swift, several UI files, Info.plist, and a DeskExtend binary. Build on the current GhostTranslate source state. Do not stage or change the unrelated DeskExtend binary or unrelated UI/Info.plist edits. Each commit below must list only the files named in that task.

## File Map

- Create Sources/GhostTranslateCore/Audio/SpeechRecognitionSnapshot.swift for pure value types representing recognition sessions, streams, timed segments, events, and sentence translation inputs.
- Create Sources/GhostTranslateCore/Audio/RecognitionSessionTracker.swift for explicit user-session and recognition-stream identities.
- Modify Sources/GhostTranslateCore/Audio/AudioTranscriptionEngine.swift to create session/stream identities and map Apple Speech results to snapshots.
- Extend RecognitionSessionTracker to identify active streams and reject callbacks from obsolete streams.
- Modify Sources/GhostTranslateCore/Audio/SpeechChunker.swift to reconcile revised snapshots, detect language-aware boundaries, keep sentence memory, and emit preview/final inputs.
- Modify Sources/GhostTranslateCore/State/AppState.swift to schedule pause/checkpoint previews, add context to requests, and reject stale responses.
- Modify Sources/GhostTranslateCore/AI/Prompts.swift and Sources/GhostTranslateCore/AI/TyphoonService.swift to pass prior-sentence context while translating only the current sentence.
- Modify Tests/GhostTranslateTests/SpeechChunkerTests.swift, Tests/GhostTranslateTests/AudioTranscriptionTests.swift, and Tests/GhostTranslateTests/TyphoonServiceTests.swift for deterministic regression coverage.
- Create Tests/GhostTranslateTests/TranslationPreviewGateTests.swift for request-order behavior independent of network calls.
- Create Tests/GhostTranslateTests/AppStateRecognitionTests.swift for clear/restart and finalized interview-question routing.

## Shared Interfaces

Task 1 defines these exact types for later tasks:

```swift
public struct SpeechSegmentTiming: Equatable {
    public let substringRange: NSRange
    public let timestamp: TimeInterval
    public let duration: TimeInterval
    public var endTime: TimeInterval { timestamp + duration }
}

public struct SpeechRecognitionSnapshot: Equatable {
    public let sessionID: UUID
    public let streamID: UUID
    public let localeIdentifier: String
    public let transcript: String
    public let isFinal: Bool
    public let receivedAtUptime: TimeInterval
    public let segments: [SpeechSegmentTiming]
}

public struct RecognitionStreamIdentity: Equatable {
    public let sessionID: UUID
    public let streamID: UUID
}

public enum SpeechRecognitionEvent: Equatable {
    case snapshot(SpeechRecognitionSnapshot)
    case sessionEnded(sessionID: UUID)
}

public struct SentenceTranslationInput: Equatable {
    public let text: String
    public let context: String?
}

public struct SpeechChunkingUpdate: Equatable {
    public let revision: UInt64
    public let preview: SentenceTranslationInput?
    public let finalized: [SentenceTranslationInput]
}
```

SpeechChunker exposes:

```swift
public func process(_ event: SpeechRecognitionEvent) -> SpeechChunkingUpdate
public func previewCurrentSentence(sessionID: UUID, expectedRevision: UInt64) -> SentenceTranslationInput?
public func reset()
```

`process` finalizes complete sentences in order. It returns an immediate preview when a sentence boundary or a timed internal pause qualifies. AppState calls `previewCurrentSentence` after its 350 ms inactivity timer or four-second checkpoint. On an automatic stream rollover, a new streamID resets the transcript-snapshot baseline while the same sessionID preserves the open sentence and one-sentence context. A sessionEnded event flushes the open sentence once and clears its context.

---

### Task 1: Define Recognition Snapshots and Rebuild SpeechChunker State

**Files:**
- Create: Sources/GhostTranslateCore/Audio/SpeechRecognitionSnapshot.swift
- Modify: Sources/GhostTranslateCore/Audio/SpeechChunker.swift
- Test: Tests/GhostTranslateTests/SpeechChunkerTests.swift

**Interfaces:**
- Consumes: Existing cumulative transcript callbacks and the approved design in docs/superpowers/specs/2026-10-01-live-speech-chunking-design.md.
- Produces: The shared snapshot/event/update types above and a deterministic SpeechChunker API for Tasks 2 and 3.

- [x] **Step 1: Add failing tests for pause previews, sentence memory, and revisions**

Add tests that instantiate snapshots directly; do not use a microphone or wall-clock sleeps.

```swift
func testPreviewUsesWholeOpenSentenceAndFinalizesWithContext() {
    let chunker = SpeechChunker()
    let sessionID = UUID()
    let streamID = UUID()

    let first = SpeechRecognitionSnapshot(
        sessionID: sessionID,
        streamID: streamID,
        localeIdentifier: "en-US",
        transcript: "I joined the company",
        isFinal: false,
        receivedAtUptime: 1.0,
        segments: []
    )
    let firstUpdate = chunker.process(.snapshot(first))
    XCTAssertEqual(
        chunker.previewCurrentSentence(sessionID: sessionID, expectedRevision: firstUpdate.revision)?.text,
        "I joined the company"
    )

    let final = SpeechRecognitionSnapshot(
        sessionID: sessionID,
        streamID: streamID,
        localeIdentifier: "en-US",
        transcript: "I joined the company. I work on search.",
        isFinal: true,
        receivedAtUptime: 2.0,
        segments: []
    )
    let finalUpdate = chunker.process(.snapshot(final))
    XCTAssertEqual(finalUpdate.finalized.map(\.text), ["I joined the company.", "I work on search."])
    XCTAssertEqual(finalUpdate.finalized[1].context, "I joined the company.")
}
```

- [x] **Step 2: Run the focused tests and confirm the new API/behavior fails to compile or fails assertions**

Run from GhostTranslate: `swift test --filter SpeechChunkerTests`
Expected: FAIL because the snapshot types and snapshot-based SpeechChunker methods do not exist yet.

- [x] **Step 3: Add the recognition value types**

In SpeechRecognitionSnapshot.swift, implement the shared snapshot, event, segment timing, stream identity, sentence input, and chunking update types. Keep this file Foundation-only so the state machine tests can construct recognition results without importing Speech or accessing a microphone.

- [x] **Step 4: Implement snapshot reconciliation and boundary handling**

Replace emittedChunksCount with state for the active sessionID, streamID, last transcript snapshot, current sentence buffer, previous finalized sentence, committed source prefix, and revision number. On the same stream, replace the open snapshot when ASR revises it. On a new stream in the same session, reset only the stream transcript baseline and append new recognized text to the open sentence without duplicating the carried text. On sessionEnded, finalize the remaining sentence and clear context.

Use NaturalLanguage token ranges only as safe cut points. Select the earliest valid sentence-ending punctuation by its position in the source text; recognize `.?!` for English/Thai and `。？！` for the secondary Japanese/Chinese path. Detect internal pauses from adjacent segment end/start times with a 350 ms gap. Do not impose a word-count threshold. Keep the four-second checkpoint's full sentence buffer intact so subsequent words can produce a revised complete preview.

- [x] **Step 5: Add and run regression tests for revisions, stream rollover, and Unicode boundaries**

Add assertions for: changed partial text replacing the open sentence; the first sentence after a new stream not being suppressed; no repeated finalized sentence; a timed pause preview; punctuation order; Thai safe token boundaries; Japanese/Chinese punctuation; and sessionEnded flushing exactly once.

Run: `swift test --filter SpeechChunkerTests`
Expected: all SpeechChunkerTests pass, including the existing punctuation and streaming-sequence tests.

- [x] **Step 6: Commit Task 1 only**

```bash
git add GhostTranslate/Sources/GhostTranslateCore/Audio/SpeechRecognitionSnapshot.swift GhostTranslate/Sources/GhostTranslateCore/Audio/SpeechChunker.swift GhostTranslate/Tests/GhostTranslateTests/SpeechChunkerTests.swift
git commit -m "feat: reconcile speech transcript chunks"
```

### Task 2: Emit Timed Snapshots from AudioTranscriptionEngine

**Files:**
- Create: Sources/GhostTranslateCore/Audio/RecognitionSessionTracker.swift
- Modify: Sources/GhostTranslateCore/Audio/AudioTranscriptionEngine.swift
- Modify: Tests/GhostTranslateTests/AudioTranscriptionTests.swift
- Consume: RecognitionStreamIdentity, SpeechRecognitionEvent, and SpeechRecognitionSnapshot from Task 1.

**Interfaces:**
- Consumes: RecognitionStreamIdentity, SpeechRecognitionEvent, and SpeechRecognitionSnapshot from Task 1.
- Produces: `public var onRecognitionEvent: ((SpeechRecognitionEvent) -> Void)?` for AppState.
- Produces: `RecognitionSessionTracker.beginSession() -> RecognitionStreamIdentity`, `beginStream() -> RecognitionStreamIdentity`, and `endSession() -> UUID?`.

- [x] **Step 1: Add failing tests for session/stream identity behavior**

Add failing tests for the pure RecognitionSessionTracker in AudioTranscriptionTests. Assert that a second beginStream keeps the session ID but changes the stream ID, while endSession followed by beginSession creates a different session ID.

Run: `swift test --filter AudioTranscriptionTests`
Expected: FAIL until the tracker exists.

- [x] **Step 2: Replace the string-only callback with recognition events**

When a result arrives, map `bestTranscription.formattedString`, `result.isFinal`, `bestTranscription.segments[*].substringRange`, `timestamp`, and `duration` into SpeechRecognitionSnapshot. Set `receivedAtUptime` from `ProcessInfo.processInfo.systemUptime`.

Start a new session for explicit listening starts. Create a new streamID for each recognition task. `restartContinuousStream()` must preserve sessionID and create only a new streamID. Explicit stop and locale change emit one sessionEnded event. Refactor internal engine teardown so an automatic restart does not emit a user-session end event. Map every SFTranscriptionSegment's substringRange, timestamp, and duration to SpeechSegmentTiming.

- [x] **Step 3: Run focused audio tests and the core test target**

Run: `swift test --filter AudioTranscriptionTests`
Expected: all audio engine initialization, locale, and tracker tests pass without microphone access.

Run: `swift test`
Expected: the complete GhostTranslate test suite passes on macOS.

- [x] **Step 4: Commit Task 2 only**

```bash
git add GhostTranslate/Sources/GhostTranslateCore/Audio/RecognitionSessionTracker.swift GhostTranslate/Sources/GhostTranslateCore/Audio/AudioTranscriptionEngine.swift GhostTranslate/Tests/GhostTranslateTests/AudioTranscriptionTests.swift
git commit -m "feat: emit timed speech recognition snapshots"
```

### Task 3: Add Sentence-Context Previews and Latest-Request Handling

**Files:**
- Modify: Sources/GhostTranslateCore/State/AppState.swift
- Modify: Sources/GhostTranslateCore/AI/Prompts.swift
- Modify: Sources/GhostTranslateCore/AI/TyphoonService.swift
- Modify: Tests/GhostTranslateTests/TyphoonServiceTests.swift
- Create: Tests/GhostTranslateTests/TranslationPreviewGateTests.swift
- Consume: SpeechRecognitionEvent and SpeechChunkingUpdate from Tasks 1 and 2.

**Interfaces:**
- Produces: `Prompts.subtitleUserPrompt(currentSentence: String, contextSentence: String?) -> String`.
- Produces: `TyphoonService.translateSubtitle(text: String, context: String? = nil) async throws -> String`.
- Produces: `LatestTranslationGate.issue() -> UInt64`, `accepts(_:) -> Bool`, and `invalidate()` for latest-wins response checks.

- [x] **Step 1: Add failing prompt and latest-request gate tests**

```swift
func testContextPromptAsksToTranslateOnlyCurrentSentence() {
    let prompt = Prompts.subtitleUserPrompt(
        currentSentence: "I shipped the feature.",
        contextSentence: "We discussed the launch yesterday."
    )
    XCTAssertTrue(prompt.contains("We discussed the launch yesterday."))
    XCTAssertTrue(prompt.contains("I shipped the feature."))
    XCTAssertTrue(prompt.contains("current sentence only"))
}

func testOlderTranslationTicketIsRejected() {
    var gate = LatestTranslationGate()
    let older = gate.issue()
    let newer = gate.issue()
    XCTAssertFalse(gate.accepts(older))
    XCTAssertTrue(gate.accepts(newer))
}
```

Run: `swift test --filter TyphoonServiceTests` and `swift test --filter TranslationPreviewGateTests`
Expected: both commands fail until the prompt builder and request gate exist.

- [x] **Step 2: Implement context-aware prompt construction**

Add `Prompts.subtitleUserPrompt(currentSentence:contextSentence:)`. If context exists, include it as context-only and explicitly request translation of the current sentence only. Update subtitleSystemPrompt with the same no-duplicate constraint. Extend TyphoonService.translateSubtitle with an optional context argument and pass the constructed user prompt to sendChatCompletion. Calls without context keep their current behavior.

- [x] **Step 3: Wire recognition events, preview timers, and stale-response guard into AppState**

Replace setupAudioCallbacks' string callback with an event switch. For changed snapshots, call SpeechChunker.process, schedule a cancellable 350 ms inactivity preview keyed to sessionID and revision, and schedule a four-second checkpoint from the start of the open sentence. Preview requests use the full open sentence plus the previous finalized sentence as context. Finalized sentences rotate context and update the subtitle result. Deduplicate identical preview text.

Before each translation await, obtain a LatestTranslationGate ticket. Apply translatedText, previousLine, or interviewResult only when that ticket remains current. Invalidate tickets and cancel both timers on clear or session end. On automatic streamID rollover, preserve the sentence memory; on explicit session end or locale change, flush once and clear context.

- [x] **Step 4: Run focused tests and add deterministic lifecycle regressions**

Add tests that invalidating a ticket rejects pending work, a finalized sentence becomes the next preview's context, clear empties sentence context, and duplicate snapshots do not schedule duplicate preview input. Keep timers testable by exercising pure chunker/gate methods; do not use wall-clock sleeps or live network calls in unit tests.

Run: `swift test --filter SpeechChunkerTests`, `swift test --filter TyphoonServiceTests`, and `swift test --filter TranslationPreviewGateTests`
Expected: all focused test commands pass.

- [x] **Step 5: Run the full suite and review the scoped diff**

Run from GhostTranslate: `swift test`
Expected: all tests pass. Then inspect `git diff --check` and `git diff --stat`; confirm no DeskExtend, Info.plist, or unrelated UI changes were staged.

- [x] **Step 6: Commit Task 3 only**

```bash
git add GhostTranslate/Sources/GhostTranslateCore/State/AppState.swift GhostTranslate/Sources/GhostTranslateCore/AI/Prompts.swift GhostTranslate/Sources/GhostTranslateCore/AI/TyphoonService.swift GhostTranslate/Tests/GhostTranslateTests/TyphoonServiceTests.swift GhostTranslate/Tests/GhostTranslateTests/TranslationPreviewGateTests.swift
git commit -m "feat: add sentence-aware translation previews"
```

### Follow-up Audit

- Clearing now rotates the recognition stream while retaining the current user session. Tests verify the AppState clear path, fresh text on the next stream, and rejection of callbacks associated with the previous stream identity.
- Finalized multi-sentence interview questions are aggregated before Interview Co-pilot generation instead of sending only the final sentence to subtitle translation. Interview response parsing handles numbered and Unicode bullets, and the HUD shows AI errors.
- Removed the source-level fallback API key. Credentials now come only from the user's configured key, saved settings, or `TYPHOON_API_KEY`.
- Verification after follow-up changes: `swift test` passes all 35 tests; Release app packaging and installation are performed after committing these follow-ups.

## Plan Self-Review

- Snapshot shape, chunker API, preview context, lifecycle boundaries, timing triggers, and latest-response gate are defined before dependent tasks consume them.
- Every approved spec goal maps to Task 1, Task 2, or Task 3. The YouTube cue study informs variable timing but does not introduce a YouTube-specific dependency.
- No fixed word-count threshold is introduced. The 350 ms pause preview and four-second checkpoint match the approved spec.
- Tests use snapshots, timing values, prompt strings, and request tickets; they do not require microphone permission or live Typhoon credentials.
- All commit commands stage only the files listed in their task.
