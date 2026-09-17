import Foundation
import UniformTypeIdentifiers

public enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case webp
    case png
    case jpeg
    case heic
    case pdf
    case tiff

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .webp: return "WebP"
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .heic: return "HEIC"
        case .pdf: return "PDF"
        case .tiff: return "TIFF"
        }
    }

    public var fileExtension: String {
        switch self {
        case .webp: return "webp"
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .pdf: return "pdf"
        case .tiff: return "tiff"
        }
    }

    public var utType: UTType {
        switch self {
        case .webp: return .webP
        case .png: return .png
        case .jpeg: return .jpeg
        case .heic: return .heic
        case .pdf: return .pdf
        case .tiff: return .tiff
        }
    }

    public var systemImage: String {
        switch self {
        case .webp: return "photo.badge.arrow.forward"
        case .png: return "photo"
        case .jpeg: return "photo.fill"
        case .heic: return "livephoto"
        case .pdf: return "doc.text.fill"
        case .tiff: return "photo.stack"
        }
    }

    public var isImage: Bool {
        self != .pdf
    }
}
