import Foundation

public enum DisplayResolution: String, CaseIterable, Identifiable, Sendable {
    case fullHD = "1080p (1920x1080)"
    case quadHD = "1440p (2560x1440)"
    case hd720p = "720p (1280x720)"

    public var id: String { rawValue }

    public var width: UInt32 {
        switch self {
        case .fullHD: return 1920
        case .quadHD: return 2560
        case .hd720p: return 1280
        }
    }

    public var height: UInt32 {
        switch self {
        case .fullHD: return 1080
        case .quadHD: return 1440
        case .hd720p: return 720
        }
    }
}

public struct DisplayConfig: Sendable {
    public var resolution: DisplayResolution
    public var refreshRate: Double
    public var hiDPI: Bool
    public var displayName: String

    public init(
        resolution: DisplayResolution = .fullHD,
        refreshRate: Double = 60.0,
        hiDPI: Bool = false,
        displayName: String = "DeskExtend Monitor"
    ) {
        self.resolution = resolution
        self.refreshRate = refreshRate
        self.hiDPI = hiDPI
        self.displayName = displayName
    }
}
