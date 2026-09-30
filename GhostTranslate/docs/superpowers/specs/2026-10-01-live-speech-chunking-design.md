# Live Speech Chunking and Sentence Memory

- **Date:** 2026-10-01
- **Status:** Design approved in conversation; implementation not started.

## Context

GhostTranslate receives cumulative partial transcripts from Apple Speech. The current SpeechChunker reparses each snapshot, remembers only how many chunks it emitted, and uses punctuation, fixed word counts, and a short list of Thai conjunctions. This can lose track of revisions or stream restarts, delays some translations until a long phrase completes, and does not use the timing already available from recognition segments.

The user wants translations to appear quickly while speech is still in progress, with temporary sentence memory so the translation can be revised into a complete, coherent sentence. English and Thai are the primary languages. Japanese and Chinese remain secondary supported languages.

An English YouTube caption track was inspected as a timing and cue-length reference. It contained 229 timed cues; cue duration had a 2.24 second median, ranged from 1.08 to 6.10 seconds, and 40 cues contained four or fewer whitespace-separated words. This supports variable, time-aligned cue sizes rather than a fixed word count. The sample is a prerecorded video and does not establish YouTube's live-caption implementation. [TED example](https://www.youtube.com/watch?v=eIho2S0ZahI), [YouTube caption guidance](https://support.google.com/youtube/answer/2734796?hl=en).

## Goals

- Start translating before the speaker finishes a sentence.
- Keep a sentence buffer so previews use the whole sentence as it grows, rather than translating isolated fragments.
- Replace an older preview with a newer one and ignore translation responses that arrive out of order.
- Use speech timing and language boundaries rather than a fixed word-count threshold.
- Avoid losing or duplicating text when Apple Speech revises a partial result or restarts a recognition task.
- Keep memory in RAM and bounded to the current sentence plus one completed sentence of context.

## Non-goals

- Persistent transcript or translation history.
- Automatic language detection; the selected recognition locale remains the source language.
- Redesigning HUD visuals or unrelated audio and OCR behavior.
- Replacing Apple Speech or the Typhoon translation service.

## Design

### Recognition snapshot

AudioTranscriptionEngine will pass a value snapshot to AppState instead of only a string and final flag. The snapshot contains:

- A recognition-stream generation identifier.
- The selected locale.
- The full formatted transcript for the current recognition task.
- Whether the recognition result is final.
- The monotonic time when the app received this snapshot.
- Segment text ranges, start timestamps, and durations when Apple Speech provides them.

Apple documents each SFTranscriptionSegment as a discrete recognized utterance with a substring range, timestamp, and duration. [SFTranscriptionSegment](https://developer.apple.com/documentation/speech/sftranscriptionsegment), [SFTranscription](https://developer.apple.com/documentation/speech/sftranscription).

### Chunker and sentence memory

SpeechChunker remains a stateful, UI-independent component. It compares transcript snapshots by content and generation, not by the number of previously emitted chunks. It reconciles revisions in the open sentence and tracks finalized sentence boundaries so repeated snapshots do not create duplicate output.

It maintains two in-memory text values:

1. The complete sentence currently being spoken. This is the source sent for each preview update and is kept intact while the speaker pauses or crosses a preview checkpoint.
2. The immediately preceding finalized sentence, sent as translation context only. The translation prompt must return a translation of the current sentence alone, not repeat the context sentence.

The prior sentence is replaced when a new sentence is finalized. Neither value is persisted to disk.

### Boundary and preview behavior

- Use the earliest valid sentence-ending punctuation in the text. Recognize English and Thai punctuation first, and preserve Japanese and Chinese punctuation handling as a secondary path.
- Use Apple Speech segment timings to detect gaps between recognized utterances. A gap of 350 ms can trigger a preview refresh at the latest safe linguistic boundary; pauses do not by themselves discard the open sentence memory. AppState also starts a 350 ms inactivity timer when it receives a changed partial, so a trailing pause can trigger a preview even when Apple Speech sends no new callback.
- Refresh a preview only when its source text changes. A newer preview replaces the displayed preview rather than appending another subtitle.
- If speech continues without punctuation or a usable pause, force a preview checkpoint after four seconds at the latest safe clause or token boundary. Keep the full current sentence in memory so later words can rebuild the complete translation. If tokenization yields no boundary, use the nearest preceding Swift Character boundary.
- Finalize the sentence on sentence-ending punctuation or a final recognition result. Move it to the previous-sentence context slot and start a new current-sentence buffer.
- Use Natural Language tokenization only to find safe language-aware cut points, not to impose a word-count threshold. Apple documents NLTokenizer as a linguistic-unit tokenizer with configurable language, including Thai. [NLTokenizer](https://developer.apple.com/documentation/naturallanguage/nltokenizer), [NLLanguage.thai](https://developer.apple.com/documentation/naturallanguage/nllanguage/thai).
- If segment timing is missing, use punctuation, token boundaries, and monotonic inactivity timers for the 350 ms pause preview and four-second checkpoint.

### Translation ordering and lifecycle

Each preview request carries the current sentence revision. AppState applies a response only if it still matches the latest revision; older network responses are ignored. Identical source previews are deduplicated.

On an automatic recognition-task rollover, reset the per-stream snapshot baseline but preserve the open sentence and previous-sentence context. On an explicit stop, clear action, or locale change, flush any non-empty open sentence once, then clear the context before a new session or language begins. This avoids carrying a previous speaker turn or source language into unrelated speech.

## Acceptance criteria

- A preview can be produced from a pause or the four-second checkpoint before the recognition result is final.
- Preview input contains the accumulated current sentence, not only the most recent fragment.
- New partials update that preview without repeating already finalized sentences.
- ASR text revisions update the open sentence; stream rollover does not suppress the first sentence of the new task.
- A delayed response from an older preview cannot replace a newer preview or finalized translation.
- Sentence finalization rotates the one-sentence context and clears the open sentence.
- Explicit stop, clear, and locale changes do not leak memory across sessions or languages.
- The algorithm has no fixed word-count threshold; language tokenization is used only to choose safe boundaries.

## Verification plan

Add deterministic SpeechChunker tests with synthetic snapshots and segment timings for:

- Pause-triggered preview before final recognition.
- Preview growth across multiple cues while retaining the whole sentence.
- Sentence punctuation finalization and previous-sentence context rotation.
- A partial revision that changes the open sentence without duplicating prior output.
- Automatic stream rollover with preserved sentence memory and a fresh transcript baseline.
- Explicit reset paths for stop, clear, and locale changes.
- Four-second fallback at a safe boundary when no pause or punctuation arrives.
- Missing segment timings, English and Thai token boundaries, and secondary Japanese/Chinese punctuation.
- Out-of-order translation completion, verifying stale results are discarded.

Translation ordering should be tested with a controllable mock service; segmentation tests should not depend on live microphones, network access, or wall-clock sleeps.

## Scope note

This design covers speech chunking, temporary sentence memory, and the translation request ordering directly needed for low-latency previews. It does not authorize implementation yet. The next step is for the user to review this written spec; implementation planning begins only after that review is approved.
