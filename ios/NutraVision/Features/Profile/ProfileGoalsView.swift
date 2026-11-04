import NutraCore
import SwiftUI

private let kgPerLb = 0.45359237
private let cmPerInch = 2.54

private let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

extension ProfileRow {
    /// Targets follow the body, conditions and pace while they are automatic.
    mutating func recomputeTargets() {
        guard targetsSource == .auto else { return }
        let fresh = TargetCalculator.targets(stats: bodyStats, conditionIds: conditions, weeklyRateKg: weeklyRateKg)
        if fresh != targets { targets = fresh }
    }
}

// MARK: - Sections (shared by onboarding steps and Profile & Goals)

/// Sex, birth date, height, weight, activity.
struct BodySection: View {
    @Binding var draft: ProfileRow

    private var birth: Binding<Date> {
        Binding(
            get: { draft.birthDate.flatMap { dayFormatter.date(from: $0) } ?? dayFormatter.date(from: "1990-01-01")! },
            set: { draft.birthDate = dayFormatter.string(from: $0) })
    }

    var body: some View {
        Section("About you") {
            Picker("Sex", selection: $draft.sex) {
                ForEach(Sex.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            DatePicker("Birth date", selection: birth, in: ...Date(), displayedComponents: .date)
            HeightField(cm: $draft.heightCm)
            WeightField(title: "Weight", kg: $draft.weightKg)
            Picker("Activity", selection: $draft.activity) {
                ForEach(Activity.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        }
    }
}

/// Multi-select conditions; the first one picked is the primary.
struct ConditionsSection: View {
    @Binding var draft: ProfileRow

    var body: some View {
        Section("Health conditions") {
            ForEach(ConditionCatalog.all) { condition in
                Button {
                    if let i = draft.conditions.firstIndex(of: condition.id) {
                        draft.conditions.remove(at: i)
                    } else {
                        draft.conditions.append(condition.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: condition.icon).foregroundStyle(Theme.accent2).frame(width: 28)
                        VStack(alignment: .leading) {
                            Text(condition.name).foregroundStyle(.primary)
                            Text(condition.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if draft.conditions.first == condition.id {
                            Text("Primary").font(.caption.bold()).foregroundStyle(Theme.accent)
                        }
                        if draft.conditions.contains(condition.id) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
    }
}

/// Goal weight and weekly pace (-1...+1 kg/week).
struct GoalSection: View {
    @Binding var draft: ProfileRow

    private var paceLabel: String {
        let kg = draft.weeklyRateKg
        let lb = kg / kgPerLb
        return String(format: "%+.2f kg/week (%+.2f lb/week)", kg, lb)
    }

    var body: some View {
        Section("Goal") {
            WeightField(title: "Goal weight", kg: $draft.goalWeightKg)
            VStack(alignment: .leading) {
                Text(paceLabel).font(.subheadline)
                Slider(value: $draft.weeklyRateKg, in: -1...1, step: 0.25)
            }
        }
    }
}

/// Editable daily targets; any edit makes them custom.
struct TargetsSection: View {
    @Binding var draft: ProfileRow

    private func field(_ title: String, _ unit: String, _ path: WritableKeyPath<Targets, Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(unit, value: Binding(
                get: { draft.targets[keyPath: path] },
                set: { draft.targets[keyPath: path] = $0; draft.targetsSource = .custom }),
                format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            Text(unit).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
        }
    }

    var body: some View {
        Section {
            field("Calories", "kcal", \.kcal)
            field("Protein", "g", \.proteinG)
            field("Carbs", "g", \.carbsG)
            field("Fat", "g", \.fatG)
            field("Saturated fat", "g", \.satFatG)
            field("Sodium", "mg", \.sodiumMg)
            field("Fiber", "g", \.fiberG)
            Toggle("Add exercise calories to goal", isOn: $draft.addExerciseKcal)
            if draft.targetsSource != .auto {
                Button("Reset to recommended") {
                    draft.targetsSource = .auto
                    draft.recomputeTargets()
                }
            }
        } header: {
            Text("Daily targets")
        } footer: {
            Text(draft.targetsSource == .auto ? "Recommended for your body and conditions." : "Custom targets.")
        }
    }
}

// MARK: - Unit fields (cm/kg are stored; ft-in and lb are input conveniences)

struct HeightField: View {
    @Binding var cm: Double?
    @State private var imperial = false

    private var feet: Binding<Double?> {
        Binding(get: { cm.map { ($0 / cmPerInch / 12).rounded(.down) } },
                set: { cm = (($0 ?? 0) * 12 + (inches.wrappedValue ?? 0)) * cmPerInch })
    }
    private var inches: Binding<Double?> {
        Binding(get: { cm.map { ($0 / cmPerInch).truncatingRemainder(dividingBy: 12) } },
                set: { cm = ((feet.wrappedValue ?? 0) * 12 + ($0 ?? 0)) * cmPerInch })
    }

    var body: some View {
        HStack {
            Text("Height")
            Spacer()
            if imperial {
                TextField("ft", value: feet, format: .number.precision(.fractionLength(0))).frame(width: 40)
                Text("ft")
                TextField("in", value: inches, format: .number.precision(.fractionLength(0...1))).frame(width: 50)
                Text("in")
            } else {
                TextField("cm", value: $cm, format: .number.precision(.fractionLength(0...1))).frame(width: 70)
                Text("cm")
            }
            Picker("Unit", selection: $imperial) {
                Text("cm").tag(false)
                Text("ft/in").tag(true)
            }
            .pickerStyle(.menu).labelsHidden()
        }
        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
    }
}

struct WeightField: View {
    let title: String
    @Binding var kg: Double?
    @State private var pounds = false

    private var shown: Binding<Double?> {
        Binding(get: { pounds ? kg.map { $0 / kgPerLb } : kg },
                set: { kg = pounds ? $0.map { $0 * kgPerLb } : $0 })
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(pounds ? "lb" : "kg", value: shown, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
            Picker("Unit", selection: $pounds) {
                Text("kg").tag(false)
                Text("lb").tag(true)
            }
            .pickerStyle(.menu).labelsHidden()
        }
    }
}

// MARK: - Profile & Goals

/// Everything editable about the body, conditions, goal and targets, saved in one go.
struct ProfileGoalsView: View {
    @Environment(AppModel.self) private var app
    @State private var draft: ProfileRow
    @State private var saving = false
    @State private var error: String?

    init(profile: ProfileRow) {
        var start = profile
        start.recomputeTargets()
        _draft = State(initialValue: start)
    }

    var body: some View {
        Form {
            BodySection(draft: $draft)
            ConditionsSection(draft: $draft)
            GoalSection(draft: $draft)
            TargetsSection(draft: $draft)
            if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
            Button {
                Task { await save() }
            } label: {
                if saving { ProgressView() } else { Text("Save") }
            }
            .disabled(saving || draft.heightCm == nil || draft.weightKg == nil)
        }
        .navigationTitle("Profile & Goals")
        .onChange(of: draft) { _, _ in draft.recomputeTargets() }
    }

    private func save() async {
        saving = true
        error = nil
        do { try await app.saveProfile(draft) } catch { self.error = error.localizedDescription }
        saving = false
    }
}
