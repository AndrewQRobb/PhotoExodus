import Foundation

/// Abstraction for file movement — enables dry-run mode without changing pipeline logic.
protocol MoveStrategy: Sendable {
    func moveOrCopy(from source: URL, to destination: URL) throws
    func setModificationDate(_ date: Date, on url: URL) throws
}

/// Moves files for real. Falls back to copy+delete for cross-volume moves.
struct RealMoveStrategy: MoveStrategy {
    func moveOrCopy(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        do {
            try fm.moveItem(at: source, to: destination)
        } catch let error as NSError where error.code == NSFileWriteUnknownError ||
                                           error.code == 512 {
            // Cross-volume move — fall back to copy + delete
            try fm.copyItem(at: source, to: destination)
            try fm.removeItem(at: source)
        }
    }

    func setModificationDate(_ date: Date, on url: URL) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: date],
            ofItemAtPath: url.path
        )
    }
}

/// Logs intended operations without touching the filesystem.
struct DryRunMoveStrategy: MoveStrategy {
    func moveOrCopy(from source: URL, to destination: URL) throws {
        // No-op: would move \(source.lastPathComponent) → \(destination.path)
    }

    func setModificationDate(_ date: Date, on url: URL) throws {
        // No-op: would set date on \(url.lastPathComponent)
    }
}
