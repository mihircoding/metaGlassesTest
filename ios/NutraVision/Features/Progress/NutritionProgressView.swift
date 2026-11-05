import NutraCore
import SwiftUI

/// Progress: month calendar, year heatmap and trend charts. A doctor passes the patient's profile as `subject`.
/// Wrap in a NavigationStack (PatientTabs and the doctor's patient list do).
struct NutritionProgressView: View {
    let userId: UUID
    let subject: ProfileRow?

    @Environment(AppModel.self) private var app
    private enum Mode: String, CaseIterable { case month = "Month", year = "Year", trends = "Trends" }
    @State private var mode = Mode.month
    /// Any date inside the month (or year) on screen.
    @State private var anchor = Date()
    @State private var kcalByDay: [String: Double] = [:]
    /// That day's workouts, only loaded when the profile adds exercise back to the goal.
    @State private var exerciseDays: [String: DayModel] = [:]
    @State private var error: String?
    @State private var selected: Date?

    init(userId: UUID, subject: ProfileRow? = nil) {
        self.userId = userId
        self.subject = subject
    }

    private var profile: ProfileRow? { subject ?? app.profile }
    private var targets: Targets { profile?.targets ?? .defaults }
    private var addExercise: Bool { profile?.addExerciseKcal == true }

    private var visibleRange: DateInterval {
        let unit: Calendar.Component = mode == .year ? .year : .month
        return Calendar.current.dateInterval(of: unit, for: anchor) ?? Backend.dayInterval(anchor)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if mode == .trends {
                    TrendCharts(userId: userId, profile: profile)
                } else {
                    stepper
                    if let error {
                        InlineError(message: error) { Task { await load() } }
                    }
                    if mode == .month {
                        MonthCalendarView(month: anchor, status: status, onSelect: { selected = $0 })
                    } else {
                        YearHeatmapView(year: anchor, status: status, onSelect: { selected = $0 })
                    }
                }
            }
            .padding()
        }
        .navigationDestination(item: $selected) { day in
            DiaryView(userId: userId, readOnly: subject != nil, date: day, subject: subject)
        }
        .task(id: "\(mode.rawValue)|\(visibleRange.start.timeIntervalSince1970)") { await load() }
    }

    private var stepper: some View {
        HStack {
            Button { step(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(mode == .month ? "Previous month" : "Previous year")
            Spacer()
            Text(mode == .month ? anchor.formatted(.dateTime.month(.wide).year()) : anchor.formatted(.dateTime.year()))
                .font(.headline)
            Spacer()
            Button { step(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel(mode == .month ? "Next month" : "Next year")
        }
        .buttonStyle(.borderless)
    }

    private func step(_ n: Int) {
        anchor = Calendar.current.date(byAdding: mode == .month ? .month : .year, value: n, to: anchor) ?? anchor
    }

    /// The day's colour: its intake against the shared goal (target plus that day's counted exercise).
    private func status(_ day: Date) -> DayStatus {
        let key = DayKey.key(for: day)
        let goal = AppModel.goalKcal(targets: targets, addExerciseKcal: addExercise, day: exerciseDays[key])
        return DayStatus.classify(kcal: kcalByDay[key], goal: goal)
    }

    /// One query per visible range, grouped by local day.
    private func load() async {
        guard mode != .trends else { return }
        let range = visibleRange
        do {
            let logs = try await Backend.shared.foodLogs(userId: userId, from: range.start, to: range.end)
            var workouts: [WorkoutRow] = []
            if addExercise {
                workouts = try await Backend.shared.workouts(userId: userId, from: range.start, to: range.end)
            }
            if Task.isCancelled { return }
            kcalByDay = Dictionary(grouping: logs, by: { DayKey.key(for: $0.loggedAt) })
                .mapValues { $0.reduce(0) { $0 + $1.total.kcal } }
            var days: [String: DayModel] = [:]
            for (key, rows) in Dictionary(grouping: workouts, by: { DayKey.key(for: $0.startedAt) }) {
                let model = DayModel(userId: userId, date: rows[0].startedAt)
                model.workouts = rows
                days[key] = model
            }
            exerciseDays = days
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }
}
