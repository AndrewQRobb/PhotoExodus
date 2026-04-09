import Foundation

/// Represents a disagreement between JSON sidecar and EXIF metadata
/// that needs user resolution.
public struct MetadataConflict: Identifiable, Sendable {
    public let id = UUID()
    public let itemID: UUID
    public let sourceURL: URL
    public let jsonDate: Date?
    public let exifDate: Date?
    public let jsonLatitude: Double?
    public let jsonLongitude: Double?
    public let exifLatitude: Double?
    public let exifLongitude: Double?
    public var resolution: Resolution?

    public enum Resolution: Sendable {
        case useJSON
        case useEXIF
        case skip
    }
}
