import NutraCore
import SwiftUI

/// One recipe idea: title, our one-line summary, time, diet labels and any tip for this condition.
/// Opens the full recipe on the GI Nutrition Foundation's site.
/// Colors are concrete: inside a Link, .primary/.secondary resolve against the link tint.
struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        Link(destination: recipe.url) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(recipe.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square").foregroundStyle(Color.secondary).accessibilityHidden(true)
                }
                Text(recipe.summary).font(.footnote).foregroundStyle(Color.secondary)
                HStack(spacing: 6) {
                    if let minutes = recipe.minutes {
                        Label("\(minutes) min", systemImage: "clock").font(.caption).foregroundStyle(Color.secondary)
                    }
                    ForEach(recipe.diets.prefix(3), id: \.self) { diet in
                        Text(diet)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(Theme.accent2)
                    }
                }
                if let tip = recipe.tip {
                    Label(tip, systemImage: "lightbulb").font(.caption).foregroundStyle(Color.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the recipe in Safari")
    }
}
