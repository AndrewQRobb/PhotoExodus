import Foundation
import ImageIO
import CoreLocation

/// Extracts date and GPS from image EXIF metadata using ImageIO.
enum EXIFExtractor {

    struct ExifData {
        let date: Date?
        let latitude: Double?
        let longitude: Double?
    }

    /// Extract EXIF date and GPS from an image file.
    /// - Returns: nil if not an image, file too large, or no EXIF data found.
    static func extract(from url: URL) -> ExifData? {
        guard url.isImageFile else { return nil }

        // Skip files larger than 64 MiB (same as Dart reference)
        if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
           size > maxFileSize {
            return nil
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { return nil }

        let date = extractDate(from: props)
        let (latitude, longitude) = extractGPS(from: props)

        if date == nil && latitude == nil { return nil }
        return ExifData(date: date, latitude: latitude, longitude: longitude)
    }

    /// Read all EXIF/TIFF/GPS properties for conflict detection and metadata writing.
    static func readAllProperties(from url: URL) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
    }

    // MARK: - Date Extraction

    private static func extractDate(from props: [String: Any]) -> Date? {
        // Try EXIF tags in priority order (matching Dart reference)
        let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiffDict = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        let candidates: [String?] = [
            tiffDict?[kCGImagePropertyTIFFDateTime as String] as? String,
            exifDict?[kCGImagePropertyExifDateTimeOriginal as String] as? String,
            exifDict?[kCGImagePropertyExifDateTimeDigitized as String] as? String,
        ]

        for candidate in candidates {
            if let dateStr = candidate, let date = parseExifDate(dateStr) {
                return date
            }
        }
        return nil
    }

    /// Parse EXIF date string with normalization for malformed data.
    /// Standard format: "2022:12:16 16:06:47"
    /// Port of Dart's date string normalization pipeline.
    private static let exifDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func parseExifDate(_ raw: String) -> Date? {
        // Normalize separators: replace -, /, ., \ with :
        var s = raw
        for sep in ["-", "/", ".", "\\"] {
            s = s.replacingOccurrences(of: sep, with: ":")
        }
        // Handle single-digit seconds with leading space: ": " → ":0"
        s = s.replacingOccurrences(of: ": ", with: ":0")
        // Truncate to 19 chars max
        if s.count > 19 { s = String(s.prefix(19)) }
        // Convert "YYYY:MM:DD HH:MM:SS" → "YYYY-MM-DD HH:MM:SS"
        if s.count >= 10 {
            var chars = Array(s)
            if chars.count > 4 && chars[4] == ":" { chars[4] = "-" }
            if chars.count > 7 && chars[7] == ":" { chars[7] = "-" }
            s = String(chars)
        }

        return exifDateFormatter.date(from: s)
    }

    // MARK: - GPS Extraction

    private static func extractGPS(from props: [String: Any]) -> (Double?, Double?) {
        guard let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return (nil, nil)
        }

        guard let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
        else { return (nil, nil) }

        let latitude = latRef == "S" ? -lat : lat
        let longitude = lonRef == "W" ? -lon : lon

        // Filter out 0,0 (often means "no location")
        if latitude == 0 && longitude == 0 { return (nil, nil) }
        return (latitude, longitude)
    }
}
