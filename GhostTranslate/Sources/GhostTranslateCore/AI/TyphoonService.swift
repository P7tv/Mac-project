import Foundation

public enum TyphoonError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case emptyResponse
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Typhoon API Key is missing. Please configure it in Settings."
        case .invalidURL:
            return "Invalid Typhoon API URL."
        case .serverError(let code, let msg):
            return "Typhoon API Server Error (\(code)): \(msg)"
        case .decodingError(let err):
            return "Failed to decode Typhoon response: \(err.localizedDescription)"
        case .emptyResponse:
            return "Received empty response from Typhoon AI."
        }
    }
}

public actor TyphoonService {
    public static let shared = TyphoonService()
    
    private let defaultBaseURL = "https://api.opentyphoon.ai/v1"
    private let defaultModel = "typhoon-v2.5-30b-a3b-instruct"
    
    // Default fallback to user's known working key in workspace
    private let fallbackAPIKey = "sk-VL6FVfEvqs8uY4fo5CfiKqnG6Wy2Kf2jwrXC3HQjGEPemPmR"
    
    private var customAPIKey: String?
    private var customModel: String?
    
    public init() {}
    
    public func setAPIKey(_ key: String?) {
        self.customAPIKey = key?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func setModel(_ model: String?) {
        self.customModel = model?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func resolveAPIKey() -> String? {
        if let custom = customAPIKey, !custom.isEmpty {
            return custom
        }
        if let stored = UserDefaults.standard.string(forKey: "ghost_typhoon_api_key"), !stored.isEmpty {
            return stored
        }
        if let env = ProcessInfo.processInfo.environment["TYPHOON_API_KEY"], !env.isEmpty {
            return env
        }
        return fallbackAPIKey
    }
    
    private func resolveModel() -> String {
        if let custom = customModel, !custom.isEmpty {
            return custom
        }
        if let stored = UserDefaults.standard.string(forKey: "ghost_typhoon_model"), !stored.isEmpty {
            return stored
        }
        return defaultModel
    }
    
    /// Translates text quickly for live subtitles
    public func translateSubtitle(text: String) async throws -> String {
        let messages = [
            TyphoonMessage(role: "system", content: Prompts.subtitleSystemPrompt),
            TyphoonMessage(role: "user", content: text)
        ]
        return try await sendChatCompletion(messages: messages, maxTokens: 150, temperature: 0.2)
    }
    
    /// Generates structured interview talking points and summary
    public func generateInterviewPrompts(question: String) async throws -> InterviewPromptResult {
        let messages = [
            TyphoonMessage(role: "system", content: Prompts.interviewSystemPrompt),
            TyphoonMessage(role: "user", content: question)
        ]
        let rawResponse = try await sendChatCompletion(messages: messages, maxTokens: 350, temperature: 0.3)
        return Prompts.parseInterviewResponse(rawResponse)
    }
    
    /// Translates text captured via on-screen OCR
    public func translateOCR(text: String) async throws -> String {
        let messages = [
            TyphoonMessage(role: "system", content: Prompts.ocrSystemPrompt),
            TyphoonMessage(role: "user", content: text)
        ]
        return try await sendChatCompletion(messages: messages, maxTokens: 300, temperature: 0.2)
    }
    
    /// Core HTTP completion sender
    private func sendChatCompletion(
        messages: [TyphoonMessage],
        maxTokens: Int = 200,
        temperature: Double = 0.3
    ) async throws -> String {
        guard let apiKey = resolveAPIKey(), !apiKey.isEmpty else {
            throw TyphoonError.missingAPIKey
        }
        
        guard let url = URL(string: "\(defaultBaseURL)/chat/completions") else {
            throw TyphoonError.invalidURL
        }
        
        let requestBody = TyphoonRequest(
            model: resolveModel(),
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TyphoonError.serverError(statusCode: 0, message: "Invalid HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw TyphoonError.serverError(statusCode: httpResponse.statusCode, message: errorText)
        }
        
        do {
            let typhoonResponse = try JSONDecoder().decode(TyphoonResponse.self, from: data)
            guard let content = typhoonResponse.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
                throw TyphoonError.emptyResponse
            }
            return content
        } catch {
            throw TyphoonError.decodingError(error)
        }
    }
    
    /// Streams completion chunks via Server-Sent Events (SSE)
    public func streamCompletion(
        messages: [TyphoonMessage],
        maxTokens: Int = 250,
        temperature: Double = 0.3
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = resolveAPIKey(), !apiKey.isEmpty else {
                        continuation.finish(throwing: TyphoonError.missingAPIKey)
                        return
                    }
                    
                    guard let url = URL(string: "\(defaultBaseURL)/chat/completions") else {
                        continuation.finish(throwing: TyphoonError.invalidURL)
                        return
                    }
                    
                    let requestBody = TyphoonRequest(
                        model: resolveModel(),
                        messages: messages,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        stream: true
                    )
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: TyphoonError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Stream connection failed"))
                        return
                    }
                    
                    for try await line in asyncBytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty || trimmed == ":" { continue }
                        if trimmed == "data: [DONE]" {
                            continuation.finish()
                            return
                        }
                        
                        if trimmed.hasPrefix("data: ") {
                            let jsonPart = String(trimmed.dropFirst(6))
                            if let data = jsonPart.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(TyphoonStreamChunk.self, from: data),
                               let delta = chunk.choices.first?.delta.content {
                                continuation.yield(delta)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
