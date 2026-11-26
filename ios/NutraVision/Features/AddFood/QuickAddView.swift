import NutraCore
import SwiftUI

/// Log calories (and optionally macros) without picking a food: a restaurant meal, a homemade dish.
struct QuickAddView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let date: Date
    var onLogged: () -> Void = {}

    @State private var name = ""
    @State private var meal: Meal = MealSlot.meal(at: Date())
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var saving = false
    @State private var error: String?

    private static func value(_ text: String) -> Double? {
        let v = Double(text.replacingOccurrences(of: ",", with: "."))
        return v.flatMap { $0 >= 0 ? $0 : nil }
    }

    private var calories: Double? { Self.value(kcal).flatMap { $0 > 0 ? $0 : nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (optional)", text: $name)
                    Picker("Meal", selection: $meal) {
                        ForEach(Meal.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    number("Calories", "kcal", $kcal)
                } footer: {
                    Text("Required.")
                }
                Section("Optional") {
                    number("Protein", "g", $protein)
                    number("Carbs", "g", $carbs)
                    number("Fat", "g", $fat)
                }
                if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
            }
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }.disabled(saving || calories == nil)
                }
            }
        }
    }

    private func number(_ label: String, _ unit: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                .accessibilityLabel(label)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func save() async {
        guard let userId = Backend.shared.userId, let calories else { return }
        saving = true
        error = nil
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let nutrients = Nutrients(kcal: calories, proteinG: Self.value(protein) ?? 0,
                                  carbsG: Self.value(carbs) ?? 0, fatG: Self.value(fat) ?? 0)
        let row = FoodLogRow(userId: userId, loggedAt: FoodLogRow.loggedAt(for: date), meal: meal,
                             name: trimmed.isEmpty ? "Quick add" : trimmed, brand: nil, servingDesc: "1 entry",
                             servingGrams: nil, servings: 1, perServing: nutrients, source: .manual, sourceRef: nil)
        do {
            try await app.addLogs([row])
            onLogged()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        saving = false
    }
}
