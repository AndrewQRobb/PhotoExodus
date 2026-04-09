import SwiftUI

struct SetupView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("PhotoExodus")
                    .font(.largeTitle.bold())
                Text("Migrate your Google Photos library to Apple Photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            // Input folder
            GroupBox("Google Takeout Folder") {
                HStack {
                    if let url = viewModel.inputURL {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        Text(url.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Select your unzipped Google Takeout folder")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose...") {
                        chooseFolder { url in viewModel.inputURL = url }
                    }
                }
                .padding(.vertical, 4)
            }

            // Output folder
            GroupBox("Output Folder") {
                HStack {
                    if let url = viewModel.outputURL {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.green)
                        Text(url.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Select where to save your organized photos")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose...") {
                        chooseFolder { url in viewModel.outputURL = url }
                    }
                }
                .padding(.vertical, 4)
            }

            // Options
            GroupBox("Options") {
                Toggle("Remove edited copies (keep originals only)", isOn: $viewModel.removeEditedCopies)
                    .padding(.vertical, 4)
            }

            Spacer()

            // Warning and start
            VStack(spacing: 12) {
                Label("Files will be moved, not copied. You can re-download from Google Takeout if needed.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Button(action: { viewModel.startProcessing() }) {
                    Text("Start Migration")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canStart)
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }

    private func chooseFolder(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(url)
            }
        }
    }
}
