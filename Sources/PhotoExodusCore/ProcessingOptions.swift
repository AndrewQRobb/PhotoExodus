import Foundation

/// Configuration for a pipeline run.
public struct ProcessingOptions: Sendable {
    public let inputURL: URL
    public let outputURL: URL
    public var removeEditedCopies: Bool = true
    public var useDryRun: Bool = false
    /// Threshold in seconds for EXIF vs JSON date disagreement to trigger user review.
    public var conflictThresholdSeconds: TimeInterval = 86400 // 24 hours

    public init(inputURL: URL, outputURL: URL, removeEditedCopies: Bool = true,
                useDryRun: Bool = false, conflictThresholdSeconds: TimeInterval = 86400) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.removeEditedCopies = removeEditedCopies
        self.useDryRun = useDryRun
        self.conflictThresholdSeconds = conflictThresholdSeconds
    }
}
