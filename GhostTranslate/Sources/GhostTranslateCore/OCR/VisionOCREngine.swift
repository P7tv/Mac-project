import Foundation
import Vision
import CoreGraphics

public enum OCRError: LocalizedError {
    case noTextFound
    case recognitionFailed(Error)
    case captureFailed
    
    public var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text could be recognized in the selected screen area."
        case .recognitionFailed(let err):
            return "OCR recognition error: \(err.localizedDescription)"
        case .captureFailed:
            return "Failed to capture the selected screen region."
        }
    }
}

public final class VisionOCREngine {
    public static let shared = VisionOCREngine()
    
    public init() {}
    
    /// Recognize text from a CGImage using Apple's Vision framework
    public func recognizeText(from image: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Sort observations vertically from top to bottom
                let sorted = observations.sorted { obs1, obs2 in
                    obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
                }
                
                let extractedLines = sorted.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }
                
                let fullText = extractedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: fullText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "th-TH", "ja-JP", "zh-Hans", "zh-Hant"]
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }
}
