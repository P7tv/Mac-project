import Foundation
import UniformTypeIdentifiers

public enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case webp
    case jpeg
    case png
    case heic
    case pdf
    case gif
    case m4a
    case icns
    case ico
    case tiff

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .webp: return "WebP"
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .pdf: return "PDF"
        case .gif: return "GIF"
        case .m4a: return "M4A (Audio)"
        case .icns: return "ICNS (Mac)"
        case .ico: return "ICO (Win)"
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
        case .gif: return "gif"
        case .m4a: return "m4a"
        case .icns: return "icns"
        case .ico: return "ico"
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
        case .gif: return .gif
        case .m4a: return .mpeg4Audio
        case .icns: return .icns
        case .ico: return .ico
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
        case .gif: return "play.square.stack.fill"
        case .m4a: return "waveform"
        case .icns: return "app.badge.fill"
        case .ico: return "window.vertical.closed"
        case .tiff: return "photo.stack"
        }
    }

    public var isImage: Bool {
        switch self {
        case .pdf, .m4a: return false
        default: return true
        }
    }
}
