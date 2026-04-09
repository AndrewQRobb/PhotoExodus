import Foundation

/// Callback types for the processing engine to communicate with the UI.
public typealias ProgressCallback = @Sendable (PipelineProgress) async -> Void
public typealias ConflictCallback = @Sendable (MetadataConflict) async -> MetadataConflict.Resolution

/// Progress update from the pipeline.
public struct PipelineProgress: Sendable {
    public let stage: String
    public let completed: Int
    public let total: Int
    public let currentFile: String?
}

/// Orchestrates the full migration pipeline.
/// Designed to be called from an async context (e.g., a SwiftUI Task).
public enum ProcessingEngine {

    /// Run the full migration pipeline.
    public static func run(
        options: ProcessingOptions,
        onProgress: ProgressCallback? = nil,
        onConflict: ConflictCallback? = nil
    ) async throws -> ProcessingResult {
        // Phase 1: Scan
        await onProgress?(PipelineProgress(stage: "Scanning files", completed: 0, total: 0, currentFile: nil))
        var items = try Scanner.scan(input: options.inputURL)
        let totalScanned = items.count

        try Task.checkCancellation()

        // Phase 2: Remove duplicates
        await onProgress?(PipelineProgress(stage: "Removing duplicates", completed: 0, total: totalScanned, currentFile: nil))
        let duplicatesRemoved = Deduplicator.removeDuplicates(from: &items)

        try Task.checkCancellation()

        // Phase 3: Remove edited copies
        var editedCopiesRemoved = 0
        if options.removeEditedCopies {
            await onProgress?(PipelineProgress(stage: "Detecting edited copies", completed: 0, total: totalScanned, currentFile: nil))
            editedCopiesRemoved = ExtrasRemover.removeExtras(from: &items)
        }

        try Task.checkCancellation()

        // Phase 4: Extract dates and detect conflicts
        await onProgress?(PipelineProgress(stage: "Extracting metadata", completed: 0, total: totalScanned, currentFile: nil))
        let conflicts = DateExtractor.extractAll(
            from: items,
            conflictThreshold: options.conflictThresholdSeconds
        ) { completed, total in
            // Synchronous progress from DateExtractor — no await needed here
        }

        try Task.checkCancellation()

        // Phase 5: Resolve conflicts (suspends for each one)
        var conflictsResolved = 0
        if let onConflict = onConflict {
            for conflict in conflicts {
                try Task.checkCancellation()
                await onProgress?(PipelineProgress(
                    stage: "Reviewing conflict \(conflictsResolved + 1) of \(conflicts.count)",
                    completed: conflictsResolved, total: conflicts.count,
                    currentFile: conflict.sourceURL.lastPathComponent
                ))

                let resolution = await onConflict(conflict)

                if let item = items.first(where: { $0.id == conflict.itemID }) {
                    let jsonData = JSONSidecarExtractor.extract(for: item.sourceURL)
                    let exifData = EXIFExtractor.extract(from: item.sourceURL)
                    DateExtractor.applyResolution(resolution, to: item, jsonData: jsonData, exifData: exifData)
                }
                conflictsResolved += 1
            }
        } else {
            // No conflict handler — default to JSON for all
            for conflict in conflicts {
                if let item = items.first(where: { $0.id == conflict.itemID }) {
                    let jsonData = JSONSidecarExtractor.extract(for: item.sourceURL)
                    let exifData = EXIFExtractor.extract(from: item.sourceURL)
                    DateExtractor.applyResolution(.useJSON, to: item, jsonData: jsonData, exifData: exifData)
                }
            }
        }

        try Task.checkCancellation()

        // Phase 6: Write metadata into files
        let activeItems = items.filter { !$0.isDuplicate && !$0.isEditedCopy }
        var writeFailures: [ProcessingResult.FailureRecord] = []
        var filesConverted = 0

        for (index, item) in activeItems.enumerated() {
            try Task.checkCancellation()
            await onProgress?(PipelineProgress(
                stage: "Writing metadata", completed: index, total: activeItems.count,
                currentFile: item.sourceURL.lastPathComponent
            ))

            do {
                let wasWebP = item.sourceURL.isWebP
                let resultURL = try MetadataWriter.writeMetadata(for: item)
                item.effectiveSourceURL = resultURL
                if wasWebP { filesConverted += 1 }
            } catch {
                writeFailures.append(ProcessingResult.FailureRecord(
                    sourceURL: item.sourceURL,
                    stage: "Metadata Write",
                    reason: error.localizedDescription
                ))
            }
        }

        try Task.checkCancellation()

        // Phase 7: Move files to output
        await onProgress?(PipelineProgress(stage: "Moving files", completed: 0, total: activeItems.count, currentFile: nil))
        let strategy: MoveStrategy = options.useDryRun ? DryRunMoveStrategy() : RealMoveStrategy()
        let moveFailures = FileMover.moveFiles(items, to: options.outputURL, strategy: strategy)

        let allFailures = writeFailures + moveFailures
        let successfullyMoved = activeItems.count - writeFailures.count - moveFailures.count
        let dateUnknownCount = activeItems.filter { $0.metadata.dateTaken == nil }.count

        await onProgress?(PipelineProgress(stage: "Complete", completed: activeItems.count, total: activeItems.count, currentFile: nil))

        return ProcessingResult(
            totalScanned: totalScanned,
            duplicatesRemoved: duplicatesRemoved,
            editedCopiesRemoved: editedCopiesRemoved,
            conflictsResolved: conflictsResolved,
            filesConverted: filesConverted,
            successfullyMoved: successfullyMoved,
            dateUnknownCount: dateUnknownCount,
            failures: allFailures
        )
    }
}
