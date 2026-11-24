import MWDATCore
import SwiftUI

@main
struct NutraVisionApp: App {
    @State private var wearablesVM: WearablesViewModel
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        MainThreadWatchdog.start()
        startupLog.debug("init: configuring Wearables")
        #endif
        let started = Date()
        do {
            try Wearables.configure()
        } catch {
            NSLog("Wearables.configure() failed: \(error)")  // phone-camera path stays usable
        }
        startupLog.debug("init: Wearables configured in \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s")
        _wearablesVM = State(wrappedValue: WearablesViewModel(wearables: Wearables.shared))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(wearablesVM)
                .environment(app)
                .task { await app.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await app.refresh() } }  // also imports from Apple Health
                }
                .overlay {
                    RegistrationView(viewModel: wearablesVM, app: app)
                }
        }
    }
}
