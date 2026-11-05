import NutraCore
import SwiftUI

struct RecommendationDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let recommendation: RecommendationRow
    let doctorName: String
    /// Reloads the Care Team lists after a response.
    let onDone: () async -> Void
    @State private var error: String?
    @State private var working = false

    static func title(for rec: RecommendationRow) -> String {
        switch rec.kind {
        case .targets: return "New daily targets"
        case .dietPlan: return rec.payload.dietPlan?.name ?? "Diet plan"
        case .note: return "Note"
        }
    }

    var body: some View {
        List {
            Section {
                Text("From \(doctorName)").font(.subheadline).foregroundStyle(.secondary)
                if let message = recommendation.message, !message.isEmpty { Text(message) }
            }
            if let proposed = recommendation.payload.targets { targetsSection("Current vs proposed", proposed) }
            if let plan = recommendation.payload.dietPlan { planSections(plan) }
            if recommendation.status == .pending {
                Section {
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.bad)
                        Button("Retry") { self.error = nil }
                    }
                    HStack {
                        Button("Accept") { respond(accept: true) }.buttonStyle(.borderedProminent).tint(Theme.accent)
                        Button("Decline") { respond(accept: false) }.buttonStyle(.bordered)
                    }
                    .disabled(working)
                }
            } else {
                Section { Text(recommendation.status.rawValue.capitalized).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(Self.title(for: recommendation))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func targetsSection(_ header: String, _ proposed: Targets) -> some View {
        let current = app.targets
        return Section(header) {
            row("Calories", current.kcal, proposed.kcal, "kcal")
            row("Protein", current.proteinG, proposed.proteinG, "g")
            row("Carbs", current.carbsG, proposed.carbsG, "g")
            row("Fat", current.fatG, proposed.fatG, "g")
            row("Sat fat", current.satFatG, proposed.satFatG, "g")
            row("Sodium", current.sodiumMg, proposed.sodiumMg, "mg")
            row("Fiber", current.fiberG, proposed.fiberG, "g")
        }
    }

    private func row(_ label: String, _ current: Double, _ proposed: Double, _ unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(current.rounded())) \(unit)").foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
            Text("\(Int(proposed.rounded())) \(unit)").bold()
                .foregroundStyle(proposed == current ? Color.primary : Theme.accent)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func planSections(_ plan: DietPlanDraft) -> some View {
        Section("Plan") {
            Text(plan.name).font(.headline)
            if !plan.conditionId.isEmpty {
                Text(ConditionCatalog.condition(id: plan.conditionId).name).foregroundStyle(.secondary)
            }
            if !plan.notes.isEmpty { Text(plan.notes).font(.footnote) }
        }
        targetsSection("Plan targets vs current", plan.targets)
        ForEach(plan.meals, id: \.meal) { planMeal in
            Section(planMeal.meal.title) {
                ForEach(planMeal.items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.servingDesc).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(item.nutrients.kcal.rounded())) kcal").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func respond(accept: Bool) {
        working = true
        Task {
            defer { working = false }
            do {
                if accept {
                    try await Backend.shared.acceptRecommendation(id: recommendation.id)
                    await app.refresh()  // new targets (source: doctor) and verdicts show immediately
                } else {
                    try await Backend.shared.declineRecommendation(id: recommendation.id)
                }
                await onDone()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
