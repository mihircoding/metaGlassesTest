import NutraCore
import SwiftUI

struct ConditionDetailView: View {
    let condition: Condition

    @Environment(AppModel.self) private var app
    @State private var busy = false
    @State private var error: String?
    @State private var retry: (() -> Void)?
    @State private var started = false

    private var inConditions: Bool { app.profile?.conditions.contains(condition.id) ?? false }

    var body: some View {
        List {
            Section {
                Label(condition.name, systemImage: condition.icon).font(.headline).foregroundStyle(Theme.accent)
                Text(condition.summary)
            }
            Section("Recommended") { ForEach(condition.recommend, id: \.self) { Text($0) } }
            Section("Avoid") { ForEach(condition.avoid, id: \.self) { Text($0) } }
            Section("Limits") {
                row("Macro split", "\(Int(condition.proteinPct))% protein / \(Int(condition.carbsPct))% carbs / \(Int(condition.fatPct))% fat")
                row("Sodium", "\(Int(condition.sodiumMg)) mg")
                row("Saturated fat", "up to \(Int(condition.satFatPctMax))% of calories")
                row("Fiber", "\(Int(condition.fiberG)) g")
            }
            Section("Sample day") {
                ForEach(condition.samplePlan.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(condition.samplePlan[i].meal.title).font(.subheadline.bold())
                        ForEach(condition.samplePlan[i].items.indices, id: \.self) { j in
                            let item = condition.samplePlan[i].items[j]
                            Text("\(item.name) · \(item.servingDesc)").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                if started { Text("Plan started. It is now your active plan.").foregroundStyle(Theme.accent) }
                if let error, let retry { InlineError(message: error, retry: retry) }
                Button("Start this plan") { startPlan() }
                    .buttonStyle(.borderedProminent).tint(Theme.accent).disabled(busy || app.profile == nil)
                Button(inConditions ? "In my conditions" : "Add to my conditions") { addCondition() }
                    .buttonStyle(.bordered).disabled(busy || inConditions || app.profile == nil)
            }
            Section {
                Text("NutraVision is not medical advice. Talk to your doctor before changing your diet.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(condition.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }

    private func startPlan() {
        guard let userId = Backend.shared.userId, let profile = app.profile else { return }
        var meals = condition.samplePlan
        for m in meals.indices {
            for i in meals[m].items.indices { meals[m].items[i].id = UUID() }
        }
        let plan = DietPlanRow(userId: userId, authorId: userId, conditionId: condition.id,
                               name: "\(condition.name) plan", notes: nil, targets: profile.targets,
                               meals: meals, isActive: true)
        run(retrying: startPlan) {
            try await Backend.shared.saveDietPlan(plan)
            started = true
        }
    }

    private func addCondition() {
        guard var profile = app.profile else { return }
        if !profile.conditions.contains(condition.id) { profile.conditions.append(condition.id) }
        let updated = profile
        run(retrying: addCondition) { try await app.saveProfile(updated) }  // targets recompute while automatic
    }

    private func run(retrying: @escaping () -> Void, _ work: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do { try await work() } catch {
                self.error = error.localizedDescription
                retry = retrying
            }
        }
    }
}
