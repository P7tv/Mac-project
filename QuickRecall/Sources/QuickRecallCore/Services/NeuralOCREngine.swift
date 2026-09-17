import Foundation
import Vision
import CoreGraphics

public final class NeuralOCREngine: Sendable {
    public init() {}

    public func recognizeText(from image: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                var textLines: [String] = []
                for obs in observations {
                    if let topCandidate = obs.topCandidates(1).first {
                        let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            textLines.append(text)
                        }
                    }
                }

                continuation.resume(returning: textLines.joined(separator: "\n"))
            }

            request.recognitionLanguages = ["th-TH", "en-US"]
            request.recognitionLevel = .accurate
            request.usesCPUOnly = false // Execute on Apple Silicon Neural Engine

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
