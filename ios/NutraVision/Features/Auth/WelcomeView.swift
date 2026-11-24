import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "leaf.circle.fill").font(.system(size: 80))
                    .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .top, endPoint: .bottom))
                    .accessibilityHidden(true)
                Text("NutraVision").font(.largeTitle.bold())
                Text("Track meals, hit your targets, and eat for your health.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 14) {
                    feature("camera.viewfinder", "Log food in seconds",
                            "Search, scan a barcode, snap a photo, or go hands-free with Meta glasses.")
                    feature("heart.text.square", "Advice for your health",
                            "Every food is checked against your conditions and daily targets.")
                    feature("person.2", "Your doctor in the loop",
                            "Share your diary with your doctor and get their recommendations.")
                }
                .padding(.top, 8)
                Spacer()
                NavigationLink("Create account") { SignUpView() }.buttonStyle(.borderedProminent).controlSize(.large)
                NavigationLink("Sign in") { SignInView() }.controlSize(.large)
            }
            .padding(24)
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Theme.accent).frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
