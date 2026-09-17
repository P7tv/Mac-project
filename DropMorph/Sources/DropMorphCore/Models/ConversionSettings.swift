import Foundation

public enum ResizePreset: String, CaseIterable, Identifiable, Sendable {
    case original = "100% (Original)"
    case seventyFive = "75%"
    case fifty = "50%"
    case twentyFive = "25%"
    case max1920 = "Max 1920px"
    case max1280 = "Max 1280px"
    case max800 = "Max 800px"

    public var id: String { rawValue }

    public var scaleFactor: Double? {
        switch self {
        case .original: return 1.0
        case .seventyFive: return 0.75
        case .fifty: return 0.5
        case .twentyFive: return 0.25
        case .max1920, .max1280, .max800: return nil
        }
    }

    public var maxDimension: CGFloat? {
        switch self {
        case .max1920: return 1920
        case .max1280: return 1280
        case .max800: return 800
        default: return nil
        }
    }
}

public struct ConversionSettings: Sendable {
    public var targetFormat: OutputFormat
    public var quality: Double // 0.1 to 1.0
    public var resizePreset: ResizePreset
    public var stripMetadata: Bool
    public var customOutputFolder: URL?

    public init(
        targetFormat: OutputFormat = .webp,
        quality: Double = 0.8,
        resizePreset: ResizePreset = .original,
        stripMetadata: Bool = true,
        customOutputFolder: URL? = nil
    ) {
        self.targetFormat = targetFormat
        self.quality = quality
        self.resizePreset = resizePreset
        self.stripMetadata = stripMetadata
        self.customOutputFolder = customOutputFolder
    }
}
