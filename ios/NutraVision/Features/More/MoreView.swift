import SwiftUI

struct MoreView: View {
    @Environment(AppModel.self) private var app
    @State private var error: String?
    @State private var careTeam = CareTeamModel()

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
                            NavigationLink {
                                CareTeamView()
                            } label: {
                                HStack {
                                    Text("Care Team")
                                    Spacer()
                                    if careTeam.pendingCount > 0 {
                                        Text("\(careTeam.pendingCount)").font(.caption.bold()).foregroundStyle(.white)
                                            .padding(.horizontal, 7).padding(.vertical, 2)
                                            .background(Theme.bad, in: Capsule())
                                            .accessibilityLabel("\(careTeam.pendingCount) pending")
                                    }
                                }
                            }
                            NavigationLink("Glasses") { GlassesSettingsView() }
                            NavigationLink("Apple Health") { AppleHealthView() }
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
            .onAppear { Task { await careTeam.load() } }  // reload when returning from Care Team
        }
    }
}
