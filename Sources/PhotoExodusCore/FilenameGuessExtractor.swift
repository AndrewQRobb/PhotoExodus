import Foundation

/// Extracts date from common camera/screenshot filename patterns.
/// Direct port of Dart's guess_extractor.dart with all 6 patterns.
enum FilenameGuessExtractor {

    // Cache DateFormatters to avoid per-call allocation
    private static let formatters: [String: DateFormatter] = {
        var result: [String: DateFormatter] = [:]
        for format in ["yyyyMMdd-HHmmss", "yyyyMMdd_HHmmss", "yyyy-MM-dd-HH-mm-ss",
                        "yyyy-MM-dd-HHmmss", "yyyyMMddHHmmss", "yyyy_MM_dd_HH_mm_ss"] {
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            f.isLenient = false
            result[format] = f
        }
        return result
    }()

    // All patterns use named capture group "date".
    // Month is validated with explicit alternation (01-12).
    // Year prefix restricted to 18xx, 19xx, 20xx.
    private static let patterns: [(NSRegularExpression, String)] = {
        let defs: [(String, String)] = [
            // 1. YYYYMMDD-hhmmss — Screenshot_20190919-053857_Camera.jpg
            (#"(?<date>(20|19|18)\d{2}(01|02|03|04|05|06|07|08|09|10|11|12)[0-3]\d-\d{6})"#,
             "yyyyMMdd-HHmmss"),
            // 2. YYYYMMDD_hhmmss — IMG_20190509_154733.jpg
            (#"(?<date>(20|19|18)\d{2}(01|02|03|04|05|06|07|08|09|10|11|12)[0-3]\d_\d{6})"#,
             "yyyyMMdd_HHmmss"),
            // 3. YYYY-MM-DD-hh-mm-ss — Screenshot_2019-04-16-11-19-37-232.jpg
            (#"(?<date>(20|19|18)\d{2}-(01|02|03|04|05|06|07|08|09|10|11|12)-[0-3]\d-\d{2}-\d{2}-\d{2})"#,
             "yyyy-MM-dd-HH-mm-ss"),
            // 4. YYYY-MM-DD-hhmmss — signal-2020-10-26-163832.jpg
            (#"(?<date>(20|19|18)\d{2}-(01|02|03|04|05|06|07|08|09|10|11|12)-[0-3]\d-\d{6})"#,
             "yyyy-MM-dd-HHmmss"),
            // 5. YYYYMMDDhhmmss — BURST20190216172030.jpg, 201801261147521000.jpg
            (#"(?<date>(20|19|18)\d{2}(01|02|03|04|05|06|07|08|09|10|11|12)[0-3]\d{7})"#,
             "yyyyMMddHHmmss"),
            // 6. YYYY_MM_DD_hh_mm_ss — 2016_01_30_11_49_15.mp4
            (#"(?<date>(20|19|18)\d{2}_(01|02|03|04|05|06|07|08|09|10|11|12)_[0-3]\d_\d{2}_\d{2}_\d{2})"#,
             "yyyy_MM_dd_HH_mm_ss"),
        ]
        return defs.map { pattern, format in
            (try! NSRegularExpression(pattern: pattern), format)
        }
    }()

    /// Attempt to guess a date from the file's name.
    static func extract(from url: URL) -> Date? {
        let filename = url.lastPathComponent

        for (regex, dateFormat) in patterns {
            let nsFilename = filename as NSString
            guard let match = regex.firstMatch(
                in: filename,
                range: NSRange(location: 0, length: nsFilename.length)
            ) else { continue }

            let dateRange = match.range(withName: "date")
            guard dateRange.location != NSNotFound else { continue }
            let dateStr = nsFilename.substring(with: dateRange)

            if let date = formatters[dateFormat]?.date(from: dateStr) {
                return date
            }
        }
        return nil
    }
}
