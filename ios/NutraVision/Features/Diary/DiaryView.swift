import NutraCore
import SwiftUI

/// One day's food and exercise. Reused read-only by the doctor and opened on a given day by Progress.
/// Wrap in a NavigationStack (PatientTabs does).
struct DiaryView: View {
    let userId: UUID
    let readOnly: Bool
    /// A patient's profile when a doctor reads their diary: their targets, conditions and exercise setting apply.
    let subject: ProfileRow?

    @Environment(AppModel.self) private var app
    @State private var date: Date
    @State private var own: DayModel
    @State private var error: String?
    @State private var addTarget: AddTarget?
    @State private var editing: FoodLogRow?

    private struct AddTarget: Identifiable {
        let meal: Meal
        var id: String { meal.rawValue }
    }

    init(userId: UUID, readOnly: Bool, date: Date = Date(), subject: ProfileRow? = nil) {
        self.userId = userId
        self.readOnly = readOnly
        self.subject = subject
        _date = State(initialValue: date)
        _own = State(initialValue: DayModel(userId: userId, date: date))
    }

    /// Today's shared model when it is the signed-in user's today, so edits elsewhere show here too.
    private var day: DayModel {
        if let t = app.today, t.userId == userId, Calendar.current.isDateInToday(date) { return t }
        return own
    }

    private var targets: Targets { subject?.targets ?? app.targets }
    private var addExercise: Bool { (subject ?? app.profile)?.addExerciseKcal == true }
    private var conditionIds: [String] { (subject ?? app.profile)?.conditions ?? [] }
    private var goal: Double { AppModel.goalKcal(targets: targets, addExerciseKcal: addExercise, day: day) }
    private var remaining: Double { goal - day.consumed.kcal }

    var body: some View {
        List {
            if let error {
                Section {
                    Text(error).font(.footnote).foregroundStyle(Theme.bad)
                    Button("Retry") { Task { await reload() } }.buttonStyle(.bordered)
                }
            }
            Section {
                dateStepper
                equation
                NavigationLink("Nutrition") { DayNutritionView(consumed: day.consumed, targets: targets) }
            }
            ForEach(Meal.allCases, id: \.self) { meal in mealSection(meal) }
            Section("Exercise") {
                if day.workouts.isEmpty {
                    Text("No exercise logged").foregroundStyle(.secondary)
                }
                ForEach(day.workouts) { w in
                    HStack {
                        Text(w.kind.capitalized)
                        Spacer()
                        Text("\(Int(w.durationMin.rounded())) min · \(Int(w.kcal.rounded())) kcal")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Diary")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: date) { await reload() }
        .sheet(item: $addTarget, onDismiss: { Task { await reload() } }) { target in
            AddFoodView(meal: target.meal, date: date)
        }
        .sheet(item: $editing) { row in
            EditLogSheet(row: row) { await reload() }
        }
    }

    // MARK: Header

    private var dateStepper: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous day")
            Spacer()
            Text(Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday().month().day()))
                .font(.headline)
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next day")
        }
        .buttonStyle(.borderless)
    }

    private var equation: some View {
        HStack {
            term(targets.kcal, "Goal")
            Text("−")
            term(day.consumed.kcal, "Food")
            Text("+")
            term(AppModel.countedExerciseKcal(addExerciseKcal: addExercise, day: day), "Exercise")
            Text("=")
            term(remaining, "Remaining").foregroundStyle(remaining < 0 ? Theme.bad : Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func term(_ value: Double, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value.rounded()))").font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Meals

    private func mealSection(_ meal: Meal) -> some View {
        let rows = day.logs.filter { $0.meal == meal }
        let kcal = rows.reduce(0) { $0 + $1.total.kcal }
        return Section {
            ForEach(rows) { row in
                Button { if !readOnly { editing = row } } label: { logRow(row) }
                    .buttonStyle(.plain)
                    .swipeActions {
                        if !readOnly {
                            Button(role: .destructive) { Task { await delete(row) } } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
            if !readOnly {
                Button("Add Food") { addTarget = AddTarget(meal: meal) }
            }
        } header: {
            HStack { Text(meal.title); Spacer(); Text("\(Int(kcal.rounded())) kcal") }
        }
    }

    private func logRow(_ row: FoodLogRow) -> some View {
        // consumed = .zero: each food is judged on its own, for speed (colour only).
        let verdict = HealthVerdict.evaluate(name: row.name, item: row.total, targets: targets,
                                             dailyGoalKcal: goal, consumed: .zero,
                                             conditionIds: conditionIds)
        return HStack {
            Circle().fill(verdict.level.color).frame(width: 10, height: 10).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                Text("\(row.servingDesc) × \(row.servings.formatted(.number.precision(.fractionLength(0...2))))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(row.total.kcal.rounded()))").foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    // MARK: Actions

    private func move(_ days: Int) {
        date = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func reload() async {
        own.date = date
        do {
            try await day.load()
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }

    private func delete(_ row: FoodLogRow) async {
        do {
            try await Backend.shared.deleteFoodLog(id: row.id)
            await reload()
            if userId == Backend.shared.userId { await app.refresh() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Change servings and meal of one logged food.
private struct EditLogSheet: View {
    let row: FoodLogRow
    let onSaved: () async -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Double
    @State private var meal: Meal
    @State private var error: String?
    @State private var saving = false

    init(row: FoodLogRow, onSaved: @escaping () async -> Void) {
        self.row = row
        self.onSaved = onSaved
        _servings = State(initialValue: row.servings)
        _meal = State(initialValue: row.meal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(row.name) {
                    Stepper(value: $servings, in: 0.25...50, step: 0.25) {
                        Text("Servings: \(servings.formatted(.number.precision(.fractionLength(0...2))))")
                    }
                    Picker("Meal", selection: $meal) {
                        ForEach(Meal.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Text("\(Int(row.perServing.scaled(by: servings).kcal.rounded())) kcal").foregroundStyle(.secondary)
                }
                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(Theme.bad)
                        Button("Retry") { save() }.buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(saving) }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        var updated = row
        updated.servings = servings
        updated.meal = meal
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                try await Backend.shared.updateFoodLog(updated)
                await onSaved()
                if row.userId == Backend.shared.userId { await app.refresh() }
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
