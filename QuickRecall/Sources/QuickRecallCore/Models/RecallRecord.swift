import Foundation

public struct RecallRecord: Identifiable, Sendable, Equatable {
    public let id: String
    public let timestamp: Date
    public let appName: String
    public let windowTitle: String
    public let extractedText: String
    public let thumbnailPath: String
    public var matchSnippet: String?

    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        appName: String,
        windowTitle: String = "",
        extractedText: String,
        thumbnailPath: String,
        matchSnippet: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appName = appName
        self.windowTitle = windowTitle
        self.extractedText = extractedText
        self.thumbnailPath = thumbnailPath
        self.matchSnippet = matchSnippet
    }

    public var timeAgoDisplay: String {
        let seconds = Int(-timestamp.timeIntervalSinceNow)
        if seconds < 60 {
            return "เมื่อสักครู่"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) นาทีที่แล้ว"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours) ชม. ที่แล้ว"
        } else {
            let days = seconds / 86400
            return "\(days) วันที่แล้ว"
        }
    }

    public var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
