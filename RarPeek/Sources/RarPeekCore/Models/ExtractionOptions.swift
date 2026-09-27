import Foundation

public enum OverwritePolicy: String, CaseIterable, Identifiable, Sendable {
    case rename = "Rename (Keep both)"
    case overwrite = "Overwrite"
    case skip = "Skip existing"

    public var id: String { rawValue }
}

public struct ExtractionOptions: Sendable {
    public var targetFolder: URL
    public var password: String?
    public var selectedIndexes: [Int]?
    public var overwritePolicy: OverwritePolicy
    public var createContainingFolder: Bool

    public init(
        targetFolder: URL,
        password: String? = nil,
        selectedIndexes: [Int]? = nil,
        overwritePolicy: OverwritePolicy = .rename,
        createContainingFolder: Bool = true
    ) {
        self.targetFolder = targetFolder
        self.password = password
        self.selectedIndexes = selectedIndexes
        self.overwritePolicy = overwritePolicy
        self.createContainingFolder = createContainingFolder
    }
}
