import Foundation

/// Detects and marks edited copies of photos using multilingual suffix matching.
/// Port of Dart's extras.dart removeExtras logic.
enum ExtrasRemover {

    /// Mark edited copies in the list. Returns count of edited copies found.
    /// Uses NFC normalization before suffix comparison (macOS filenames arrive in NFD).
    static func removeExtras(from items: inout [MediaItem]) -> Int {
        var count = 0

        for item in items where !item.isDuplicate {
            let stem = (item.sourceURL.deletingPathExtension().lastPathComponent)
                .lowercased()
                .nfcNormalized

            for suffix in editedSuffixes {
                if stem.hasSuffix(suffix) {
                    item.isEditedCopy = true
                    count += 1
                    break
                }
            }
        }

        return count
    }
}
