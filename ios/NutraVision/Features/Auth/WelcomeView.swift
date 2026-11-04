import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "leaf.circle.fill").font(.system(size: 80))
                    .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .top, endPoint: .bottom))
                Text("NutraVision").font(.largeTitle.bold())
                Text("Track meals, hit your targets, and eat for your health.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Spacer()
                NavigationLink("Create account") { SignUpView() }.buttonStyle(.borderedProminent).controlSize(.large)
                NavigationLink("Sign in") { SignInView() }.controlSize(.large)
            }
            .padding(24)
        }
    }
}
