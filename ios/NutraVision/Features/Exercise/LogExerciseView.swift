import NutraCore
import SwiftUI

/// Log one workout. Calories start from the MET estimate and stop following it once the user edits them.
struct LogExerciseView: View {
    let onSaved: () async -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ExerciseKind = .running
    @State private var startedAt: Date
    @State private var minutes = "30"
    @State private var distance = ""
    @State private var useMiles = false
    @State private var notes = ""
    @State private var kcalText = ""
    @State private var kcalEdited = false
    @State private var error: String?
    @State private var saving = false

    private static let kmPerMile = 1.609344

    init(date: Date, onSaved: @escaping () async -> Void) {
        self.onSaved = onSaved
        _startedAt = State(initialValue: date)
    }

    private func number(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }
    private var minutesValue: Double? { number(minutes) }
    private var kcalValue: Double? { number(kcalText) }
    private var distanceValue: Double? { number(distance) }
    private var valid: Bool {
        guard let m = minutesValue, m > 0, let k = kcalValue, k >= 0 else { return false }
        return distance.isEmpty || (distanceValue ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(ExerciseKind.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    DatePicker("Start", selection: $startedAt)
                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("min", text: $minutes).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("min").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Distance (optional)")
                        Spacer()
                        TextField("0", text: $distance).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Picker("Unit", selection: $useMiles) {
                            Text("km").tag(false)
                            Text("mi").tag(true)
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 90)
                    }
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("kcal", text: Binding(get: { kcalText }, set: { kcalText = $0; kcalEdited = true }))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                    TextField("Notes", text: $notes)
                }
                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(Theme.bad)
                        Button("Retry") { save() }.buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Log exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(saving || !valid) }
            }
            .onAppear { estimate() }
            .onChange(of: kind) { estimate() }
            .onChange(of: minutes) { estimate() }
        }
    }

    private func estimate() {
        guard !kcalEdited else { return }
        let k = ExerciseCalories.kcal(kind: kind, minutes: minutesValue ?? 0, weightKg: app.profile?.weightKg)
        kcalText = String(Int(k))
    }

    private func save() {
        guard let userId = Backend.shared.userId, let m = minutesValue, let k = kcalValue else { return }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = WorkoutRow(userId: userId, startedAt: startedAt, kind: kind, durationMin: m, kcal: k,
                             distanceKm: distanceValue.map { useMiles ? $0 * Self.kmPerMile : $0 },
                             notes: trimmed.isEmpty ? nil : trimmed, source: .manual, healthkitUuid: nil)
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                try await Backend.shared.insertWorkout(row)
                await app.refresh()
                await onSaved()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
