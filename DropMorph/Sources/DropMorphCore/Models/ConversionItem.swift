import Foundation
import Combine

public enum ConversionStatus: Equatable, Sendable {
    case pending
    case processing(Double) // 0.0 ... 1.0
    case completed(outputURL: URL)
    case failed(String)
}

public final class ConversionItem: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: UUID
    public let inputURL: URL
    public let originalFilename: String
    public let originalFileSize: Int64
    
    @Published public var status: ConversionStatus
    @Published public var convertedFileSize: Int64?
    @Published public var outputURL: URL?

    public init(inputURL: URL) {
        self.id = UUID()
        self.inputURL = inputURL
        self.originalFilename = inputURL.lastPathComponent
        
        // Calculate original file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: inputURL.path),
           let size = attributes[.size] as? Int64 {
            self.originalFileSize = size
        } else {
            self.originalFileSize = 0
        }
        
        self.status = .pending
        self.convertedFileSize = nil
        self.outputURL = nil
    }

    public var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalFileSize, countStyle: .file)
    }

    public var formattedConvertedSize: String? {
        guard let size = convertedFileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var savingsPercentage: Int? {
        guard let converted = convertedFileSize, originalFileSize > 0 else { return nil }
        let diff = Double(originalFileSize - converted) / Double(originalFileSize) * 100.0
        return Int(round(diff))
    }
}
