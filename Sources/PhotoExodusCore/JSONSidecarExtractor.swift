import Foundation

/// Data extracted from a Google Photos JSON sidecar file.
struct SidecarData: Sendable {
    let date: Date
    let latitude: Double?
    let longitude: Double?
}

/// Multilingual "edited" suffixes used for sidecar name-matching.
/// Must be lowercase. Used by both ExtrasRemover and sidecar lookup.
let editedSuffixes: [String] = [
    "-edited", "-effects", "-smile", "-mix",   // EN
    "-edytowane",                                // PL
    "-bearbeitet",                               // DE
    "-bewerkt",                                  // NL
    "-\u{7DE8}\u{96C6}\u{6E08}\u{307F}",       // JA (編集済み)
    "-modificato",                               // IT
    "-modifi\u{00E9}",                           // FR (modifié)
    "-ha editado",                               // ES
    "-editat",                                   // CA
]

/// Extracts date and GPS from a Google Photos JSON sidecar file.
///
/// Tries up to 7 name-matching strategies to find the `.json` file
/// that corresponds to a given media file. This is a direct port of
/// the Dart `json_extractor.dart` logic.
enum JSONSidecarExtractor {

    /// Find and parse the JSON sidecar for a media file.
    /// - Parameters:
    ///   - fileURL: The media file URL.
    ///   - tryhard: Enable aggressive name transformations (strategies 6-7).
    /// - Returns: Extracted sidecar data, or nil if no sidecar found.
    static func extract(for fileURL: URL, tryhard: Bool = false) -> SidecarData? {
        guard let jsonURL = findJSON(for: fileURL, tryhard: tryhard) else { return nil }
        return parseSidecar(at: jsonURL)
    }

    /// Returns the resolved sidecar URL if found (cached on MediaItem by Scanner).
    static func findJSON(for fileURL: URL, tryhard: Bool = false) -> URL? {
        let dir = fileURL.deletingLastPathComponent()
        let name = fileURL.lastPathComponent

        var strategies: [(String) -> String] = [
            { $0 },                 // 1. Identity: photo.jpg → photo.jpg.json
            shortenName,            // 2. 51-char truncation
            bracketSwap,            // 3. photo(1).jpg → photo.jpg(1).json
            removeExtra,            // 4. photo-edited.jpg → photo.jpg
            noExtension,            // 5. photo.jpg → photo.json
        ]
        if tryhard {
            strategies.append(removeExtraRegex)  // 6. Regex suffix removal
            strategies.append(removeDigit)        // 7. photo(1).jpg → photo.jpg
        }

        for strategy in strategies {
            let jsonName = strategy(name) + ".json"
            let jsonURL = dir.appendingPathComponent(jsonName)
            if FileManager.default.fileExists(atPath: jsonURL.path) {
                return jsonURL
            }
        }
        return nil
    }

    // MARK: - JSON Parsing

    /// Parse a known sidecar file directly (used when URL is pre-cached).
    static func parseSidecar(at url: URL) -> SidecarData? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // Parse photoTakenTime.timestamp (Unix seconds as string)
        guard let photoTime = json["photoTakenTime"] as? [String: Any],
              let timestampStr = photoTime["timestamp"] as? String,
              let epoch = Int(timestampStr)
        else { return nil }

        let date = Date(timeIntervalSince1970: TimeInterval(epoch))

        // Parse geoData (user-corrected location, preferred over geoDataExif)
        var latitude: Double?
        var longitude: Double?
        if let geo = json["geoData"] as? [String: Any] {
            let lat = geo["latitude"] as? Double ?? 0
            let lon = geo["longitude"] as? Double ?? 0
            // Google uses 0,0 as "no location" — filter it out
            if lat != 0 || lon != 0 {
                latitude = lat
                longitude = lon
            }
        }

        return SidecarData(date: date, latitude: latitude, longitude: longitude)
    }

    // MARK: - Name Matching Strategies

    /// Strategy 2: Google truncates JSON filenames at 51 chars total.
    /// E.g., "Urlaub in Knaufspesch in der Schneifel (38).JPG"
    /// → JSON is "Urlaub in Knaufspesch in der Schneifel (38).JP.json" (51 chars)
    private static func shortenName(_ filename: String) -> String {
        let withJSON = filename + ".json"
        return withJSON.count > 51 ? String(filename.prefix(51 - ".json".count)) : filename
    }

    /// Strategy 3: Swap bracket position.
    /// "image(11).jpg" → "image.jpg(11)"
    /// Uses the last match to handle names like "image(3).(2)(3).jpg".
    private static func bracketSwap(_ filename: String) -> String {
        let pattern = try! NSRegularExpression(pattern: #"\(\d+\)\."#)
        let nsFilename = filename as NSString
        let matches = pattern.matches(in: filename, range: NSRange(location: 0, length: nsFilename.length))
        guard let lastMatch = matches.last else { return filename }

        let matchStr = nsFilename.substring(with: lastMatch.range)
        let bracket = matchStr.replacingOccurrences(of: ".", with: "") // "(11)" without dot
        let withoutBracket = filename.replacingLastOccurrence(of: bracket, with: "")
        return withoutBracket + bracket
    }

    /// Strategy 4: Remove known "-edited" etc. suffixes (NFC-normalized).
    private static func removeExtra(_ filename: String) -> String {
        let normalized = filename.nfcNormalized
        for suffix in editedSuffixes {
            if normalized.contains(suffix) {
                return normalized.replacingLastOccurrence(of: suffix, with: "")
            }
        }
        return normalized
    }

    /// Strategy 5: Strip file extension entirely.
    /// "20030616.jpg" → "20030616"
    private static func noExtension(_ filename: String) -> String {
        (filename as NSString).deletingPathExtension
    }

    /// Strategy 6 (tryhard): Regex-based suffix removal.
    /// Matches "-word(digit)" or "-word" immediately before extension.
    /// Only applied if exactly one match (safety check).
    private static func removeExtraRegex(_ filename: String) -> String {
        let normalized = filename.nfcNormalized
        let pattern = try! NSRegularExpression(
            pattern: "(?<extra>-[A-Za-z\u{00C0}-\u{00D6}\u{00D8}-\u{00F6}\u{00F8}-\u{00FF}]+(\\(\\d\\))?)\\.\\w+$"
        )
        let nsStr = normalized as NSString
        let matches = pattern.matches(in: normalized, range: NSRange(location: 0, length: nsStr.length))
        guard matches.count == 1,
              let extraRange = matches[0].range(withName: "extra") as NSRange?,
              extraRange.location != NSNotFound
        else { return normalized }

        return nsStr.replacingCharacters(in: extraRange, with: "")
    }

    /// Strategy 7 (tryhard): Remove "(digit)." → "."
    /// "photo(1).jpg" → "photo.jpg"
    private static func removeDigit(_ filename: String) -> String {
        filename.replacingOccurrences(
            of: #"\(\d\)\."#,
            with: ".",
            options: .regularExpression
        )
    }
}
