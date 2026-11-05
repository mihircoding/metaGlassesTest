import SwiftUI

/// The only place Apple Health permission is requested.
struct AppleHealthView: View {
    @Environment(AppModel.self) private var app
    @State private var busy = false
    @State private var message: String?
    @State private var error: String?

    private var health: HealthSync { HealthSync.shared }

    var body: some View {
        List {
            Section {
                if !HealthSync.isAvailable {
                    Text("Apple Health is not available on this device.").foregroundStyle(.secondary)
                } else if health.isAuthorized {
                    Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Button("Sync now") { run { try await sync() } }.disabled(busy)
                } else {
                    Button("Connect Apple Health") {
                        run {
                            try await HealthSync.shared.requestAccess()
                            try await sync()
                        }
                    }
                    .disabled(busy)
                }
                if busy { ProgressView() }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                if let error { Text(error).font(.footnote).foregroundStyle(Theme.bad) }
            } footer: {
                Text("Imports workouts and weight, shows today's steps and active energy, and saves the food and weight you log to Apple Health.")
            }
        }
        .navigationTitle("Apple Health")
    }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true
        error = nil
        message = nil
        Task {
            defer { busy = false }
            do { try await work() } catch { self.error = error.localizedDescription }
        }
    }

    private func sync() async throws {
        guard let userId = Backend.shared.userId else { return }
        try await HealthSync.shared.importNew(userId: userId)
        try? await app.today?.load()
        message = "Synced just now."
    }
}
