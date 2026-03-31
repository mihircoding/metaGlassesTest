//
// MetaGlassesVoice — iOS companion for Meta AI glasses (voice → on-device transcription).
//

import MWDATCore
import SwiftUI

@main
struct MetaGlassesVoiceApp: App {
    @StateObject private var wearablesVM: WearablesViewModel

    init() {
        do {
            try Wearables.configure()
        } catch {
            assertionFailure("Wearables.configure() failed: \(error)")
        }
        _wearablesVM = StateObject(wrappedValue: WearablesViewModel(wearables: Wearables.shared))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(wearablesVM: wearablesVM)
                .overlay {
                    RegistrationView(viewModel: wearablesVM)
                }
        }
    }
}
