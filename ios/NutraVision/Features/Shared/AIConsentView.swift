import SwiftUI

/// Whether the user has agreed to food photos being sent to a third-party AI (App Review 5.1.2).
/// Asked once, before the first photo or glasses scan.
enum AIConsent {
    static let key = "consent.aiFoodPhotos"
}

/// Explains where a food photo goes before the first scan, and asks to continue.
struct AIConsentView: View {
    var onContinue: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56)).foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Food recognition uses AI").font(.title2.bold()).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                Label("Your photo is sent to Claude, an AI model made by Anthropic, to identify the food and estimate nutrition.",
                      systemImage: "paperplane")
                Label("Only the photo is sent: not your name, diary or health details.", systemImage: "lock")
                Label("Photos aren't saved by NutraVision after the scan.", systemImage: "trash")
                Label("Estimates can be wrong. Check them before you log.", systemImage: "exclamationmark.triangle")
            }
            .font(.subheadline)
            Spacer()
            Button {
                onContinue()
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            Button("Not now", action: onCancel)
        }
        .padding(24)
    }
}
