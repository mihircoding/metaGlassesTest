import NutraCore
import SwiftUI

struct FoodDetailView: View {
    let item: FoodItem
    let meal: Meal
    let date: Date
    /// How the log row records where the food came from.
    var source: FoodSource = .search
    /// Called after a successful add; the Add Food sheet uses it to close itself.
    var onLogged: (() -> Void)?
    /// Pick mode (plan editor): the button says Choose and reports the food and servings instead of logging.
    var onPick: ((FoodItem, Double) -> Void)?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private enum Unit: Hashable { case labeled, hundredG, grams }
    @State private var unit = Unit.labeled
    @State private var servings = 1.0
    @State private var gramsText = ""
    @State private var selectedMeal: Meal
    @State private var error: String?
    @State private var saving = false

    init(item: FoodItem, meal: Meal, date: Date, source: FoodSource = .search, onLogged: (() -> Void)? = nil,
         onPick: ((FoodItem, Double) -> Void)? = nil) {
        self.item = item
        self.meal = meal
        self.date = date
        self.source = source
        self.onLogged = onLogged
        self.onPick = onPick
        _selectedMeal = State(initialValue: meal)
        _gramsText = State(initialValue: item.servingGrams.map { String(Int($0.rounded())) } ?? "")
    }

    /// Multiples of the labeled serving; what the log row stores as `servings`.
    private var factor: Double {
        switch unit {
        case .labeled: return servings
        case .hundredG: return servings * 100 / (item.servingGrams ?? 100)
        case .grams: return (Double(gramsText) ?? 0) / (item.servingGrams ?? 100)
        }
    }

    private var total: Nutrients { item.perServing.scaled(by: factor) }

    var body: some View {
        Form {
            Section {
                Text(item.name).font(.headline)
                if let brand = item.brand { Text(brand).foregroundStyle(.secondary) }
            }
            Section("Amount") {
                // 100 g and grams need the labeled serving's weight to convert.
                Picker("Serving", selection: $unit) {
                    Text(item.servingDesc).tag(Unit.labeled)
                    if item.servingGrams != nil {
                        Text("100 g").tag(Unit.hundredG)
                        Text("Grams").tag(Unit.grams)
                    }
                }
                if unit == .grams {
                    HStack {
                        Text("Grams")
                        Spacer()
                        TextField("g", text: $gramsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } else {
                    Stepper(value: $servings, in: 0.25...100, step: 0.25) {
                        Text("Servings: \(servings, format: .number.precision(.fractionLength(0...2)))")
                    }
                }
                if onPick == nil {
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(Meal.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
            }
            Section("Nutrition") {
                NutritionLabel(nutrients: total)
            }
            Section("Fit for you") {
                VerdictBadge(verdict: app.verdict(name: item.name, item: total))
            }
            Section {
                if let error {
                    Text(error).foregroundStyle(Theme.bad).font(.footnote)
                }
                Button {
                    add()
                } label: {
                    Text(onPick != nil ? "Choose" : error == nil ? "Add" : "Retry").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent)
                .disabled(saving || factor <= 0)
            }
        }
        .navigationTitle("Food")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        if let onPick {
            onPick(item, factor)
            if let onLogged { onLogged() } else { dismiss() }
            return
        }
        guard let userId = Backend.shared.userId else { return }
        saving = true
        error = nil
        let row = FoodLogRow(item: item, userId: userId, date: date, meal: selectedMeal, servings: factor, source: source)
        Task {
            defer { saving = false }
            do {
                try await app.addLogs([row])
                if let onLogged { onLogged() } else { dismiss() }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
