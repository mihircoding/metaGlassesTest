import SwiftUI

struct MoreView: View {
    @Environment(AppModel.self) private var app
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let profile = app.profile {
                    Section {
                        VStack(alignment: .leading) {
                            Text(profile.fullName).font(.headline)
                            Text(profile.email).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if profile.role == .patient {
                        Section {
                            NavigationLink("Profile & Goals") { ProfileGoalsView(profile: profile) }
                            NavigationLink("Glasses") { GlassesSettingsView() }
                        }
                    }
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        Task {
                            do { try await Backend.shared.signOut() } catch { self.error = error.localizedDescription }
                        }
                    }
                    if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
                }
                Section {
                    Text("NutraVision is not medical advice. Talk to your doctor before changing your diet.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("More")
        }
    }
}
