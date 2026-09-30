import Foundation

public struct TyphoonMessage: Codable, Equatable {
    public let role: String
    public let content: String
    
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct TyphoonRequest: Codable {
    public let model: String
    public let messages: [TyphoonMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let stream: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case stream
    }
    
    public init(
        model: String = "typhoon-v2.5-30b-a3b-instruct",
        messages: [TyphoonMessage],
        maxTokens: Int? = 250,
        temperature: Double? = 0.3,
        stream: Bool? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.stream = stream
    }
}

public struct TyphoonResponse: Codable {
    public struct Choice: Codable {
        public let index: Int
        public let message: TyphoonMessage
        public let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    public let id: String
    public let choices: [Choice]
}

public struct TyphoonStreamChunk: Codable {
    public struct StreamChoice: Codable {
        public struct Delta: Codable {
            public let content: String?
        }
        public let delta: Delta
    }
    public let choices: [StreamChoice]
}

public struct InterviewPromptResult: Equatable {
    public let questionSummary: String
    public let bulletPoints: [String]
    public let rawText: String
    
    public init(questionSummary: String, bulletPoints: [String], rawText: String) {
        self.questionSummary = questionSummary
        self.bulletPoints = bulletPoints
        self.rawText = rawText
    }
}
