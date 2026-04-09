import Foundation
import UniformTypeIdentifiers

// MARK: - NFC Normalization

extension String {
    /// Unicode NFC normalization. macOS filenames arrive in NFD form;
    /// this must be applied before suffix matching and sidecar lookups.
    var nfcNormalized: String {
        precomposedStringWithCanonicalMapping
    }

    /// Replace only the last occurrence of `target` with `replacement`.
    func replacingLastOccurrence(of target: String, with replacement: String) -> String {
        guard let range = range(of: target, options: .backwards) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}

// MARK: - MIME Type Detection

extension URL {
    /// Whether this file is a photo or video based on its UTType.
    var isMediaFile: Bool {
        guard let uttype = UTType(filenameExtension: pathExtension) else {
            // Special case: .mts video files may not resolve via UTType
            return pathExtension.lowercased() == "mts"
        }
        return uttype.conforms(to: .image) || uttype.conforms(to: .movie) ||
               uttype.conforms(to: .video) || uttype.conforms(to: .audiovisualContent)
    }

    /// Whether this is an image file (for EXIF extraction).
    var isImageFile: Bool {
        guard let uttype = UTType(filenameExtension: pathExtension) else { return false }
        return uttype.conforms(to: .image)
    }

    /// Whether this is a WebP file that needs conversion.
    var isWebP: Bool {
        pathExtension.lowercased() == "webp"
    }
}

// MARK: - File Naming

/// Find a non-existing filename by appending (1), (2), etc. before the extension.
/// Exact port of Dart's findNotExistingName.
func findNotExistingName(for filename: String, in directory: URL) -> URL {
    let fm = FileManager.default
    let base = (filename as NSString).deletingPathExtension
    let ext = (filename as NSString).pathExtension

    var candidate = directory.appendingPathComponent(filename)
    var counter = 1
    while fm.fileExists(atPath: candidate.path) {
        let newName = ext.isEmpty ? "\(base)(\(counter))" : "\(base)(\(counter)).\(ext)"
        candidate = directory.appendingPathComponent(newName)
        counter += 1
    }
    return candidate
}
