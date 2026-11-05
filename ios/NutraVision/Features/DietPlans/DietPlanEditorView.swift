import NutraCore
import SwiftUI

/// Edits a diet plan. Push it (no NavigationStack of its own). Patients: Save writes the plan to `diet_plans`.
/// Doctors: pass `onDone` to get the edited plan back instead of saving it.
struct DietPlanEditorView: View {
    var onDone: ((DietPlanRow) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: DietPlanRow
    /// Each item as first added, so a portion change rescales from the original and never compounds rounding.
    @State private var bases: [UUID: PlanItem]
    @State private var mults: [UUID: Double] = [:]
    @State private var pick: PickTarget?
    @State private var saving = false
    @State private var error: String?

    private struct PickTarget: Identifiable {
        let id = UUID()
        let mealIndex: Int
        let replacing: UUID?
    }

    init(plan: DietPlanRow, onDone: ((DietPlanRow) -> Void)? = nil) {
        var p = plan
        var seen = Set<UUID>()  // sample plans reuse item ids; each row needs its own
        for m in p.meals.indices {
            for i in p.meals[m].items.indices where !seen.insert(p.meals[m].items[i].id).inserted {
                p.meals[m].items[i].id = UUID()
            }
        }
        _draft = State(initialValue: p)
        _bases = State(initialValue: Dictionary(uniqueKeysWithValues: p.meals.flatMap { $0.items }.map { ($0.id, $0) }))
        self.onDone = onDone
    }

    private var totals: Nutrients { draft.meals.flatMap { $0.items }.map { $0.nutrients }.sum() }

    var body: some View {
        Form {
            Section("Plan") {
                TextField("Plan name", text: $draft.name)
            }
            Section("Daily targets") {
                field("Calories (kcal)", $draft.targets.kcal)
                field("Protein (g)", $draft.targets.proteinG)
                field("Carbs (g)", $draft.targets.carbsG)
                field("Fat (g)", $draft.targets.fatG)
                field("Saturated fat (g)", $draft.targets.satFatG)
                field("Sodium (mg)", $draft.targets.sodiumMg)
                field("Fiber (g)", $draft.targets.fiberG)
            }
            Section("Day total vs target") {
                total("Calories", totals.kcal, draft.targets.kcal, "kcal")
                total("Protein", totals.proteinG, draft.targets.proteinG, "g")
                total("Carbs", totals.carbsG, draft.targets.carbsG, "g")
                total("Fat", totals.fatG, draft.targets.fatG, "g")
                total("Saturated fat", totals.satFatG, draft.targets.satFatG, "g")
                total("Sodium", totals.sodiumMg, draft.targets.sodiumMg, "mg")
                total("Fiber", totals.fiberG, draft.targets.fiberG, "g")
            }
            ForEach(draft.meals.indices, id: \.self) { mi in
                Section(draft.meals[mi].meal.title) {
                    ForEach(draft.meals[mi].items) { item in
                        itemRow(item, mealIndex: mi)
                    }
                    .onDelete { offsets in
                        for o in offsets { forget(draft.meals[mi].items[o].id) }
                        draft.meals[mi].items.remove(atOffsets: offsets)
                    }
                    Button("Add food", systemImage: "plus") { pick = PickTarget(mealIndex: mi, replacing: nil) }
                }
            }
            if let error {
                Section { InlineError(message: error) { save() } }
            }
        }
        .navigationTitle(draft.name.isEmpty ? "Diet plan" : draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(onDone == nil ? "Save" : "Done") { save() }
                    .disabled(saving || draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(item: $pick) { target in
            AddFoodView(meal: draft.meals[target.mealIndex].meal, date: Date(),
                        onPick: { food, servings in picked(food, servings, target) })
        }
    }

    private func itemRow(_ item: PlanItem, mealIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                    Text(item.servingDesc).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(item.nutrients.kcal.rounded())) kcal").foregroundStyle(.secondary)
            }
            HStack {
                Stepper(value: Binding(get: { mults[item.id] ?? 1 },
                                       set: { setMult($0, mealIndex: mealIndex, id: item.id) }),
                        in: 0.25...10, step: 0.25) {
                    Text("Portion x\(fmt(mults[item.id] ?? 1))").font(.footnote)
                }
                Button("Swap") { pick = PickTarget(mealIndex: mealIndex, replacing: item.id) }
                    .buttonStyle(.bordered).font(.footnote)
            }
        }
    }

    private func field(_ title: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

    private func total(_ title: String, _ value: Double, _ target: Double, _ unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(Int(value.rounded())) / \(Int(target.rounded())) \(unit)")
                .foregroundStyle(target > 0 && value > target * 1.1 ? Theme.moderation : .secondary)
        }
    }

    private func fmt(_ n: Double) -> String { n.formatted(.number.precision(.fractionLength(0...2))) }

    private func forget(_ id: UUID) {
        bases[id] = nil
        mults[id] = nil
    }

    private func setMult(_ m: Double, mealIndex: Int, id: UUID) {
        guard let base = bases[id], let i = draft.meals[mealIndex].items.firstIndex(where: { $0.id == id }) else { return }
        mults[id] = m
        var r = base
        if m != 1 {
            r.servingDesc = "\(fmt(m)) x \(base.servingDesc)"
            r.servingGrams = base.servingGrams.map { $0 * m }
            r.nutrients = base.nutrients.scaled(by: m)
        }
        draft.meals[mealIndex].items[i] = r
    }

    private func picked(_ food: FoodItem, _ servings: Double, _ target: PickTarget) {
        let item = PlanItem(name: food.name,
                            servingDesc: servings == 1 ? food.servingDesc : "\(fmt(servings)) x \(food.servingDesc)",
                            servingGrams: food.servingGrams.map { $0 * servings },
                            nutrients: food.perServing.scaled(by: servings))
        bases[item.id] = item
        if let old = target.replacing,
           let i = draft.meals[target.mealIndex].items.firstIndex(where: { $0.id == old }) {
            draft.meals[target.mealIndex].items[i] = item
            forget(old)
        } else {
            draft.meals[target.mealIndex].items.append(item)
        }
    }

    private func save() {
        if let onDone {
            onDone(draft)
            dismiss()
            return
        }
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                try await Backend.shared.saveDietPlan(draft)  // the active plan stays active
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
