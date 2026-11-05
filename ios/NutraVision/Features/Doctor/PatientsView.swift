import NutraCore
import Observation
import SwiftUI

/// Message in red with a Retry button; the one inline-error pattern of the doctor screens.
struct InlineError: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).font(.footnote).foregroundStyle(Theme.bad)
            Button("Retry", action: retry).buttonStyle(.bordered)
        }
    }
}

/// One accepted patient with the last week of intake boiled down for the list.
struct PatientSummary: Identifiable {
    let profile: ProfileRow
    let todayKcal: Double
    /// Average kcal over the days that have any log; nil when nothing was logged in 7 days.
    let averageKcal: Double?
    let flags: [String]
    var id: UUID { profile.id }
}

@Observable
@MainActor
final class PatientsModel {
    var patients: [PatientSummary] = []
    var error: String?
    var loaded = false

    func load() async {
        do {
            let links = try await Backend.shared.careLinks().filter { $0.status == .accepted }
            let profiles = try await Backend.shared.profiles(ids: links.map(\.patientId))
            // Local days: from the start of the day 6 days ago to the end of today.
            let today = Backend.dayInterval(Date())
            let from = Calendar.current.date(byAdding: .day, value: -6, to: today.start) ?? today.start
            let todayKey = DayKey.key(for: today.start)
            var result: [PatientSummary] = []
            for profile in profiles.sorted(by: { $0.fullName < $1.fullName }) {
                let logs = try await Backend.shared.foodLogs(userId: profile.id, from: from, to: today.end)
                let byDay = Dictionary(grouping: logs, by: { DayKey.key(for: $0.loggedAt) })
                let totals: [Nutrients] = byDay.sorted { $0.key < $1.key }.map { $0.value.map(\.total).sum() }
                // ponytail: goal ignores exercise here (list view); the diary shows the exact figure.
                let flags = PatientFlags.flags(days: totals, targets: profile.targets, dailyGoalKcal: profile.targets.kcal)
                let todayKcal: Double = byDay[todayKey].map { $0.map(\.total).sum().kcal } ?? 0
                let average: Double? = totals.isEmpty ? nil : totals.reduce(0) { $0 + $1.kcal } / Double(totals.count)
                result.append(PatientSummary(profile: profile, todayKcal: todayKcal, averageKcal: average, flags: flags))
            }
            patients = result
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
        loaded = true
    }
}

struct PatientsView: View {
    @State private var model = PatientsModel()

    var body: some View {
        NavigationStack {
            List {
                if let error = model.error {
                    Section { InlineError(message: error) { Task { await model.load() } } }
                }
                if model.loaded && model.error == nil && model.patients.isEmpty {
                    Section { Text("No patients yet. Send a request from the Requests tab.").foregroundStyle(.secondary) }
                }
                ForEach(model.patients) { patient in
                    NavigationLink { PatientDetailView(patient: patient.profile) } label: { row(patient) }
                }
            }
            .overlay { if !model.loaded { ProgressView() } }
            .navigationTitle("Patients")
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    private func row(_ patient: PatientSummary) -> some View {
        let avg = patient.averageKcal.map { "7-day avg \(Int($0.rounded())) kcal" } ?? "Nothing logged in 7 days"
        return VStack(alignment: .leading, spacing: 4) {
            Text(patient.profile.fullName.isEmpty ? patient.profile.email : patient.profile.fullName).font(.headline)
            Text("Today \(Int(patient.todayKcal.rounded())) kcal · \(avg)")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach(patient.flags, id: \.self) { flag in
                Label(flag, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(Theme.moderation)
            }
        }
    }
}
