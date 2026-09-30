import Foundation

public final class SpeechChunker {
    private var committedOffset: Int = 0
    private let targetWordCount: Int = 10
    
    private let naturalConjunctions = [
        " and ", " but ", " so ", " because ", " which ", " when ", " then ", " with ",
        " แล้วก็ ", " และ ", " แต่ ", " หรือ ", " เพราะ ", " ซึ่ง ", " ก็คือ "
    ]
    
    public init() {}
    
    public func reset() {
        committedOffset = 0
    }
    
    /// Process incoming streaming transcript.
    /// Returns newly committed segments and the currently active remainder.
    public func process(fullTranscript: String, isFinal: Bool) -> (committedSegments: [String], activeRemainder: String) {
        guard fullTranscript.count >= committedOffset else {
            // Transcript was reset upstream
            committedOffset = 0
            return ([], fullTranscript)
        }
        
        let startIndex = fullTranscript.index(fullTranscript.startIndex, offsetBy: committedOffset)
        let uncommitted = String(fullTranscript[startIndex...]).trimmingCharacters(in: .whitespaces)
        
        guard !uncommitted.isEmpty else {
            return ([], "")
        }
        
        if isFinal {
            committedOffset = fullTranscript.count
            return ([uncommitted], "")
        }
        
        var committed: [String] = []
        var remaining = uncommitted
        
        // Loop to find sentence and clause breaks
        while true {
            if let breakIndex = findNaturalBreak(in: remaining) {
                let segment = String(remaining[..<breakIndex]).trimmingCharacters(in: .whitespaces)
                let nextStart = remaining.index(after: breakIndex)
                
                if !segment.isEmpty {
                    committed.append(segment)
                    committedOffset += segment.count + (fullTranscript[startIndex...].distance(from: remaining.startIndex, to: nextStart) - remaining.count)
                }
                
                remaining = String(remaining[nextStart...]).trimmingCharacters(in: .whitespaces)
            } else {
                break
            }
        }
        
        // Update committedOffset accurately based on remaining length
        let remainingDistance = uncommitted.hasSuffix(remaining) ? uncommitted.count - remaining.count : 0
        committedOffset += remainingDistance
        
        return (committed, remaining)
    }
    
    private func findNaturalBreak(in text: String) -> String.Index? {
        // Priority 1: Sentence terminating punctuation (. ? !)
        for char in [".", "?", "!"] {
            if let range = text.range(of: char) {
                // Ensure it's not a decimal point or URL
                let afterIdx = text.index(after: range.lowerBound)
                if afterIdx == text.endIndex || text[afterIdx].isWhitespace {
                    return range.lowerBound
                }
            }
        }
        
        // Priority 2: Clause punctuation (comma, semicolon) if chunk is long enough (> 5 words)
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count >= 6 {
            for char in [",", ";", "—"] {
                if let range = text.range(of: char) {
                    return range.lowerBound
                }
            }
        }
        
        // Priority 3: Word count threshold exceeded (e.g. 10-12 words without any punctuation)
        if words.count >= targetWordCount {
            // Look for conjunctions near the middle
            for conj in naturalConjunctions {
                if let range = text.range(of: conj) {
                    let wordDistance = text[..<range.lowerBound].components(separatedBy: .whitespaces).count
                    if wordDistance >= 5 {
                        return range.lowerBound
                    }
                }
            }
            
            // Otherwise break at the targetWordCount word boundary
            let prefixWords = words.prefix(targetWordCount).joined(separator: " ")
            if let range = text.range(of: prefixWords) {
                return range.upperBound
            }
        }
        
        return nil
    }
}
