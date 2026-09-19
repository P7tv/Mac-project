import Foundation

public struct ParsedUpload: Sendable {
    public let filename: String
    public let data: Data
    public let mimeType: String?

    public init(filename: String, data: Data, mimeType: String? = nil) {
        self.filename = filename
        self.data = data
        self.mimeType = mimeType
    }
}

public enum MultipartParser {
    public static func parse(body: Data, contentType: String, defaultFilename: String = "upload") -> ParsedUpload? {
        // If not multipart, treat the entire body payload as the file content
        guard let boundary = extractBoundary(from: contentType) else {
            if !body.isEmpty {
                return ParsedUpload(filename: defaultFilename, data: body)
            }
            return nil
        }

        let boundaryMarker = ("--" + boundary).data(using: .utf8)!
        let crlfCrlf = Data([13, 10, 13, 10])
        let lfLf = Data([10, 10])
        let crlf = Data([13, 10])

        guard let firstBoundaryRange = body.range(of: boundaryMarker) else {
            // If boundary delimiter wasn't found, fallback to raw body if non-empty
            return !body.isEmpty ? ParsedUpload(filename: defaultFilename, data: body) : nil
        }

        let searchStart = firstBoundaryRange.upperBound

        // Search for end of part headers
        let headerTerminatorRange: Range<Data.Index>
        let isCrlf: Bool
        if let r = body.range(of: crlfCrlf, in: searchStart..<body.endIndex) {
            headerTerminatorRange = r
            isCrlf = true
        } else if let r = body.range(of: lfLf, in: searchStart..<body.endIndex) {
            headerTerminatorRange = r
            isCrlf = false
        } else {
            return nil
        }

        let headerData = body[searchStart..<headerTerminatorRange.lowerBound]
        let headerString = String(data: headerData, encoding: .utf8) ?? String(data: headerData, encoding: .ascii) ?? ""

        let filename = extractFilename(from: headerString) ?? defaultFilename
        let mimeType = extractMimeType(from: headerString)
        let fileDataStart = headerTerminatorRange.upperBound

        // The file content ends before the next boundary
        let nextBoundary = (isCrlf ? "\r\n--" : "\n--") + boundary
        if let nextBoundaryData = nextBoundary.data(using: .utf8),
           let endRange = body.range(of: nextBoundaryData, in: fileDataStart..<body.endIndex) {
            let fileData = body[fileDataStart..<endRange.lowerBound]
            return ParsedUpload(filename: filename, data: Data(fileData), mimeType: mimeType)
        } else if let endRange = body.range(of: boundaryMarker, in: fileDataStart..<body.endIndex) {
            var fileEnd = endRange.lowerBound
            if fileEnd >= fileDataStart + 2 && body[(fileEnd - 2)..<fileEnd] == crlf {
                fileEnd -= 2
            } else if fileEnd >= fileDataStart + 1 && body[fileEnd - 1] == 10 {
                fileEnd -= 1
            }
            let fileData = body[fileDataStart..<fileEnd]
            return ParsedUpload(filename: filename, data: Data(fileData), mimeType: mimeType)
        }

        return nil
    }

    public static func extractBoundary(from contentType: String) -> String? {
        let parts = contentType.components(separatedBy: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("boundary=") {
                var b = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if b.hasPrefix("\"") && b.hasSuffix("\"") && b.count >= 2 {
                    b = String(b.dropFirst().dropLast())
                }
                return b
            }
        }
        return nil
    }

    public static func extractFilename(from partHeaders: String) -> String? {
        for line in partHeaders.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if lower.contains("content-disposition:") && lower.contains("filename=") {
                if let range = line.range(of: "filename=\"", options: .caseInsensitive) {
                    let rest = line[range.upperBound...]
                    if let endQuote = rest.firstIndex(of: "\"") {
                        return String(rest[..<endQuote])
                    }
                } else if let range = line.range(of: "filename=", options: .caseInsensitive) {
                    let rest = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    let token = rest.components(separatedBy: ";")[0].trimmingCharacters(in: .whitespaces)
                    return token
                }
            }
        }
        return nil
    }

    public static func extractMimeType(from partHeaders: String) -> String? {
        for line in partHeaders.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if lower.hasPrefix("content-type:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }
}
