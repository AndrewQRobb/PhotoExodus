import SwiftUI
import PhotoExodusCore

struct ConflictReviewView: View {
    let conflict: MetadataConflict
    let onResolve: (MetadataConflict.Resolution) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Metadata Conflict")
                .font(.title2.bold())

            Text(conflict.sourceURL.lastPathComponent)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                // Image preview
                if let nsImage = NSImage(contentsOf: conflict.sourceURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: 200, height: 200)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }

                // Metadata comparison
                VStack(spacing: 16) {
                    metadataCard(
                        title: "JSON Sidecar",
                        date: conflict.jsonDate,
                        latitude: conflict.jsonLatitude,
                        longitude: conflict.jsonLongitude,
                        color: .blue
                    ) {
                        onResolve(.useJSON)
                    }

                    metadataCard(
                        title: "EXIF in File",
                        date: conflict.exifDate,
                        latitude: conflict.exifLatitude,
                        longitude: conflict.exifLongitude,
                        color: .orange
                    ) {
                        onResolve(.useEXIF)
                    }
                }
            }

            Button("Skip This File") {
                onResolve(.skip)
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private func metadataCard(
        title: String,
        date: Date?,
        latitude: Double?,
        longitude: Double?,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)

                if let date = date {
                    Label(date.formatted(date: .long, time: .standard), systemImage: "calendar")
                        .font(.caption)
                } else {
                    Label("No date", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lat = latitude, let lon = longitude {
                    Label(String(format: "%.4f, %.4f", lat, lon), systemImage: "location")
                        .font(.caption)
                } else {
                    Label("No GPS", systemImage: "location.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Use This") { action() }
                    .buttonStyle(.borderedProminent)
                    .tint(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
