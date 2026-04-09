import Foundation

/// Walks a Google Takeout input directory, classifies folders,
/// and builds the initial list of MediaItems.
enum Scanner {

    /// Regex matching Google Takeout year folders: "Photos from 2023", etc.
    private static let yearFolderPattern = try! NSRegularExpression(
        pattern: #"^Photos from (20|19|18)\d{2}$"#
    )

    /// Scan the input directory and return all media items found in year folders.
    /// Also pre-caches the JSON sidecar URL on each item.
    static func scan(
        input: URL,
        progress: @Sendable (Int) -> Void = { _ in }
    ) throws -> [MediaItem] {
        let fm = FileManager.default
        var items: [MediaItem] = []
        var count = 0

        // Find all year folders (may be nested under "Google Photos/" or at top level)
        let yearFolders = try findYearFolders(in: input)

        for folder in yearFolders {
            guard let enumerator = fm.enumerator(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                // Skip directories
                guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                      values.isRegularFile == true
                else { continue }

                // Skip JSON sidecars — they're metadata, not media
                if fileURL.pathExtension.lowercased() == "json" { continue }

                // Skip non-media files
                guard fileURL.isMediaFile else { continue }

                let item = MediaItem(sourceURL: fileURL)
                // Pre-cache sidecar lookup (normal mode)
                item.jsonSidecarURL = JSONSidecarExtractor.findJSON(for: fileURL)
                items.append(item)

                count += 1
                progress(count)
            }
        }

        return items
    }

    /// Find all "Photos from YYYY" directories anywhere under the input.
    private static func findYearFolders(in root: URL) throws -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return result }

        for case let dirURL as URL in enumerator {
            guard let values = try? dirURL.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true
            else { continue }

            if isYearFolder(dirURL.lastPathComponent) {
                result.append(dirURL)
                enumerator.skipDescendants() // Don't recurse into year folders
            }
        }

        return result
    }

    /// Check if a folder name matches "Photos from YYYY".
    static func isYearFolder(_ name: String) -> Bool {
        let nsName = name as NSString
        return yearFolderPattern.firstMatch(
            in: name,
            range: NSRange(location: 0, length: nsName.length)
        ) != nil
    }
}
