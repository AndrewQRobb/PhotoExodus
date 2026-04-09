import SwiftUI

struct ProcessingProgressView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Processing...")
                .font(.title2.bold())

            VStack(spacing: 12) {
                Text(viewModel.currentStage)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if viewModel.stageTotal > 0 {
                    ProgressView(value: Double(viewModel.stageCompleted),
                                 total: Double(viewModel.stageTotal))
                        .progressViewStyle(.linear)

                    Text("\(viewModel.stageCompleted) / \(viewModel.stageTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                }

                if let file = viewModel.currentFile {
                    Text(file)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: 400)

            Spacer()

            Button("Cancel") {
                viewModel.cancelProcessing()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
