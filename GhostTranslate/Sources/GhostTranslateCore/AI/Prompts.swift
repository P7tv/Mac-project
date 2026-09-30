import Foundation

public enum Prompts {
    public static let subtitleSystemPrompt = """
    You are an ultra-fast, natural real-time subtitle translator.
    Your task: Translate the input speech transcript directly into clean, fluent, colloquial Thai.
    Rules:
    1. Output ONLY the Thai translation.
    2. Do NOT add notes, explanations, or quotes.
    3. Keep it concise so it reads easily as a video/speech subtitle.
    4. Handle technical terminology naturally in modern Thai or standard loan words.
    """
    
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
