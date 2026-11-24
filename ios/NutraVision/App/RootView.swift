import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .loading: LoadingView()
            case .signedOut: WelcomeView()
            case .onboarding: OnboardingView()
            case .patient: PatientTabs().onAppear { startupLog.debug("patient tabs appeared") }
            case .doctor: DoctorTabs()
            }
        }
        .tint(Theme.accent)
        // Only once signed in: before that the welcome screen (and its "Reset password" sheet) is still
        // on screen, and a second sheet presented over it would be dropped.
        .sheet(isPresented: Binding(get: { app.choosingNewPassword && app.phase != .signedOut && app.phase != .loading },
                                    set: { app.choosingNewPassword = $0 })) {
            NewPasswordView()
        }
        .onChange(of: app.phase, initial: true) { _, phase in
            startupLog.debug("root view showing \(String(describing: phase), privacy: .public)")
        }
        .safeAreaInset(edge: .top) {
            if app.phase != .loading, let banner = app.banner {
                HStack {
                    Text(banner).font(.footnote)
                    Spacer()
                    Button("Retry") { Task { await app.refresh() } }
                    Button { app.banner = nil } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Dismiss")
                }
                .padding(10)
                .background(Theme.bad.opacity(0.15))
            }
        }
    }
}

/// Shown while a signed-in user's profile loads. On a bad network that can take minutes (each request
/// waits for its timeout and is retried), so after a few seconds it says so and offers a way out.
private struct LoadingView: View {
    @Environment(AppModel.self) private var app
    @State private var slow = false

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            if let banner = app.banner {
                Text(banner).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Retry") { Task { await app.refresh() } }.buttonStyle(.borderedProminent)
                signOutButton
            } else if slow {
                Text("Still connecting… Check your internet connection.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                signOutButton
            }
        }
        .padding()
        .animation(.default, value: slow)
        .task {
            try? await Task.sleep(for: .seconds(8))
            slow = true
        }
    }

    /// Signing out clears the session on the device first, so it works offline; only telling the
    /// server waits on the network, and a failure there doesn't matter once the user is signed out.
    private var signOutButton: some View {
        Button("Sign out", role: .destructive) {
            Task {
                do {
                    try await Backend.shared.signOut()
                } catch {
                    if app.phase == .loading { app.banner = error.localizedDescription }
                }
            }
        }
    }
}
