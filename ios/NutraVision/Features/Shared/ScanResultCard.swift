import NutraCore
import SwiftUI

/// Scan result for photo, barcode and glasses scans: editable grams per item, live verdict, Add / Skip.
struct ScanResultCard: View {
    @Environment(AppModel.self) private var app
    @Binding var items: [AnalyzedItem]
    let onAdd: (Meal) -> Void
    let onSkip: () -> Void
    @State private var meal = MealSlot.meal(at: Date())

    private var total: Nutrients { items.map(\.nutrients).sum() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($items) { $item in
                ScanItemRow(item: $item)
                Divider()
            }
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text("\(Int(total.kcal.rounded())) kcal").font(.headline).monospacedDigit()
            }
            Text("P \(Int(total.proteinG.rounded())) g · C \(Int(total.carbsG.rounded())) g · F \(Int(total.fatG.rounded())) g")
                .font(.footnote).foregroundStyle(.secondary)
            VerdictBadge(verdict: app.verdict(name: items.map(\.name).joined(separator: ", "), item: total))
            Picker("Meal", selection: $meal) {
                ForEach(Meal.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            HStack {
                Button("Skip", role: .cancel, action: onSkip).buttonStyle(.bordered)
                Button { onAdd(meal) } label: { Text("Add").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .disabled(items.isEmpty)
            }
        }
        .padding()
    }
}

private struct ScanItemRow: View {
    @Binding var item: AnalyzedItem
    /// The values as scanned: later edits rescale from here, so rounding never compounds.
    @State private var base: AnalyzedItem
    @State private var text: String

    init(item: Binding<AnalyzedItem>) {
        _item = item
        _base = State(initialValue: item.wrappedValue)
        _text = State(initialValue: String(Int(item.wrappedValue.grams.rounded())))
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name).font(.subheadline.bold())
                Text("\(Int(item.nutrients.kcal.rounded())) kcal · \(item.confidence.rawValue) confidence")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            TextField("g", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .textFieldStyle(.roundedBorder)
            Text("g").foregroundStyle(.secondary)
        }
        .onChange(of: text) { _, newValue in
            guard let grams = Double(newValue), grams > 0 else { return }
            item.grams = grams
            item.nutrients = base.grams > 0 ? base.nutrients.scaled(by: grams / base.grams) : base.nutrients
        }
    }
}
