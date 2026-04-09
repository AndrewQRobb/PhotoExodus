import SwiftUI
import PhotoExodusCore

struct ContentView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Group {
            switch viewModel.currentScreen {
            case .setup:
                SetupView(viewModel: viewModel)
            case .processing:
                ProcessingProgressView(viewModel: viewModel)
            case .conflictReview:
                if let conflict = viewModel.pendingConflict {
                    ConflictReviewView(conflict: conflict) { resolution in
                        viewModel.resolveConflict(resolution)
                    }
                }
            case .summary:
                if let result = viewModel.result {
                    SummaryView(result: result) {
                        viewModel.reset()
                    }
                }
            }
        }
        .padding()
    }
}
