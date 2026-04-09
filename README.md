# PhotoExodus

A native macOS app for migrating your Google Photos library to Apple Photos with maximum metadata fidelity.

Forked from [GooglePhotosTakeoutHelper](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper) and rewritten from scratch in Swift as a SwiftUI desktop app.

## Features

- **JSON sidecar extraction** -- reads timestamps and GPS coordinates from Google's `.json` sidecar files using 7 name-matching strategies
- **EXIF metadata writing** -- writes date taken and GPS coordinates directly into image files
- **WebP to JPEG conversion** -- converts WebP images to JPEG at maximum quality
- **Deduplication** -- identifies duplicate files by SHA-256 hash, keeps the best copy
- **Edited copy removal** -- detects "-edited" suffixes in 8+ languages and removes duplicates
- **Conflict resolution** -- when JSON and EXIF metadata disagree, presents both options for you to choose
- **Date-organized output** -- outputs files in `YYYY/MM/` folder structure for easy visual review before importing

## Usage

1. Export your Google Photos library via [Google Takeout](https://takeout.google.com/)
2. Unzip all archives and merge into one folder
3. Open PhotoExodus, select your input folder and an output folder
4. Review any metadata conflicts when prompted
5. Drag the output folder into Apple Photos

## Building

Requires macOS 14+ (Sonoma) and Xcode or Swift toolchain.

```bash
swift build
swift test
```

## Architecture

The project is split into two SPM targets:

- **PhotoExodusCore** -- a pure Swift library containing all processing logic (15 modules), fully testable with no UI dependencies
- **PhotoExodus** -- a SwiftUI app that provides the GUI and drives the processing pipeline

### Processing pipeline

1. **Scan** -- find all media files and pre-cache JSON sidecar locations
2. **Deduplicate** -- group by file size, then SHA-256 hash
3. **Remove extras** -- flag edited copies using multilingual suffix matching
4. **Extract dates** -- JSON sidecar, EXIF, filename pattern (3-stage fallback)
5. **Write metadata** -- embed EXIF timestamps and GPS, convert WebP to JPEG
6. **Move files** -- organize into date folders, set file modification dates

## License

See [LICENSE](LICENSE).

## Credits

Originally based on [GooglePhotosTakeoutHelper](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper) by TheLastGimbus.
