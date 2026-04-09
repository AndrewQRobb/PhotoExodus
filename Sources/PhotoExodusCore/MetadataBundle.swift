import Foundation
import CoreLocation

/// Aggregated metadata extracted from various sources for a single media item.
struct MetadataBundle: Sendable {
    var dateTaken: Date?
    var dateSource: DateSource = .unknown
    var latitude: Double?
    var longitude: Double?
    var gpsSource: GPSSource = .none

    var hasGPS: Bool { latitude != nil && longitude != nil }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Lower raw value = more authoritative.
    enum DateSource: Int, Comparable, Sendable, CustomStringConvertible {
        case jsonSidecar = 0
        case exif = 1
        case filenameGuess = 2
        case tryhardJSON = 3
        case unknown = 99

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var description: String {
            switch self {
            case .jsonSidecar: "JSON Sidecar"
            case .exif: "EXIF"
            case .filenameGuess: "Filename"
            case .tryhardJSON: "JSON (tryhard)"
            case .unknown: "Unknown"
            }
        }
    }

    enum GPSSource: Sendable {
        case jsonSidecar, exif, none
    }
}
