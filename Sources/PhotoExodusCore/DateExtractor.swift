import Foundation

/// Orchestrates the 3-stage date/GPS extraction pipeline and detects metadata conflicts.
enum DateExtractor {

    /// Run the extraction pipeline on all active (non-duplicate, non-edited) items.
    /// Returns a list of metadata conflicts that need user resolution.
    static func extractAll(
        from items: [MediaItem],
        conflictThreshold: TimeInterval = 86400,
        progress: @Sendable (Int, Int) -> Void = { _, _ in }
    ) -> [MetadataConflict] {
        var conflicts: [MetadataConflict] = []
        let activeItems = items.filter { !$0.isDuplicate && !$0.isEditedCopy }
        let total = activeItems.count

        for (index, item) in activeItems.enumerated() {
            // Collect data from all sources before deciding
            let jsonData = extractJSON(for: item)
            let exifData = EXIFExtractor.extract(from: item.sourceURL)
            let guessDate = FilenameGuessExtractor.extract(from: item.sourceURL)

            // Check for conflicts between JSON and EXIF
            if let conflict = detectConflict(
                item: item,
                jsonData: jsonData,
                exifData: exifData,
                threshold: conflictThreshold
            ) {
                conflicts.append(conflict)
                // Don't set metadata yet — will be set after user resolution
            } else {
                // No conflict — apply best available metadata
                applyBestMetadata(to: item, json: jsonData, exif: exifData, guess: guessDate)
            }

            progress(index + 1, total)
        }

        return conflicts
    }

    /// Apply a conflict resolution to an item.
    static func applyResolution(_ resolution: MetadataConflict.Resolution,
                                to item: MediaItem,
                                jsonData: SidecarData?,
                                exifData: EXIFExtractor.ExifData?) {
        switch resolution {
        case .useJSON:
            if let json = jsonData {
                item.metadata.dateTaken = json.date
                item.metadata.dateSource = .jsonSidecar
                item.metadata.latitude = json.latitude
                item.metadata.longitude = json.longitude
                item.metadata.gpsSource = json.latitude != nil ? .jsonSidecar : .none
            }
        case .useEXIF:
            if let exif = exifData {
                item.metadata.dateTaken = exif.date
                item.metadata.dateSource = .exif
                item.metadata.latitude = exif.latitude
                item.metadata.longitude = exif.longitude
                item.metadata.gpsSource = exif.latitude != nil ? .exif : .none
            }
        case .skip:
            // Leave metadata empty — file will go to date-unknown
            break
        }
    }

    // MARK: - Private

    private static func extractJSON(for item: MediaItem) -> SidecarData? {
        // Use pre-cached sidecar URL to avoid redundant filesystem probing
        guard let jsonURL = item.jsonSidecarURL else { return nil }
        return JSONSidecarExtractor.parseSidecar(at: jsonURL)
    }

    /// Apply the best available metadata from all sources.
    /// Priority: JSON (0) > EXIF (1) > guess (2) > tryhard JSON (3)
    private static func applyBestMetadata(
        to item: MediaItem,
        json: SidecarData?,
        exif: EXIFExtractor.ExifData?,
        guess: Date?
    ) {
        // Date: try sources in priority order
        if let json = json {
            item.metadata.dateTaken = json.date
            item.metadata.dateSource = .jsonSidecar
        } else if let exifDate = exif?.date {
            item.metadata.dateTaken = exifDate
            item.metadata.dateSource = .exif
        } else if let guessDate = guess {
            item.metadata.dateTaken = guessDate
            item.metadata.dateSource = .filenameGuess
        } else {
            // Last resort: tryhard JSON
            if let tryhardData = JSONSidecarExtractor.extract(
                for: item.sourceURL, tryhard: true
            ) {
                item.metadata.dateTaken = tryhardData.date
                item.metadata.dateSource = .tryhardJSON
                // Also grab GPS from tryhard if available
                if tryhardData.latitude != nil {
                    item.metadata.latitude = tryhardData.latitude
                    item.metadata.longitude = tryhardData.longitude
                    item.metadata.gpsSource = .jsonSidecar
                }
            }
        }

        // GPS: prefer JSON, fall back to EXIF
        if item.metadata.latitude == nil {
            if let json = json, json.latitude != nil {
                item.metadata.latitude = json.latitude
                item.metadata.longitude = json.longitude
                item.metadata.gpsSource = .jsonSidecar
            } else if let exifLat = exif?.latitude, let exifLon = exif?.longitude {
                item.metadata.latitude = exifLat
                item.metadata.longitude = exifLon
                item.metadata.gpsSource = .exif
            }
        }
    }

    /// Detect a conflict when both JSON and EXIF provide dates that differ
    /// by more than the threshold.
    private static func detectConflict(
        item: MediaItem,
        jsonData: SidecarData?,
        exifData: EXIFExtractor.ExifData?,
        threshold: TimeInterval
    ) -> MetadataConflict? {
        guard let jsonDate = jsonData?.date,
              let exifDate = exifData?.date
        else { return nil }

        let dateDiff = abs(jsonDate.timeIntervalSince(exifDate))

        // Also check GPS disagreement
        let gpsDiff: Bool = {
            guard let jLat = jsonData?.latitude, let jLon = jsonData?.longitude,
                  let eLat = exifData?.latitude, let eLon = exifData?.longitude
            else { return false }
            return abs(jLat - eLat) > 0.01 || abs(jLon - eLon) > 0.01
        }()

        // Only flag as conflict if dates differ significantly OR GPS disagrees
        guard dateDiff > threshold || gpsDiff else { return nil }

        return MetadataConflict(
            itemID: item.id,
            sourceURL: item.sourceURL,
            jsonDate: jsonDate,
            exifDate: exifDate,
            jsonLatitude: jsonData?.latitude,
            jsonLongitude: jsonData?.longitude,
            exifLatitude: exifData?.latitude,
            exifLongitude: exifData?.longitude
        )
    }
}
