import Foundation
import CryptoKit

/// Maximum file size for EXIF reading and SHA-256 hashing (64 MiB).
/// Files larger than this get a sentinel hash and skip EXIF extraction.
let maxFileSize = 64 * 1024 * 1024

/// Core data model representing a single photo or video file in the pipeline.
/// Reference type because the pipeline mutates items in place across stages.
final class MediaItem: Identifiable, @unchecked Sendable {
    let id = UUID()
    let sourceURL: URL
    var destinationURL: URL?
    var metadata = MetadataBundle()
    var jsonSidecarURL: URL?

    /// URL after metadata writing / format conversion (may differ from sourceURL for WebP→JPEG).
    var effectiveSourceURL: URL?

    var isDuplicate = false
    var isEditedCopy = false
    var failureReason: String?

    /// The URL to use for file operations (post-conversion if applicable).
    var currentURL: URL { effectiveSourceURL ?? sourceURL }

    // Lazy-cached
    private var _fileSize: Int?
    private var _sha256: Data?

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }

    /// File size in bytes. Cached after first access.
    func fileSize() throws -> Int {
        if let cached = _fileSize { return cached }
        let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let size = (attrs[.size] as? Int) ?? 0
        _fileSize = size
        return size
    }

    /// SHA-256 hash of file contents. Returns sentinel `Data([0])` for files > 64 MiB.
    /// Cached after first computation.
    func sha256Hash() throws -> Data {
        if let cached = _sha256 { return cached }
        let size = try fileSize()
        if size > maxFileSize {
            let sentinel = Data([0])
            _sha256 = sentinel
            return sentinel
        }
        let data = try Data(contentsOf: sourceURL)
        let digest = SHA256.hash(data: data)
        let hashData = Data(digest)
        _sha256 = hashData
        return hashData
    }
}
