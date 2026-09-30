import Foundation

public enum Prompts {
    public static let subtitleSystemPrompt = """
    You are an ultra-fast, natural real-time subtitle translator.
    Auto-detect the input language:
    - If the input is in English (or foreign language): Translate it directly into natural, fluent Thai.
    - If the input is in Thai: Translate it directly into natural English.
    - If mixed Thai and English: Polish it into clean Thai while keeping technical terms intact.
    Rules:
    1. Output ONLY the translation.
    2. Do NOT add notes, explanations, or quotes.
    3. Keep it concise so it reads easily as a live subtitle.
    4. When prior context is provided, do not translate or repeat it; translate only the current sentence.
    """

    public static func subtitleUserPrompt(
        currentSentence: String,
        contextSentence: String?
    ) -> String {
        guard let contextSentence,
              !contextSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return currentSentence
        }

        return """
        Previous sentence for context only (do not translate or repeat it):
        <context>
        \(contextSentence)
        </context>

        Translate the current sentence only:
        <current_sentence>
        \(currentSentence)
        </current_sentence>
        """
    }
    
    public static func detectLanguageTag(_ text: String) -> String {
        let hasThai = text.unicodeScalars.contains { $0.value >= 0x0E00 && $0.value <= 0x0E7F }
        let hasLatin = text.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        if hasThai && hasLatin {
            return "TH / EN"
        } else if hasThai {
            return "TH ➔ EN"
        } else if hasLatin {
            return "EN ➔ TH"
        }
        return "AUTO"
    }
    
    public static let interviewSystemPrompt = """
    You are an elite, real-time interview co-pilot.
    When provided with an interview question or interviewer dialogue:
    1. Summarize the core question in Thai under "**สรุปคำถาม:**"
    2. Provide 3 high-impact, actionable bullet points (in Thai with English key phrases) on how to answer effectively.
    3. Format bullet points starting with "- "
    Keep the answer concise, structured (e.g. STAR method, key metrics, technical clarity), and fast.
    """
    
    public static let ocrSystemPrompt = """
    You are an accurate screen text translator.
    The user captured text from their screen.
    Translate the text into natural Thai. If the text is code, keep code syntax and translate comments or explain the intent concisely.
    Output only the translated text.
    """
    
    public static func parseInterviewResponse(_ text: String) -> InterviewPromptResult {
        let lines = text.components(separatedBy: .newlines)
        var summary = ""
        var bullets: [String] = []
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            if line.contains("สรุปคำถาม") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    summary = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                } else {
                    summary = line
                }
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || (line.count > 2 && line.prefix(2).contains(".")) {
                let cleaned = line
                    .replacingOccurrences(of: "^[-*•]\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    bullets.append(cleaned)
                }
            }
        }
        
        if summary.isEmpty {
            summary = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? text
        }
        
        return InterviewPromptResult(
            questionSummary: summary,
            bulletPoints: bullets.isEmpty ? [text] : bullets,
            rawText: text
        )
    }
}
