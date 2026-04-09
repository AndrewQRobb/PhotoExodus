import Foundation

/// Moves processed media files to the date-organized output directory.
enum FileMover {

    /// Move all active items to the output directory with YYYY/MM/ structure.
    /// Returns a list of failures.
    static func moveFiles(
        _ items: [MediaItem],
        to output: URL,
        strategy: MoveStrategy = RealMoveStrategy()
    ) -> [ProcessingResult.FailureRecord] {
        let fm = FileManager.default
        let activeItems = items.filter { !$0.isDuplicate && !$0.isEditedCopy }
        var failures: [ProcessingResult.FailureRecord] = []

        for (_, item) in activeItems.enumerated() {
            do {
                // Determine destination subdirectory
                let subdir: String
                if let date = item.metadata.dateTaken {
                    let calendar = Calendar.current
                    let year = calendar.component(.year, from: date)
                    let month = calendar.component(.month, from: date)
                    subdir = String(format: "%04d/%02d", year, month)
                } else {
                    subdir = "date-unknown"
                }

                let destDir = output.appendingPathComponent(subdir)
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

                // Use effectiveSourceURL (post-conversion) if available
                let sourceURL = item.currentURL
                let filename = sourceURL.lastPathComponent

                let destURL = findNotExistingName(for: filename, in: destDir)

                try strategy.moveOrCopy(from: sourceURL, to: destURL)

                // Set modification date
                if let date = item.metadata.dateTaken {
                    try strategy.setModificationDate(date, on: destURL)
                }

                item.destinationURL = destURL

            } catch {
                item.failureReason = error.localizedDescription
                failures.append(ProcessingResult.FailureRecord(
                    sourceURL: item.sourceURL,
                    stage: "File Move",
                    reason: error.localizedDescription
                ))
            }

        }

        return failures
    }
}
