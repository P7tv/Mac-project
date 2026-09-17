import Foundation
import UniformTypeIdentifiers

public enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case webp
    case jpeg
    case png
    case heic
    case pdf
    case icns
    case tiff

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .webp: return "WebP"
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .pdf: return "PDF"
        case .icns: return "ICNS (Mac Icon)"
        case .tiff: return "TIFF"
        }
    }

    public var fileExtension: String {
        switch self {
        case .webp: return "webp"
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .pdf: return "pdf"
        case .icns: return "icns"
        case .tiff: return "tiff"
        }
    }

    public var utType: UTType {
        switch self {
        case .webp: return .webP
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .pdf: return .pdf
        case .icns: return .icns
        case .tiff: return .tiff
        }
    }

    public var systemImage: String {
        switch self {
        case .webp: return "photo.badge.arrow.forward"
        case .jpeg: return "photo.fill"
        case .png: return "photo"
        case .heic: return "livephoto"
        case .pdf: return "doc.text.fill"
        case .icns: return "app.badge.fill"
        case .tiff: return "photo.stack"
        }
    }

    public var isImage: Bool {
        self != .pdf
    }
}
