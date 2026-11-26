import SwiftUI

/// Shown to a doctor whose license hasn't been checked yet. Until then the backend refuses patient
/// requests, so this replaces the request form and the empty patient list.
struct VerificationNotice: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Verifying your license", systemImage: "checkmark.seal")
                .font(.headline).foregroundStyle(Theme.moderation)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
            Text("Pull down to check again.").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let license = app.profile?.licenseNumber ?? ""
        let what = license.isEmpty ? "your license" : "license \(license)"
        return "Patients trust NutraVision doctors with their health data, so we check \(what) with the issuing board before you can add patients. This usually takes one to two business days."
    }
}
