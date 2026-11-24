import SwiftUI

struct MoreView: View {
    @Environment(AppModel.self) private var app
    @State private var error: String?
    @State private var careTeam = CareTeamModel()
    @State private var confirmingDelete = false
    @State private var deleting = false

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
                            NavigationLink("Weight history") { WeightHistoryView() }
                            NavigationLink("Reminders") { RemindersView() }
                            NavigationLink("Conditions") { ConditionLibraryView() }
                            NavigationLink("Diet Plans") { DietPlansView() }
                            NavigationLink("Glasses") { GlassesSettingsView() }
                            NavigationLink("Apple Health") { AppleHealthView() }
                        }
                    }
                }
                Section {
                    NavigationLink("Privacy & data") { PrivacyView() }
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
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        HStack {
                            Text("Delete account")
                            if deleting { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(deleting)
                } footer: {
                    Text("Permanently deletes your account and everything in it: your diary, workouts, weights, foods, plans and care team links.")
                }
                .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete account and all data", role: .destructive) { deleteAccount() }
                } message: {
                    Text("This can't be undone.")
                }
                Section {
                    Text("NutraVision is not medical advice. Talk to your doctor before changing your diet.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Version \(Self.version)").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("More")
            .onAppear { Task { await careTeam.load() } }  // reload when returning from Care Team
        }
    }

    /// "1.0 (1)": marketing version and build number, both set in project.yml.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private func deleteAccount() {
        deleting = true
        error = nil
        Task {
            do {
                try await Backend.shared.deleteAccount()  // the auth listener then shows the welcome screen
            } catch {
                self.error = error.localizedDescription
            }
            deleting = false
        }
    }
}
