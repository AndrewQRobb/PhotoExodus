import Foundation

/// Removes duplicate media files using size-first grouping then SHA-256 hash comparison.
/// Direct port of Dart's grouping.dart removeDuplicates logic.
enum Deduplicator {

    /// Mark duplicate items in the list. Returns count of duplicates found.
    /// Within each group of identical files, keeps the one with the shortest filename
    /// (most likely to have a matching JSON sidecar).
    static func removeDuplicates(from items: inout [MediaItem]) -> Int {
        var duplicateCount = 0

        // Group by file size first — files can't be identical if sizes differ
        let bySize = Dictionary(grouping: items) { item -> Int in
            (try? item.fileSize()) ?? -1
        }

        for (_, sizeGroup) in bySize {
            if sizeGroup.count <= 1 { continue }

            // Multiple files with same size — compute SHA-256 and group by hash
            let byHash = Dictionary(grouping: sizeGroup) { item -> Data in
                (try? item.sha256Hash()) ?? Data()
            }

            for (_, hashGroup) in byHash {
                if hashGroup.count <= 1 { continue }

                // Sort: prefer best date accuracy (lower = better), then shortest filename.
                let sorted = hashGroup.sorted { a, b in
                    let aSrc = a.metadata.dateSource.rawValue
                    let bSrc = b.metadata.dateSource.rawValue
                    if aSrc != bSrc { return aSrc < bSrc }
                    return a.sourceURL.lastPathComponent.count < b.sourceURL.lastPathComponent.count
                }

                // Mark all but the first (best) as duplicates
                for item in sorted.dropFirst() {
                    item.isDuplicate = true
                    duplicateCount += 1
                }
            }
        }

        return duplicateCount
    }
}
