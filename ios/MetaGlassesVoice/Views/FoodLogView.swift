import SwiftUI

// MARK: - Food Log View

struct FoodLogView: View {
    @EnvironmentObject var nutrition: NutritionViewModel
    @State private var entryToEdit: FoodEntry?
    @State private var entryToDelete: FoodEntry?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // Daily summary header
                Section {
                    DailyLogSummaryRow()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                // Meals grouped by type
                let grouped = nutrition.todaySummary.entriesByMeal
                if grouped.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Nothing logged yet")
                                .font(.headline)
                            Text("Use the Scan tab to add food")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(FoodEntry.MealType.allCases, id: \.self) { mealType in
                        if let entries = grouped[mealType], !entries.isEmpty {
                            MealSection(
                                mealType: mealType,
                                entries: entries,
                                onEdit: { entryToEdit = $0 },
                                onDelete: { entryToDelete = $0; showDeleteConfirm = true }
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Food Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(DateFormatter.shortDate.string(from: nutrition.selectedDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .confirmationDialog(
                "Delete \(entryToDelete?.name ?? "entry")?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let e = entryToDelete { nutrition.deleteEntry(e) }
                }
            }
            .sheet(item: $entryToEdit) { entry in
                EditFoodEntrySheet(entry: entry) { updated in
                    nutrition.updateEntry(updated)
                    entryToEdit = nil
                }
            }
            .refreshable { nutrition.refreshToday() }
        }
    }
}

// MARK: - Daily Log Summary Row

private struct DailyLogSummaryRow: View {
    @EnvironmentObject var nutrition: NutritionViewModel

    var body: some View {
        let s = nutrition.todaySummary
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                LogSummaryChip(label: "Calories", value: "\(Int(s.totalCalories))", limit: nutrition.profile.dailyCaloricLimit, unit: "kcal", color: .orange)
                LogSummaryChip(label: "Protein",  value: s.totalProtein.macroString, limit: nutrition.profile.proteinGoal, unit: "g", color: .blue)
                LogSummaryChip(label: "Carbs",    value: s.totalCarbs.macroString,   limit: nutrition.profile.carbGoal,    unit: "g", color: .yellow)
                LogSummaryChip(label: "Fat",      value: s.totalFat.macroString,     limit: nutrition.profile.fatGoal,     unit: "g", color: .red)
                LogSummaryChip(label: "Fiber",    value: s.totalFiber.macroString,   limit: nutrition.profile.fiberGoal,   unit: "g", color: .green)
                LogSummaryChip(label: "Sodium",   value: "\(Int(s.totalSodium))",    limit: 2300, unit: "mg", color: .purple)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct LogSummaryChip: View {
    let label: String; let value: String; let limit: Double; let unit: String; let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("/ \(Int(limit))").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(width: 72)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Meal Section

private struct MealSection: View {
    let mealType: FoodEntry.MealType
    let entries: [FoodEntry]
    let onEdit: (FoodEntry) -> Void
    let onDelete: (FoodEntry) -> Void

    var mealCalories: Double { entries.reduce(0) { $0 + $1.scaledCalories } }

    var body: some View {
        Section {
            ForEach(entries) { entry in
                FoodEntryRow(entry: entry)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { onDelete(entry) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { onEdit(entry) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        } header: {
            HStack {
                Image(systemName: mealType.icon)
                Text(mealType.rawValue)
                Spacer()
                Text("\(Int(mealCalories)) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Food Entry Row

private struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            sourceIcon
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(sourceColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let brand = entry.brand {
                        Text(brand).foregroundStyle(.secondary)
                    }
                    Text("P:\(entry.scaledProtein.macroString)g")
                    Text("C:\(entry.scaledCarbs.macroString)g")
                    Text("F:\(entry.scaledFat.macroString)g")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(Int(entry.scaledCalories))")
                    .font(.subheadline.weight(.semibold))
                Text("kcal").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    var sourceIcon: Image {
        switch entry.source {
        case .barcode: return Image(systemName: "barcode")
        case .aiScan:  return Image(systemName: "sparkles")
        case .manual:  return Image(systemName: "pencil")
        }
    }

    var sourceColor: Color {
        switch entry.source {
        case .barcode: return .blue
        case .aiScan:  return .purple
        case .manual:  return .gray
        }
    }
}

// MARK: - Edit Food Entry Sheet

struct EditFoodEntrySheet: View {
    @State var entry: FoodEntry
    let onSave: (FoodEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Food Details") {
                    LabeledContent("Name") {
                        TextField("Name", text: $entry.name)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Meal", selection: $entry.mealType) {
                        ForEach(FoodEntry.MealType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    HStack {
                        Text("Servings")
                        Spacer()
                        TextField("1", value: $entry.servingQty, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                    }
                }

                Section("Nutrition (per serving)") {
                    NutritionField(label: "Calories (kcal)", value: $entry.calories)
                    NutritionField(label: "Protein (g)", value: $entry.protein)
                    NutritionField(label: "Carbs (g)", value: $entry.carbs)
                    NutritionField(label: "Fat (g)", value: $entry.fat)
                    NutritionField(label: "Fiber (g)", value: $entry.fiber)
                    NutritionField(label: "Sodium (mg)", value: $entry.sodium)
                    NutritionField(label: "Sugar (g)", value: $entry.sugar)
                }

                Section("Notes") {
                    TextField("Optional notes…", text: Binding(
                        get: { entry.notes ?? "" },
                        set: { entry.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...)
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(entry) }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct NutritionField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)
        }
    }
}

// MARK: - DateFormatter helper

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()
}
