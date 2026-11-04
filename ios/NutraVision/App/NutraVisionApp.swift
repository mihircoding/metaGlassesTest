import MWDATCore
import SwiftUI

@main
struct NutraVisionApp: App {
    @State private var wearablesVM: WearablesViewModel

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
                .overlay {
                    RegistrationView(viewModel: wearablesVM)
                }
        }
    }
}
