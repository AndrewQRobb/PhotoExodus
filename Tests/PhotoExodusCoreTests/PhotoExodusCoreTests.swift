import XCTest
@testable import PhotoExodusCore

// MARK: - Scanner Tests

final class ScannerTests: XCTestCase {
    func testYearFolderDetection() {
        XCTAssertTrue(Scanner.isYearFolder("Photos from 2023"))
        XCTAssertTrue(Scanner.isYearFolder("Photos from 1999"))
        XCTAssertTrue(Scanner.isYearFolder("Photos from 1800"))
        XCTAssertFalse(Scanner.isYearFolder("Photos from 2023 extra"))
        XCTAssertFalse(Scanner.isYearFolder("Vacation 2023"))
        XCTAssertFalse(Scanner.isYearFolder("Photos from 123"))
        XCTAssertFalse(Scanner.isYearFolder(""))
    }

    func testScanFindsMediaInYearFolders() throws {
        let root = makeTempDir()
        defer { cleanup(root) }

        // Create a year folder with media and a JSON sidecar
        let yearDir = root.appendingPathComponent("Photos from 2022")
        try FileManager.default.createDirectory(at: yearDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: yearDir.appendingPathComponent("photo.jpg").path, contents: Data([0xFF, 0xD8]))
        FileManager.default.createFile(atPath: yearDir.appendingPathComponent("photo.jpg.json").path,
                                        contents: #"{"photoTakenTime":{"timestamp":"1600000000"}}"#.data(using: .utf8))
        // Non-media file should be skipped
        FileManager.default.createFile(atPath: yearDir.appendingPathComponent("notes.txt").path, contents: Data())

        let items = try Scanner.scan(input: root)
        XCTAssertEqual(items.count, 1, "Should find exactly 1 media file")
        XCTAssertEqual(items[0].sourceURL.lastPathComponent, "photo.jpg")
        XCTAssertNotNil(items[0].jsonSidecarURL, "Sidecar should be pre-cached")
    }

    func testScanEmptyInputReturnsEmpty() throws {
        let root = makeTempDir()
        defer { cleanup(root) }
        let items = try Scanner.scan(input: root)
        XCTAssertTrue(items.isEmpty)
    }
}

// MARK: - JSON Sidecar Extractor Tests

final class JSONSidecarExtractorTests: XCTestCase {
    func testIdentityMatch() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let json = #"{"photoTakenTime":{"timestamp":"1599078832"},"geoData":{"latitude":37.7749,"longitude":-122.4194}}"#
        FileManager.default.createFile(atPath: dir.appendingPathComponent("photo.jpg.json").path,
                                        contents: json.data(using: .utf8))

        let fileURL = dir.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let result = JSONSidecarExtractor.extract(for: fileURL)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.latitude ?? 0, 37.7749, accuracy: 0.001)
        XCTAssertEqual(result?.longitude ?? 0, -122.4194, accuracy: 0.001)
    }

    func testShortenNameStrategy() throws {
        // Google truncates JSON filenames at 51 chars total
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let longName = "Urlaub in Knaufspesch in der Schneifel (38).JPG"
        // Truncated to 46 chars + ".json" = 51: "Urlaub in Knaufspesch in der Schneifel (38).JP.json"
        let truncatedJSON = "Urlaub in Knaufspesch in der Schneifel (38).JP.json"

        let json = #"{"photoTakenTime":{"timestamp":"1599078832"}}"#
        FileManager.default.createFile(atPath: dir.appendingPathComponent(truncatedJSON).path,
                                        contents: json.data(using: .utf8))
        let fileURL = dir.appendingPathComponent(longName)
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let result = JSONSidecarExtractor.extract(for: fileURL)
        XCTAssertNotNil(result, "Should find sidecar via shorten strategy")
    }

    func testBracketSwapStrategy() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        // image(11).jpg → image.jpg(11).json
        let json = #"{"photoTakenTime":{"timestamp":"1599078832"}}"#
        FileManager.default.createFile(atPath: dir.appendingPathComponent("image.jpg(11).json").path,
                                        contents: json.data(using: .utf8))
        let fileURL = dir.appendingPathComponent("image(11).jpg")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let result = JSONSidecarExtractor.extract(for: fileURL)
        XCTAssertNotNil(result, "Should find sidecar via bracket swap")
    }

    func testRemoveExtraStrategy() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        // photo-edited.jpg → photo.jpg.json
        let json = #"{"photoTakenTime":{"timestamp":"1599078832"}}"#
        FileManager.default.createFile(atPath: dir.appendingPathComponent("photo.jpg.json").path,
                                        contents: json.data(using: .utf8))
        let fileURL = dir.appendingPathComponent("photo-edited.jpg")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let result = JSONSidecarExtractor.extract(for: fileURL)
        XCTAssertNotNil(result, "Should find sidecar via remove-extra strategy")
    }

    func testTryhardRequired() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        // photo-edited(1).jpg needs tryhard to resolve to photo.jpg.json
        let json = #"{"photoTakenTime":{"timestamp":"1683074444"}}"#
        FileManager.default.createFile(atPath: dir.appendingPathComponent("photo.jpg.json").path,
                                        contents: json.data(using: .utf8))
        let fileURL = dir.appendingPathComponent("photo-edited(1).jpg")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        XCTAssertNil(JSONSidecarExtractor.extract(for: fileURL, tryhard: false),
                     "Should NOT find without tryhard")
        XCTAssertNotNil(JSONSidecarExtractor.extract(for: fileURL, tryhard: true),
                        "Should find with tryhard")
    }

    func testGeoDataZeroZeroFiltered() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let json = #"{"photoTakenTime":{"timestamp":"1599078832"},"geoData":{"latitude":0.0,"longitude":0.0}}"#
        FileManager.default.createFile(atPath: dir.appendingPathComponent("photo.jpg.json").path,
                                        contents: json.data(using: .utf8))
        let fileURL = dir.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let result = JSONSidecarExtractor.extract(for: fileURL)
        XCTAssertNotNil(result)
        XCTAssertNil(result?.latitude, "0,0 GPS should be filtered out")
    }
}

// MARK: - Filename Guess Tests

final class FilenameGuessTests: XCTestCase {
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func testAllPatterns() throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        let cases: [(String, String)] = [
            ("Screenshot_20190919-053857_Camera.jpg", "2019-09-19 05:38:57"),
            ("IMG_20190509_154733.jpg", "2019-05-09 15:47:33"),
            ("Screenshot_2019-04-16-11-19-37-232_com.google.jpg", "2019-04-16 11:19:37"),
            ("signal-2020-10-26-163832.jpg", "2020-10-26 16:38:32"),
            ("BURST20190216172030.jpg", "2019-02-16 17:20:30"),
            ("2016_01_30_11_49_15.mp4", "2016-01-30 11:49:15"),
        ]

        for (filename, expected) in cases {
            let url = tempDir.appendingPathComponent(filename)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            let date = FilenameGuessExtractor.extract(from: url)
            XCTAssertNotNil(date, "Failed to extract date from \(filename)")
            if let date = date {
                XCTAssertEqual(formatter.string(from: date), expected,
                               "Wrong date for \(filename)")
            }
        }
    }

    func testNoMatchReturnsNil() {
        let url = URL(fileURLWithPath: "/tmp/random_photo.jpg")
        XCTAssertNil(FilenameGuessExtractor.extract(from: url))
    }
}

// MARK: - Extras Remover Tests

final class ExtrasRemoverTests: XCTestCase {
    func testEditedSuffixDetection() throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        let editedFile = tempDir.appendingPathComponent("photo-edited.jpg")
        let normalFile = tempDir.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: editedFile.path, contents: nil)
        FileManager.default.createFile(atPath: normalFile.path, contents: nil)

        var items = [MediaItem(sourceURL: editedFile), MediaItem(sourceURL: normalFile)]
        let count = ExtrasRemover.removeExtras(from: &items)
        XCTAssertEqual(count, 1)
        XCTAssertTrue(items[0].isEditedCopy)
        XCTAssertFalse(items[1].isEditedCopy)
    }

    func testMultilingualSuffixes() throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        let suffixes = ["-bearbeitet", "-modifi\u{00E9}", "-\u{7DE8}\u{96C6}\u{6E08}\u{307F}"]
        var items: [MediaItem] = []
        for suffix in suffixes {
            let url = tempDir.appendingPathComponent("photo\(suffix).jpg")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            items.append(MediaItem(sourceURL: url))
        }

        let count = ExtrasRemover.removeExtras(from: &items)
        XCTAssertEqual(count, 3, "All multilingual suffixes should be detected")
    }

    func testSkipsDuplicateItems() throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        let url = tempDir.appendingPathComponent("photo-edited.jpg")
        FileManager.default.createFile(atPath: url.path, contents: nil)

        var items = [MediaItem(sourceURL: url)]
        items[0].isDuplicate = true
        let count = ExtrasRemover.removeExtras(from: &items)
        XCTAssertEqual(count, 0, "Should skip items already marked as duplicate")
    }
}

// MARK: - Deduplicator Tests

final class DeduplicatorTests: XCTestCase {
    func testIdenticalFilesDeduped() throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        let content = Data([1, 2, 3, 4, 5, 6, 7, 8])
        let file1 = tempDir.appendingPathComponent("photo.jpg")
        let file2 = tempDir.appendingPathComponent("photo(1).jpg")
        FileManager.default.createFile(atPath: file1.path, contents: content)
        FileManager.default.createFile(atPath: file2.path, contents: content)

        var items = [MediaItem(sourceURL: file1), MediaItem(sourceURL: file2)]
        let count = Deduplicator.removeDuplicates(from: &items)
        XCTAssertEqual(count, 1)
        // Shorter filename should be kept
        let kept = items.filter { !$0.isDuplicate }
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(kept[0].sourceURL.lastPathComponent, "photo.jpg")
    }

    func testDifferentFilesSurvive() throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        let file1 = tempDir.appendingPathComponent("a.jpg")
        let file2 = tempDir.appendingPathComponent("b.jpg")
        FileManager.default.createFile(atPath: file1.path, contents: Data([1, 2, 3]))
        FileManager.default.createFile(atPath: file2.path, contents: Data([4, 5, 6]))

        var items = [MediaItem(sourceURL: file1), MediaItem(sourceURL: file2)]
        let count = Deduplicator.removeDuplicates(from: &items)
        XCTAssertEqual(count, 0)
    }

    func testSameSizeDifferentContent() throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        let file1 = tempDir.appendingPathComponent("a.jpg")
        let file2 = tempDir.appendingPathComponent("b.jpg")
        FileManager.default.createFile(atPath: file1.path, contents: Data([1, 2, 3]))
        FileManager.default.createFile(atPath: file2.path, contents: Data([4, 5, 6]))

        var items = [MediaItem(sourceURL: file1), MediaItem(sourceURL: file2)]
        let count = Deduplicator.removeDuplicates(from: &items)
        XCTAssertEqual(count, 0, "Same size but different content should not dedup")
    }
}

// MARK: - Utility Tests

final class UtilityTests: XCTestCase {
    func testFindNotExistingName() throws {
        let tempDir = makeTempDir()
        defer { cleanup(tempDir) }

        let first = findNotExistingName(for: "photo.jpg", in: tempDir)
        XCTAssertEqual(first.lastPathComponent, "photo.jpg")

        FileManager.default.createFile(atPath: first.path, contents: nil)
        let second = findNotExistingName(for: "photo.jpg", in: tempDir)
        XCTAssertEqual(second.lastPathComponent, "photo(1).jpg")

        FileManager.default.createFile(atPath: second.path, contents: nil)
        let third = findNotExistingName(for: "photo.jpg", in: tempDir)
        XCTAssertEqual(third.lastPathComponent, "photo(2).jpg")
    }

    func testNFCNormalization() {
        let nfd = "modifie\u{0301}" // NFD: e + combining acute
        let nfc = "modifi\u{00E9}"  // NFC: precomposed é
        XCTAssertEqual(nfd.nfcNormalized, nfc)
    }

    func testReplacingLastOccurrence() {
        XCTAssertEqual("abc-def-abc".replacingLastOccurrence(of: "abc", with: "xyz"), "abc-def-xyz")
        XCTAssertEqual("hello".replacingLastOccurrence(of: "xyz", with: ""), "hello")
    }

    func testMediaFileDetection() {
        XCTAssertTrue(URL(fileURLWithPath: "/tmp/photo.jpg").isMediaFile)
        XCTAssertTrue(URL(fileURLWithPath: "/tmp/video.mp4").isMediaFile)
        XCTAssertTrue(URL(fileURLWithPath: "/tmp/clip.mts").isMediaFile)
        XCTAssertFalse(URL(fileURLWithPath: "/tmp/data.json").isMediaFile)
        XCTAssertFalse(URL(fileURLWithPath: "/tmp/notes.txt").isMediaFile)
    }
}

// MARK: - FileMover Tests

final class FileMoverTests: XCTestCase {
    func testDateOrganizedOutput() throws {
        let tempDir = makeTempDir()
        let output = makeTempDir()
        defer { cleanup(tempDir); cleanup(output) }

        let file = tempDir.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: file.path, contents: Data([0xFF, 0xD8]))

        let item = MediaItem(sourceURL: file)
        item.metadata.dateTaken = DateFormatter.testFormatter.date(from: "2022-03-15 14:30:00")

        let failures = FileMover.moveFiles([item], to: output)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertNotNil(item.destinationURL)
        XCTAssertTrue(item.destinationURL?.path.contains("2022/03") ?? false,
                      "Should be in YYYY/MM subfolder")
    }

    func testDateUnknownFolder() throws {
        let tempDir = makeTempDir()
        let output = makeTempDir()
        defer { cleanup(tempDir); cleanup(output) }

        let file = tempDir.appendingPathComponent("mystery.jpg")
        FileManager.default.createFile(atPath: file.path, contents: Data([0xFF, 0xD8]))

        let item = MediaItem(sourceURL: file)
        // No date set

        let failures = FileMover.moveFiles([item], to: output)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertTrue(item.destinationURL?.path.contains("date-unknown") ?? false)
    }

    func testDuplicatesSkipped() throws {
        let tempDir = makeTempDir()
        let output = makeTempDir()
        defer { cleanup(tempDir); cleanup(output) }

        let file = tempDir.appendingPathComponent("dup.jpg")
        FileManager.default.createFile(atPath: file.path, contents: Data([1]))

        let item = MediaItem(sourceURL: file)
        item.isDuplicate = true

        let failures = FileMover.moveFiles([item], to: output)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertNil(item.destinationURL, "Duplicate should not be moved")
    }
}

// MARK: - Test Helpers

private func makeTempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func cleanup(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

private extension DateFormatter {
    static let testFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
