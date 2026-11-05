import MWDATCore
import SwiftUI

/// More → Glasses: Meta AI registration, the glasses it knows about, and the glasses camera permission.
struct GlassesSettingsView: View {
    @Environment(WearablesViewModel.self) private var wearables

    var body: some View {
        @Bindable var wearables = wearables
        List {
            Section {
                LabeledContent("Status", value: status)
                if wearables.registrationState == .registered {
                    Button("Disconnect", role: .destructive) { wearables.disconnectGlasses() }
                } else {
                    Button("Connect glasses") { wearables.connectGlasses() }
                        .disabled(wearables.registrationState == .registering)
                }
            } header: {
                Text("Meta AI")
            } footer: {
                Text("Connecting opens the Meta AI app to approve NutraVision.")
            }

            Section {
                ForEach(wearables.devices, id: \.self) { id in
                    Label(Wearables.shared.deviceForIdentifier(id)?.nameOrId() ?? id, systemImage: "eyeglasses")
                }
                if wearables.devices.isEmpty {
                    Text("No glasses yet").foregroundStyle(.secondary)
                }
                Button("Allow glasses camera") {
                    Task { await wearables.requestWearableCameraPermission() }
                }
                .disabled(wearables.registrationState != .registered)
            } header: {
                Text("Glasses")
            } footer: {
                Text("Glasses appear here once camera access is allowed in Meta AI. Keep NutraVision open on screen while you use Glasses Mode.")
            }
        }
        .navigationTitle("Glasses")
        .alert("Glasses", isPresented: $wearables.isErrorPresented) {
            Button("OK") { wearables.dismissError() }
        } message: {
            Text(wearables.errorMessage)
        }
    }

    private var status: String {
        switch wearables.registrationState {
        case .registered: return "Connected"
        case .registering: return "Connecting\u{2026}"
        case .available: return "Not connected"
        default: return "Unavailable"
        }
    }
}
