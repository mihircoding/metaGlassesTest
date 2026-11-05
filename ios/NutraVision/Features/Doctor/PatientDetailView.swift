import NutraCore
import SwiftUI

/// A linked patient, read-only: Diary | Progress | Weight & workouts | Plan & history.
struct PatientDetailView: View {
    let patient: ProfileRow

    private enum Segment: String, CaseIterable {
        case diary = "Diary", progress = "Progress", bodyLog = "Weight & workouts", plan = "Plan & history"
    }

    @State private var segment = Segment.diary
    @State private var sending = false

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
                // ponytail: NutritionProgressView(userId:) arrives in Task 22.
                ContentUnavailableView("Progress", systemImage: "chart.line.uptrend.xyaxis",
                                       description: Text("Coming soon."))
            case .bodyLog:
                PatientBodyList(userId: patient.id)
            case .plan:
                PatientPlanHistory(userId: patient.id)
            }
        }
        .navigationTitle(patient.fullName.isEmpty ? patient.email : patient.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Send recommendation") { sending = true }
            }
        }
        .sheet(isPresented: $sending) { SendRecommendationView(patient: patient) }
    }
}

/// Last 90 days of weigh-ins and workouts, newest first.
private struct PatientBodyList: View {
    let userId: UUID

    @State private var weights: [WeightLogRow] = []
    @State private var workouts: [WorkoutRow] = []
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Section { InlineError(message: error) { Task { await load() } } }
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
        do {
            weights = try await Backend.shared.weights(userId: userId, from: from, to: end)
            workouts = try await Backend.shared.workouts(userId: userId, from: from, to: end)
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
