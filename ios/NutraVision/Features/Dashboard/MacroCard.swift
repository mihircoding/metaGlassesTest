import SwiftUI

/// One nutrient against its target; turns red above 100% when `warnOver` is set (sodium, sat fat).
struct MacroCard: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String
    var warnOver = false

    private var fraction: Double { target > 0 ? value / target : 0 }
    private var over: Bool { warnOver && fraction > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            Text("\(Int(value.rounded())) \(unit)")
                .font(.headline)
                .foregroundStyle(over ? Theme.bad : Color.primary)
            ProgressView(value: min(fraction, 1)).tint(over ? Theme.bad : Theme.accent)
            Text("of \(Int(target.rounded())) \(unit)").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
