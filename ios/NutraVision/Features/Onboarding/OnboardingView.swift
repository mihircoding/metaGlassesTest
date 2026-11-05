import SwiftUI

/// Patient setup: body, then conditions and goal, then editable targets.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var draft: ProfileRow?
    @State private var step = 0
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            if let binding = Binding($draft) {
                Form {
                    switch step {
                    case 0: BodySection(draft: binding)
                    case 1:
                        ConditionsSection(draft: binding)
                        GoalSection(draft: binding)
                    default: TargetsSection(draft: binding)
                    }
                    if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
                    HStack {
                        if step > 0 { Button("Back") { step -= 1 } }
                        Spacer()
                        if step < 2 {
                            Button("Next") { step += 1 }.disabled(step == 0 && !bodyComplete(binding.wrappedValue))
                        } else {
                            Button {
                                Task { await finish(binding.wrappedValue) }
                            } label: {
                                if saving { ProgressView() } else { Text("Finish") }
                            }
                            .disabled(saving)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("Step \(step + 1) of 3")
                .onChange(of: draft) { _, _ in draft?.recomputeTargets() }
            } else {
                ProgressView()
            }
        }
        .onAppear { if draft == nil { draft = app.profile.map(seed) } }
    }

    /// Fresh patients have no body data; the date picker shows 1990-01-01, so store that as the starting value.
    private func seed(_ profile: ProfileRow) -> ProfileRow {
        var p = profile
        if p.birthDate == nil { p.birthDate = "1990-01-01" }
        p.recomputeTargets()
        return p
    }

    private func bodyComplete(_ p: ProfileRow) -> Bool {
        (p.heightCm ?? 0) > 0 && (p.weightKg ?? 0) > 0 && p.birthDate != nil
    }

    private func finish(_ profile: ProfileRow) async {
        saving = true
        error = nil
        do { try await app.saveProfile(profile) } catch { self.error = error.localizedDescription }
        saving = false
    }
}
