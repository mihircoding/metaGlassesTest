import NutraCore
import SwiftUI

/// Each nutrient for one day against its target.
struct DayNutritionView: View {
    let consumed: Nutrients
    let targets: Targets

    private var rows: [(name: String, value: Double, target: Double, unit: String, isLimit: Bool)] {
        [("Calories", consumed.kcal, targets.kcal, "kcal", false),
         ("Protein", consumed.proteinG, targets.proteinG, "g", false),
         ("Carbs", consumed.carbsG, targets.carbsG, "g", false),
         ("Fat", consumed.fatG, targets.fatG, "g", false),
         ("Saturated fat", consumed.satFatG, targets.satFatG, "g", true),
         ("Sodium", consumed.sodiumMg, targets.sodiumMg, "mg", true),
         ("Fiber", consumed.fiberG, targets.fiberG, "g", false)]
    }

    var body: some View {
        List {
            ForEach(rows, id: \.name) { row in
                let fraction = row.target > 0 ? row.value / row.target : 0
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.name)
                        Spacer()
                        Text("\(Int(row.value.rounded())) / \(Int(row.target.rounded())) \(row.unit)")
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(fraction, 1))
                        .tint(row.isLimit && fraction > 1 ? Theme.bad : Theme.accent)
                }
                .padding(.vertical, 2)
            }
            Section { LabeledContent("Sugar", value: "\(Int(consumed.sugarG.rounded())) g") }
        }
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
    }
}
