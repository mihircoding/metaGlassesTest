import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                    if let banner = app.banner {
                        Text(banner).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("Retry") { Task { await app.refresh() } }.buttonStyle(.borderedProminent)
                        // Without this, a signed-in user whose profile won't load has no way out.
                        Button("Sign out", role: .destructive) {
                            Task {
                                do { try await Backend.shared.signOut() } catch { app.banner = error.localizedDescription }
                            }
                        }
                    }
                }
                .padding()
            case .signedOut: WelcomeView()
            case .onboarding: OnboardingView()
            case .patient: PatientTabs()
            case .doctor: DoctorTabs()
            }
        }
        .tint(Theme.accent)
        .safeAreaInset(edge: .top) {
            if app.phase != .loading, let banner = app.banner {
                HStack {
                    Text(banner).font(.footnote)
                    Spacer()
                    Button("Retry") { Task { await app.refresh() } }
                    Button { app.banner = nil } label: { Image(systemName: "xmark") }
                }
                .padding(10)
                .background(Theme.bad.opacity(0.15))
            }
        }
    }
}
