import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes metadata (date, GPS) into image EXIF and converts WebP→JPEG.
enum MetadataWriter {

    /// Write metadata into an image file's EXIF data.
    /// For WebP files, converts to JPEG at maximum quality.
    /// Returns the final URL (may differ from source if format was converted).
    @discardableResult
    static func writeMetadata(for item: MediaItem) throws -> URL {
        let sourceURL = item.sourceURL

        // Only write EXIF for image files — videos get file mod time only
        guard sourceURL.isImageFile else {
            if let date = item.metadata.dateTaken {
                try FileManager.default.setAttributes(
                    [.modificationDate: date],
                    ofItemAtPath: sourceURL.path
                )
            }
            return sourceURL
        }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw MetadataWriterError.cannotReadSource(sourceURL)
        }

        // Determine output format — convert WebP to JPEG
        let outputUTType: UTType
        let outputURL: URL
        if sourceURL.isWebP {
            outputUTType = .jpeg
            outputURL = sourceURL.deletingPathExtension().appendingPathExtension("jpg")
        } else {
            let sourceType = CGImageSourceGetType(source) as? String
            outputUTType = sourceType.flatMap { UTType($0) } ?? .jpeg
            outputURL = sourceURL
        }

        // Read existing properties and merge our metadata
        var props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        mergeMetadata(into: &props, from: item.metadata)

        // Write to temp file, then atomic swap
        let tempURL = outputURL.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).tmp")

        guard let destination = CGImageDestinationCreateWithURL(
            tempURL as CFURL,
            outputUTType.identifier as CFString,
            1,
            nil
        ) else {
            throw MetadataWriterError.cannotCreateDestination(outputURL)
        }

        // For JPEG output (including WebP→JPEG), set max quality
        var destOptions: [String: Any] = [:]
        if outputUTType == .jpeg {
            destOptions[kCGImageDestinationLossyCompressionQuality as String] = 1.0
        }

        CGImageDestinationAddImageFromSource(
            destination, source, 0,
            destOptions.isEmpty ? props as CFDictionary : props.merging(destOptions) { _, new in new } as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw MetadataWriterError.finalizeFailed(outputURL)
        }

        // Safe file replacement
        let fm = FileManager.default
        if sourceURL == outputURL {
            // Same format: atomic replace
            _ = try fm.replaceItemAt(sourceURL, withItemAt: tempURL)
        } else {
            // WebP→JPEG: place new file first, then remove old
            try fm.moveItem(at: tempURL, to: outputURL)
            try? fm.removeItem(at: sourceURL)
        }

        return outputURL
    }

    // MARK: - Metadata Merging

    /// Merge date and GPS metadata into an existing EXIF properties dictionary.
    /// Preserves all existing properties that we don't explicitly set.
    private static func mergeMetadata(into props: inout [String: Any],
                                      from metadata: MetadataBundle) {
        // Date → EXIF dictionary
        if let date = metadata.dateTaken {
            let dateStr = exifDateString(from: date)

            var exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            exif[kCGImagePropertyExifDateTimeOriginal as String] = dateStr
            exif[kCGImagePropertyExifDateTimeDigitized as String] = dateStr
            props[kCGImagePropertyExifDictionary as String] = exif

            var tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            tiff[kCGImagePropertyTIFFDateTime as String] = dateStr
            props[kCGImagePropertyTIFFDictionary as String] = tiff
        }

        // GPS → GPS dictionary
        if let lat = metadata.latitude, let lon = metadata.longitude {
            var gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
            gps[kCGImagePropertyGPSLatitude as String] = abs(lat)
            gps[kCGImagePropertyGPSLatitudeRef as String] = lat >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude as String] = abs(lon)
            gps[kCGImagePropertyGPSLongitudeRef as String] = lon >= 0 ? "E" : "W"
            props[kCGImagePropertyGPSDictionary as String] = gps
        }
    }

    /// Format a Date as EXIF date string: "2022:12:16 16:06:47"
    private static func exifDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

enum MetadataWriterError: LocalizedError {
    case cannotReadSource(URL)
    case cannotCreateDestination(URL)
    case finalizeFailed(URL)

    var errorDescription: String? {
        switch self {
        case .cannotReadSource(let url): "Cannot read image: \(url.lastPathComponent)"
        case .cannotCreateDestination(let url): "Cannot create output: \(url.lastPathComponent)"
        case .finalizeFailed(let url): "Failed to write image: \(url.lastPathComponent)"
        }
    }
}
