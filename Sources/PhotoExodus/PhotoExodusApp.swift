import SwiftUI

@main
struct PhotoExodusApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowResizability(.contentMinSize)
    }
}
