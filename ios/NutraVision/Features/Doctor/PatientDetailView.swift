import NutraCore
import SwiftUI

/// A linked patient, read-only: Diary | Progress | Body (vitals, fluids, weigh-ins, workouts) | Plan & history,
/// plus the doctor's own private Notes.
struct PatientDetailView: View {
    let patient: ProfileRow

    private enum Segment: String, CaseIterable {
        case diary = "Diary", progress = "Progress", bodyLog = "Body", plan = "Plan", notes = "Notes"
    }

    @State private var segment = Segment.diary
    @State private var sending = false
    /// The last 30 days as a CSV file, prepared when the screen opens so the share button works at once.
    @State private var export: URL?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $segment) {
                ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            switch segment {
            case .diary:
                DiaryView(userId: patient.id, readOnly: true, subject: patient)
            case .progress:
                NutritionProgressView(userId: patient.id, subject: patient)
            case .bodyLog:
                PatientBodyList(patient: patient)
            case .plan:
                PatientPlanHistory(userId: patient.id)
            case .notes:
                ClinicalNotesView(patient: patient)
            }
        }
        .navigationTitle(patient.fullName.isEmpty ? patient.email : patient.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Send recommendation") { sending = true }
            }
            if let export {
                ToolbarItem(placement: .secondaryAction) {
                    ShareLink(item: export) {
                        Label("Export last \(DiaryExport.days) days (CSV)", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $sending) { SendRecommendationView(patient: patient) }
        .task { export = try? await DiaryExport.file(for: patient) }  // no button if it fails
    }
}

/// Last 90 days of blood pressure, blood sugar, weigh-ins and workouts, 30 days of symptoms and
/// 14 days of fluids; newest first.
private struct PatientBodyList: View {
    let patient: ProfileRow
    private var userId: UUID { patient.id }

    @AppStorage(GlucoseUnit.storageKey) private var unit = GlucoseUnit.mgDl
    @State private var weights: [WeightLogRow] = []
    @State private var workouts: [WorkoutRow] = []
    /// Oldest first.
    @State private var vitals: [VitalLogRow] = []
    @State private var fluidDays: [FluidDay] = []
    /// Oldest first. Nil when the server has no symptom diary (before migration 0007).
    @State private var symptoms: [SymptomLogRow]?
    @State private var triggers = SymptomTriggers.Result(candidates: [], baseline: 0)
    @State private var error: String?

    private struct FluidDay: Identifiable {
        let day: Date
        let ml: Double
        var id: Date { day }
    }

    private var bloodPressure: [VitalLogRow] { vitals.filter { $0.kind == .bloodPressure } }
    private var glucose: [VitalLogRow] { vitals.filter { $0.kind == .glucose } }

    var body: some View {
        List {
            if let error {
                Section { InlineError(message: error) { Task { await load() } } }
            }
            Section("Blood pressure") {
                if bloodPressure.isEmpty { Text("No readings").foregroundStyle(.secondary) }
                if bloodPressure.count >= 2 { BloodPressureChart(readings: bloodPressure) }
                ForEach(bloodPressure.reversed().prefix(20)) { VitalRowView(vital: $0, unit: unit) }
            }
            Section("Blood sugar") {
                if glucose.isEmpty { Text("No readings").foregroundStyle(.secondary) }
                if glucose.count >= 2 { GlucoseChart(readings: glucose, unit: unit) }
                ForEach(glucose.reversed().prefix(20)) { VitalRowView(vital: $0, unit: unit) }
            }
            if let symptoms {
                Section {
                    if symptoms.isEmpty { Text("No symptoms logged").foregroundStyle(.secondary) }
                    if !symptoms.isEmpty { SymptomChart(rows: symptoms) }
                    if !triggers.candidates.isEmpty {
                        Text("Often followed by symptoms").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        TriggerRows(result: triggers)
                    }
                    ForEach(symptoms.reversed().prefix(20)) { SymptomRowView(row: $0) }
                } header: {
                    Text("Symptoms, last 30 days")
                } footer: {
                    if !triggers.candidates.isEmpty {
                        Text("Foods logged in the 6 hours before symptoms, compared with the patient's other meals. A pattern to discuss, not a diagnosis.")
                    }
                }
            }
            Section {
                if fluidDays.isEmpty { Text("No drinks logged").foregroundStyle(.secondary) }
                ForEach(fluidDays) { entry in
                    let over = patient.fluidLimitMl.map { entry.ml > $0 } ?? false
                    HStack {
                        Text(entry.day, format: .dateTime.weekday(.abbreviated).month().day())
                        Spacer()
                        Text("\(Int(entry.ml.rounded())) ml").monospacedDigit()
                            .foregroundStyle(over ? Theme.bad : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Fluids, last 14 days")
            } footer: {
                if let limit = patient.fluidLimitMl { Text("Patient's limit: \(Int(limit)) ml a day.") }
            }
            Section("Weight") {
                if weights.isEmpty { Text("No weigh-ins").foregroundStyle(.secondary) }
                ForEach(weights.reversed()) { w in
                    HStack {
                        Text(w.measuredAt, format: .dateTime.month().day().year())
                        if w.source == .healthkit { HealthHeart() }
                        Spacer()
                        Text("\(w.weightKg.formatted(.number.precision(.fractionLength(1)))) kg").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Workouts") {
                if workouts.isEmpty { Text("No workouts").foregroundStyle(.secondary) }
                ForEach(workouts.reversed()) { w in
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(spacing: 4) {
                                Text(w.kind.title)
                                if w.source == .healthkit { HealthHeart() }
                            }
                            Text(w.startedAt, format: .dateTime.month().day().year())
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(w.durationMin.rounded())) min · \(Int(w.kcal.rounded())) kcal")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        let end = Backend.dayInterval(Date()).end
        let from = Calendar.current.date(byAdding: .day, value: -90, to: end) ?? end
        let fluidsFrom = Calendar.current.date(byAdding: .day, value: -14, to: end) ?? end
        do {
            weights = try await Backend.shared.weights(userId: userId, from: from, to: end)
            workouts = try await Backend.shared.workouts(userId: userId, from: from, to: end)
            vitals = try await Backend.shared.vitals(userId: userId, from: from, to: end)
            let drinks = try await Backend.shared.fluids(userId: userId, from: fluidsFrom, to: end)
            let byDay = Dictionary(grouping: drinks) { Calendar.current.startOfDay(for: $0.loggedAt) }
            fluidDays = byDay.map { day, rows in FluidDay(day: day, ml: rows.reduce(0) { $0 + $1.ml }) }
                .sorted { $0.day > $1.day }
            // Best effort, so the tab still works on a backend without migration 0007.
            let symptomsFrom = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
            symptoms = try? await Backend.shared.symptoms(userId: userId, from: symptomsFrom, to: end)
            if let symptoms, !symptoms.isEmpty,
               let logs = try? await Backend.shared.foodLogs(userId: userId, from: symptomsFrom, to: end) {
                triggers = SymptomTriggers.analyze(meals: logs.map { (name: $0.name, time: $0.loggedAt) },
                                                   symptoms: symptoms.map(\.entry), asOf: Date())
            }
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }
}

/// The patient's active plan and what this doctor has recommended, with each status.
private struct PatientPlanHistory: View {
    let userId: UUID

    @State private var plan: DietPlanRow?
    @State private var sent: [RecommendationRow] = []
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Section { InlineError(message: error) { Task { await load() } } }
            }
            Section("Active plan") {
                if let plan {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name).font(.headline)
                        if let notes = plan.notes, !notes.isEmpty {
                            Text(notes).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text("\(Int(plan.targets.kcal.rounded())) kcal · sodium \(Int(plan.targets.sodiumMg.rounded())) mg")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No active plan").foregroundStyle(.secondary)
                }
            }
            Section("Recommendations sent") {
                if sent.isEmpty { Text("None yet").foregroundStyle(.secondary) }
                ForEach(sent) { rec in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(title(rec.kind))
                            Spacer()
                            Text(rec.status.rawValue.capitalized).font(.footnote.bold()).foregroundStyle(color(rec.status))
                        }
                        if let message = rec.message, !message.isEmpty {
                            Text(message).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func title(_ kind: RecommendationKind) -> String {
        switch kind {
        case .targets: return "New targets"
        case .dietPlan: return "Diet plan"
        case .note: return "Note"
        }
    }

    private func color(_ status: RecommendationStatus) -> Color {
        switch status {
        case .pending: return Theme.moderation
        case .accepted: return Theme.good
        case .declined: return Theme.bad
        }
    }

    private func load() async {
        do {
            let plans = try await Backend.shared.dietPlans(userId: userId)
            let all = try await Backend.shared.recommendations()
            plan = plans.first { $0.isActive }
            sent = all.filter { $0.patientId == userId }
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }
}
