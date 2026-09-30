import Foundation
import NaturalLanguage

public final class SpeechChunker {
    private static let pauseThreshold: TimeInterval = 0.350

    private var activeSessionID: UUID?
    private var activeStreamID: UUID?
    private var localeIdentifier = "en-US"

    // Keep only a character offset and a digest for committed source text.
    // Apple Speech sends cumulative transcripts, but retaining that transcript
    // would make memory grow with the length of a recognition stream.
    private var committedCharacterCount = 0
    private var committedPrefixFingerprint: UInt64?
    private var streamCarryover = ""
    private var streamCarryoverOverlap = 0
    private var streamCarryoverSeparator = ""
    private var carriesOpenSentence = false

    private var currentSentence = ""
    private var previousSentence: String?
    private var revision: UInt64 = 0
    private var lastImmediatePreviewText: String?

    private var lastSnapshotFingerprint: UInt64?
    private var lastSnapshotCharacterCount = 0

    // Temporary adapter for callers migrated in the AppState task.
    private var legacySessionID = UUID()
    private var legacyStreamID = UUID()
    private var legacyNeedsNewStream = false

    public init() {}

    public func reset() {
        clearRecognitionState()
        revision &+= 1
        legacySessionID = UUID()
        legacyStreamID = UUID()
        legacyNeedsNewStream = false
    }

    public func process(_ event: SpeechRecognitionEvent) -> SpeechChunkingUpdate {
        switch event {
        case .snapshot(let snapshot):
            return process(snapshot)
        case .sessionEnded(let sessionID):
            return endSession(sessionID: sessionID)
        }
    }

    public func previewCurrentSentence(
        sessionID: UUID,
        expectedRevision: UInt64
    ) -> SentenceTranslationInput? {
        guard activeSessionID == sessionID,
              revision == expectedRevision,
              let input = currentInput() else {
            return nil
        }
        return input
    }

    /// Compatibility entry point while AppState is migrated to snapshots.
    /// The new chunking path itself never uses a word-count threshold.
    public func process(
        fullTranscript: String,
        isFinal: Bool
    ) -> (committedSegments: [String], activeRemainder: String) {
        if legacyNeedsNewStream {
            legacyStreamID = UUID()
            legacyNeedsNewStream = false
        }

        let update = process(.snapshot(SpeechRecognitionSnapshot(
            sessionID: legacySessionID,
            streamID: legacyStreamID,
            localeIdentifier: localeIdentifier,
            transcript: fullTranscript,
            isFinal: isFinal,
            receivedAtUptime: ProcessInfo.processInfo.systemUptime,
            segments: []
        )))
        let remainder = currentInput()?.text ?? ""
        if isFinal {
            legacyNeedsNewStream = true
        }
        return (update.finalized.map(\.text), remainder)
    }

    private func process(_ snapshot: SpeechRecognitionSnapshot) -> SpeechChunkingUpdate {
        if activeSessionID != snapshot.sessionID {
            clearRecognitionState()
            activeSessionID = snapshot.sessionID
        }

        if activeStreamID != snapshot.streamID {
            beginStream(snapshot)
        } else if localeIdentifier != snapshot.localeIdentifier {
            // Locale changes are session boundaries even if a caller forgets
            // to send sessionEnded first.
            currentSentence = ""
            previousSentence = nil
            committedCharacterCount = 0
            committedPrefixFingerprint = fingerprintPrefix(snapshot.transcript, characterCount: 0)
            streamCarryover = ""
            streamCarryoverOverlap = 0
            streamCarryoverSeparator = ""
            carriesOpenSentence = false
            lastImmediatePreviewText = nil
        }

        guard committedPrefixIsStable(in: snapshot.transcript) else {
            // A callback that rewrites text before a sentence already emitted
            // is stale relative to the committed boundary. Ignore it rather
            // than emitting the same sentence twice.
            return makeUpdate(preview: nil, finalized: [])
        }

        let snapshotFingerprint = fingerprint(snapshot)
        let snapshotCharacterCount = snapshot.transcript.count
        if snapshotFingerprint == lastSnapshotFingerprint,
           snapshotCharacterCount == lastSnapshotCharacterCount {
            return makeUpdate(preview: nil, finalized: [])
        }

        revision &+= 1
        localeIdentifier = snapshot.localeIdentifier

        let transcriptCharacters = Array(snapshot.transcript)
        let sourceSuffix = String(transcriptCharacters.dropFirst(committedCharacterCount))
        var candidate: String
        var carryoverPrefixCount = 0
        var carryoverIsActive = carriesOpenSentence && committedCharacterCount == streamCarryoverOverlap

        if carryoverIsActive {
            candidate = streamCarryover + streamCarryoverSeparator + sourceSuffix
            carryoverPrefixCount = streamCarryover.count + streamCarryoverSeparator.count
        } else {
            candidate = sourceSuffix
        }

        var finalized: [SentenceTranslationInput] = []
        var sourceCharactersConsumed = committedCharacterCount

        while let split = nextSentence(in: candidate, localeIdentifier: snapshot.localeIdentifier) {
            let sentence = split.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                finalized.append(finalize(sentence))
            }

            if carryoverIsActive {
                let consumedFromThisStream = max(0, split.consumedCharacterCount - carryoverPrefixCount)
                sourceCharactersConsumed = streamCarryoverOverlap + consumedFromThisStream
                carryoverIsActive = false
                carriesOpenSentence = false
                streamCarryover = ""
                streamCarryoverSeparator = ""
            } else {
                sourceCharactersConsumed += split.consumedCharacterCount
            }

            candidate = split.remainder
            committedCharacterCount = sourceCharactersConsumed
            committedPrefixFingerprint = fingerprintPrefix(
                snapshot.transcript,
                characterCount: committedCharacterCount
            )
            lastImmediatePreviewText = nil
        }

        currentSentence = candidate

        if snapshot.isFinal {
            let finalRemainder = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalRemainder.isEmpty {
                finalized.append(finalize(finalRemainder))
            }
            currentSentence = ""
            committedCharacterCount = snapshot.transcript.count
            committedPrefixFingerprint = fingerprintPrefix(
                snapshot.transcript,
                characterCount: committedCharacterCount
            )
            carriesOpenSentence = false
            streamCarryover = ""
            streamCarryoverSeparator = ""
            lastImmediatePreviewText = nil
        }

        lastSnapshotFingerprint = snapshotFingerprint
        lastSnapshotCharacterCount = snapshotCharacterCount

        let shouldPreview = !snapshot.isFinal &&
            (!finalized.isEmpty || hasTimedPause(in: snapshot))
        let preview = shouldPreview ? makeImmediatePreview() : nil
        if currentSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastImmediatePreviewText = nil
        }
        return makeUpdate(preview: preview, finalized: finalized)
    }

    private func beginStream(_ snapshot: SpeechRecognitionSnapshot) {
        let carryover = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        activeStreamID = snapshot.streamID
        localeIdentifier = snapshot.localeIdentifier
        streamCarryover = carryover
        carriesOpenSentence = !carryover.isEmpty
        streamCarryoverOverlap = carryover.isEmpty
            ? 0
            : longestSafeOverlap(
                existing: carryover,
                incoming: snapshot.transcript,
                localeIdentifier: snapshot.localeIdentifier
            )
        let incomingSuffix = String(Array(snapshot.transcript).dropFirst(streamCarryoverOverlap))
        streamCarryoverSeparator = carriesOpenSentence
            ? separator(between: carryover, and: incomingSuffix, localeIdentifier: snapshot.localeIdentifier)
            : ""
        committedCharacterCount = streamCarryoverOverlap
        committedPrefixFingerprint = fingerprintPrefix(
            snapshot.transcript,
            characterCount: streamCarryoverOverlap
        )
        lastSnapshotFingerprint = nil
        lastSnapshotCharacterCount = 0
    }

    private func endSession(sessionID: UUID) -> SpeechChunkingUpdate {
        guard activeSessionID == sessionID else {
            return makeUpdate(preview: nil, finalized: [])
        }

        revision &+= 1
        let openText = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalized = openText.isEmpty ? [] : [finalize(openText)]
        clearRecognitionState()
        return makeUpdate(preview: nil, finalized: finalized)
    }

    private func clearRecognitionState() {
        activeSessionID = nil
        activeStreamID = nil
        localeIdentifier = "en-US"
        committedCharacterCount = 0
        committedPrefixFingerprint = nil
        streamCarryover = ""
        streamCarryoverOverlap = 0
        streamCarryoverSeparator = ""
        carriesOpenSentence = false
        currentSentence = ""
        previousSentence = nil
        lastImmediatePreviewText = nil
        lastSnapshotFingerprint = nil
        lastSnapshotCharacterCount = 0
    }

    private func finalize(_ text: String) -> SentenceTranslationInput {
        let input = SentenceTranslationInput(text: text, context: previousSentence)
        previousSentence = text
        return input
    }

    private func currentInput() -> SentenceTranslationInput? {
        let text = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return SentenceTranslationInput(text: text, context: previousSentence)
    }

    private func makeImmediatePreview() -> SentenceTranslationInput? {
        guard let input = currentInput(), input.text != lastImmediatePreviewText else { return nil }
        lastImmediatePreviewText = input.text
        return input
    }

    private func makeUpdate(
        preview: SentenceTranslationInput?,
        finalized: [SentenceTranslationInput]
    ) -> SpeechChunkingUpdate {
        SpeechChunkingUpdate(revision: revision, preview: preview, finalized: finalized)
    }

    private func nextSentence(
        in text: String,
        localeIdentifier: String
    ) -> (sentence: String, remainder: String, consumedCharacterCount: Int)? {
        guard !text.isEmpty else { return nil }

        for index in text.indices {
            let character = text[index]
            guard isSentenceEnding(character) else { continue }
            guard isValidSentenceEnding(character, at: index, in: text, localeIdentifier: localeIdentifier) else {
                continue
            }

            let sentenceEnd = text.index(after: index)
            var consumedEnd = sentenceEnd
            while consumedEnd < text.endIndex, text[consumedEnd].isWhitespace {
                consumedEnd = text.index(after: consumedEnd)
            }
            let sentence = String(text[..<sentenceEnd])
            let remainder = String(text[consumedEnd...])
            let consumed = text.distance(from: text.startIndex, to: consumedEnd)
            return (sentence, remainder, consumed)
        }
        return nil
    }

    private func isSentenceEnding(_ character: Character) -> Bool {
        [".", "?", "!", "。", "？", "！"].contains(String(character))
    }

    private func isValidSentenceEnding(
        _ character: Character,
        at index: String.Index,
        in text: String,
        localeIdentifier: String
    ) -> Bool {
        let next = text.index(after: index)
        if character == "。" || character == "？" || character == "！" {
            return true
        }
        if character == ".",
           index > text.startIndex,
           next < text.endIndex,
           text[text.index(before: index)].isNumber,
           text[next].isNumber {
            return false
        }
        if next == text.endIndex || text[next].isWhitespace {
            return true
        }
        // Sentence punctuation in Thai speech often has no following space.
        if localeIdentifier.lowercased().hasPrefix("th"), next < text.endIndex {
            return !text[next].isNumber
        }
        return false
    }

    private func hasTimedPause(in snapshot: SpeechRecognitionSnapshot) -> Bool {
        guard snapshot.segments.count > 1 else { return false }
        let ordered = snapshot.segments.sorted { $0.timestamp < $1.timestamp }
        let committedUTF16Count = String(Array(snapshot.transcript).prefix(committedCharacterCount)).utf16.count

        for pair in zip(ordered, ordered.dropFirst()) {
            let (earlier, later) = pair
            guard later.timestamp - earlier.endTime >= Self.pauseThreshold else { continue }
            let boundaryUTF16Offset = earlier.substringRange.location + earlier.substringRange.length
            guard boundaryUTF16Offset > committedUTF16Count,
                  isSafeTokenBoundary(
                    atUTF16Offset: boundaryUTF16Offset,
                    in: snapshot.transcript,
                    localeIdentifier: snapshot.localeIdentifier
                  ) else {
                continue
            }
            return true
        }
        return false
    }

    private func isSafeTokenBoundary(
        atUTF16Offset offset: Int,
        in text: String,
        localeIdentifier: String
    ) -> Bool {
        guard offset >= 0, offset <= text.utf16.count,
              let index = String.Index(utf16Offset: offset, in: text) as String.Index? else {
            return false
        }
        let characterOffset = text.distance(from: text.startIndex, to: index)
        let boundaries = tokenCharacterBoundaries(in: text, localeIdentifier: localeIdentifier)
        return boundaries.isEmpty || boundaries.contains(characterOffset)
    }

    private func longestSafeOverlap(
        existing: String,
        incoming: String,
        localeIdentifier: String
    ) -> Int {
        let existingCharacters = Array(existing)
        let incomingCharacters = Array(incoming)
        let patternLength = min(existingCharacters.count, incomingCharacters.count)
        guard patternLength > 0 else { return 0 }

        let pattern = Array(incomingCharacters.prefix(patternLength))
        let prefixTable = kmpPrefixTable(pattern)
        var matched = 0
        for character in existingCharacters {
            while matched > 0 && (matched == pattern.count || pattern[matched] != character) {
                matched = prefixTable[matched - 1]
            }
            if matched < pattern.count && pattern[matched] == character {
                matched += 1
            }
        }

        let existingBoundaries = tokenCharacterBoundaries(in: existing, localeIdentifier: localeIdentifier)
        let incomingBoundaries = tokenCharacterBoundaries(in: incoming, localeIdentifier: localeIdentifier)
        while matched > 0 {
            let start = existingCharacters.count - matched
            if existingBoundaries.contains(start), incomingBoundaries.contains(matched) {
                return matched
            }
            matched = prefixTable[matched - 1]
        }
        return 0
    }

    private func kmpPrefixTable(_ pattern: [Character]) -> [Int] {
        guard !pattern.isEmpty else { return [] }
        var table = Array(repeating: 0, count: pattern.count)
        var matched = 0
        for index in 1..<pattern.count {
            while matched > 0 && pattern[index] != pattern[matched] {
                matched = table[matched - 1]
            }
            if pattern[index] == pattern[matched] {
                matched += 1
                table[index] = matched
            }
        }
        return table
    }

    private func tokenCharacterBoundaries(in text: String, localeIdentifier: String) -> Set<Int> {
        var boundaries: Set<Int> = [0, text.count]
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(language(for: localeIdentifier))
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            boundaries.insert(text.distance(from: text.startIndex, to: range.lowerBound))
            boundaries.insert(text.distance(from: text.startIndex, to: range.upperBound))
            return true
        }
        return boundaries
    }

    private func language(for localeIdentifier: String) -> NLLanguage {
        let code = localeIdentifier.split(separator: "-").first.map(String.init) ?? localeIdentifier
        switch code.lowercased() {
        case "th": return .thai
        case "ja": return .japanese
        case "zh": return .simplifiedChinese
        default: return .english
        }
    }

    private func separator(
        between prefix: String,
        and suffix: String,
        localeIdentifier: String
    ) -> String {
        guard let last = prefix.last, let first = suffix.first else { return "" }
        if last.isWhitespace || first.isWhitespace { return "" }
        let languageCode = localeIdentifier.lowercased().split(separator: "-").first
        return ["th", "ja", "zh"].contains(languageCode.map(String.init) ?? "") ? "" : " "
    }

    private func committedPrefixIsStable(in transcript: String) -> Bool {
        guard committedCharacterCount > 0 else { return true }
        guard transcript.count >= committedCharacterCount,
              let expected = committedPrefixFingerprint else {
            return false
        }
        return fingerprintPrefix(transcript, characterCount: committedCharacterCount) == expected
    }

    private func fingerprint(_ snapshot: SpeechRecognitionSnapshot) -> UInt64 {
        var hasher = StableFingerprint()
        hasher.combine(snapshot.transcript)
        hasher.combine(snapshot.localeIdentifier)
        hasher.combine(snapshot.isFinal ? 1 : 0)
        for segment in snapshot.segments {
            hasher.combine(segment.substringRange.location)
            hasher.combine(segment.substringRange.length)
            hasher.combine(segment.timestamp.bitPattern)
            hasher.combine(segment.duration.bitPattern)
        }
        return hasher.value
    }

    private func fingerprintPrefix(_ text: String, characterCount: Int) -> UInt64? {
        guard characterCount >= 0, characterCount <= text.count else { return nil }
        return StableFingerprint.hash(String(Array(text).prefix(characterCount)))
    }
}

private struct StableFingerprint {
    private(set) var value: UInt64 = 14_695_981_039_346_656_037

    mutating func combine(_ text: String) {
        for byte in text.utf8 {
            value = (value ^ UInt64(byte)) &* 1_099_511_628_211
        }
        value = (value ^ 0xFF) &* 1_099_511_628_211
    }

    mutating func combine(_ number: Int) {
        combine(String(number))
    }

    mutating func combine(_ number: UInt64) {
        combine(String(number))
    }

    static func hash(_ text: String) -> UInt64 {
        var fingerprint = StableFingerprint()
        fingerprint.combine(text)
        return fingerprint.value
    }
}
