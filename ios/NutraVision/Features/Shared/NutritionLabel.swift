import NutraCore
import SwiftUI

struct NutritionLabel: View {
    let nutrients: Nutrients

    var body: some View {
        VStack(spacing: 6) {
            row("Calories", nutrients.kcal, "kcal", bold: true)
            Divider()
            row("Protein", nutrients.proteinG, "g")
            row("Carbs", nutrients.carbsG, "g")
            row("  Sugar", nutrients.sugarG, "g")
            row("  Fiber", nutrients.fiberG, "g")
            row("Fat", nutrients.fatG, "g")
            row("  Saturated", nutrients.satFatG, "g")
            row("Sodium", nutrients.sodiumMg, "mg")
        }
    }

    private func row(_ title: String, _ value: Double, _ unit: String, bold: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(Int(value.rounded())) \(unit)").monospacedDigit()
        }
        .font(bold ? .headline : .subheadline)
    }
}
