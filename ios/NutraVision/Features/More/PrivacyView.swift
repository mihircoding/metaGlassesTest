import SwiftUI

/// A plain-language summary of what the app stores, where it goes and who can see it.
/// Keep it in step with PrivacyInfo.xcprivacy and the App Store privacy label.
struct PrivacyView: View {
    var body: some View {
        List {
            Section("What NutraVision stores") {
                item("person.crop.circle", "Your account",
                     "Name, email and whether you're a patient or a doctor.")
                item("fork.knife", "Your diary",
                     "Foods, servings, drinks, workouts, weigh-ins, blood pressure and blood sugar readings, health conditions, targets and diet plans.")
                item("externaldrive", "Where it's kept",
                     "In NutraVision's database (hosted by Supabase), protected so each account can read only its own data.")
            }
            Section("Who can see it") {
                item("person.2", "Doctors you accept",
                     "A doctor sees your diary, progress, weight and readings only after you accept their request. They can also keep private notes about your care. Revoke access anytime in Care Team.")
                item("eye.slash", "Nobody else",
                     "No ads, no tracking and no analytics. The Meta glasses SDK's usage analytics are turned off.")
            }
            Section("When data leaves the app") {
                item("sparkles", "Food photos",
                     "Photo and glasses scans are sent to Claude, an AI model by Anthropic, to identify the food. NutraVision doesn't save the photo.")
                item("heart", "Apple Health",
                     "Only if you connect it: workouts, weight and steps come in; food and weight go out.")
            }
            Section("Your choices") {
                item("trash", "Delete your account",
                     "More › Delete account permanently removes your account and everything in it.")
            }
            Section {
                Text("NutraVision is not medical advice. Talk to your doctor before changing your diet.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy & data")
    }

    private func item(_ symbol: String, _ title: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
        }
        .accessibilityElement(children: .combine)
    }
}
