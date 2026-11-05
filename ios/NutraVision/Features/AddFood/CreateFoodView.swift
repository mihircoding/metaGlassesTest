import NutraCore
import SwiftUI

/// Name, brand, serving and nutrients -> custom_foods.
struct CreateFoodView: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var brand = ""
    @State private var servingDesc = "1 serving"
    @State private var servingGrams = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var satFat = ""
    @State private var sodium = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var error: String?
    @State private var saving = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(kcal) != nil && !saving
    }

    var body: some View {
        Form {
            Section("Food") {
                TextField("Name", text: $name)
                TextField("Brand (optional)", text: $brand)
                TextField("Serving (e.g. 1 cup)", text: $servingDesc)
                field("Serving weight (g, optional)", $servingGrams)
            }
            Section("Nutrients per serving") {
                field("Calories (kcal)", $kcal)
                field("Protein (g)", $protein)
                field("Carbs (g)", $carbs)
                field("Fat (g)", $fat)
                field("Saturated fat (g)", $satFat)
                field("Sodium (mg)", $sodium)
                field("Fiber (g)", $fiber)
                field("Sugar (g)", $sugar)
            }
            Section {
                if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
                Button { save() } label: { Text(error == nil ? "Save" : "Retry").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .disabled(!canSave)
            }
        }
        .navigationTitle("Create Food")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
        }
    }

    private func save() {
        guard let userId = Backend.shared.userId else { return }
        func num(_ s: String) -> Double { max(Double(s) ?? 0, 0) }
        let brandText = brand.trimmingCharacters(in: .whitespaces)
        let desc = servingDesc.trimmingCharacters(in: .whitespaces)
        let food = CustomFoodRow(
            userId: userId, name: name.trimmingCharacters(in: .whitespaces),
            brand: brandText.isEmpty ? nil : brandText, servingDesc: desc.isEmpty ? "1 serving" : desc,
            servingGrams: Double(servingGrams).flatMap { $0 > 0 ? $0 : nil },
            perServing: Nutrients(kcal: num(kcal), proteinG: num(protein), carbsG: num(carbs), fatG: num(fat),
                                  satFatG: num(satFat), sodiumMg: num(sodium), fiberG: num(fiber), sugarG: num(sugar)))
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                try await Backend.shared.insertCustomFood(food)
                onSaved()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
