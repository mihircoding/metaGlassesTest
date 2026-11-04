import MWDATCore
import SwiftUI

@main
struct NutraVisionApp: App {
    @State private var wearablesVM: WearablesViewModel
    @State private var app = AppModel()

    init() {
        do {
            try Wearables.configure()
        } catch {
            assertionFailure("Wearables.configure() failed: \(error)")
        }
        _wearablesVM = State(wrappedValue: WearablesViewModel(wearables: Wearables.shared))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(wearablesVM)
                .environment(app)
                .task { await app.start() }
                .overlay {
                    RegistrationView(viewModel: wearablesVM)
                }
        }
    }
}
