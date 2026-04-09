import SwiftUI
import PhotoExodusCore

struct SummaryView: View {
    let result: ProcessingResult
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            if result.failures.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Migration Complete")
                    .font(.title2.bold())
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Migration Complete with Warnings")
                    .font(.title2.bold())
            }

            // Stats grid
            GroupBox("Summary") {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    statRow("Total scanned", result.totalScanned)
                    statRow("Successfully moved", result.successfullyMoved)
                    statRow("Duplicates removed", result.duplicatesRemoved)
                    statRow("Edited copies removed", result.editedCopiesRemoved)
                    statRow("Conflicts resolved", result.conflictsResolved)
                    statRow("Formats converted", result.filesConverted)
                    statRow("Date unknown", result.dateUnknownCount)
                    statRow("Failures", result.failures.count)
                }
                .padding(.vertical, 4)
            }

            // Failure log
            if !result.failures.isEmpty {
                GroupBox("Failures") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(result.failures) { failure in
                                HStack(alignment: .top) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(failure.sourceURL.lastPathComponent)
                                            .font(.caption.bold())
                                        Text("[\(failure.stage)] \(failure.reason)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                }
            }

            HStack(spacing: 16) {
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }

    @ViewBuilder
    private func statRow(_ label: String, _ value: Int) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}
