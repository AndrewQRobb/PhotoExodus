import Foundation

/// Summary of the entire migration pipeline run.
public struct ProcessingResult: Sendable {
    public let totalScanned: Int
    public let duplicatesRemoved: Int
    public let editedCopiesRemoved: Int
    public let conflictsResolved: Int
    public let filesConverted: Int
    public let successfullyMoved: Int
    public let dateUnknownCount: Int
    public let failures: [FailureRecord]

    public init(totalScanned: Int, duplicatesRemoved: Int, editedCopiesRemoved: Int,
                conflictsResolved: Int, filesConverted: Int, successfullyMoved: Int,
                dateUnknownCount: Int, failures: [FailureRecord]) {
        self.totalScanned = totalScanned
        self.duplicatesRemoved = duplicatesRemoved
        self.editedCopiesRemoved = editedCopiesRemoved
        self.conflictsResolved = conflictsResolved
        self.filesConverted = filesConverted
        self.successfullyMoved = successfullyMoved
        self.dateUnknownCount = dateUnknownCount
        self.failures = failures
    }

    public struct FailureRecord: Identifiable, Sendable {
        public let id = UUID()
        public let sourceURL: URL
        public let stage: String
        public let reason: String

        public init(sourceURL: URL, stage: String, reason: String) {
            self.sourceURL = sourceURL
            self.stage = stage
            self.reason = reason
        }
    }
}
