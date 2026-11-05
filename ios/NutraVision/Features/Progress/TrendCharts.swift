import Charts
import NutraCore
import SwiftUI

/// Weight (90 days) and the last 30 days of calories, sodium and saturated fat, each against its goal or limit.
/// The calorie line is the plain kcal target (not each day's exercise-adjusted goal).
struct TrendCharts: View {
    let userId: UUID
    let profile: ProfileRow?

    @Environment(AppModel.self) private var app
    @State private var weights: [WeightLogRow] = []
    @State private var days: [DayPoint] = []
    @State private var error: String?

    private struct DayPoint: Identifiable {
        let date: Date
        let total: Nutrients
        var id: Date { date }
    }

    private var targets: Targets { profile?.targets ?? .defaults }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let error {
                InlineError(message: error) { Task { await load() } }
            }
            weightChart
            kcalChart
            lineChart("Sodium (mg)", value: \.sodiumMg, limit: targets.sodiumMg)
            lineChart("Saturated fat (g)", value: \.satFatG, limit: targets.satFatG)
        }
        // Reloads when a weight is logged elsewhere in the app.
        .task(id: app.weightsVersion) { await load() }
    }

    // MARK: Charts

    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight (kg), last 90 days").font(.headline)
            if weights.isEmpty {
                Text("No weigh-ins yet").font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(weights) { w in
                        LineMark(x: .value("Date", w.measuredAt), y: .value("kg", w.weightKg))
                            .foregroundStyle(Theme.accent)
                        PointMark(x: .value("Date", w.measuredAt), y: .value("kg", w.weightKg))
                            .foregroundStyle(Theme.accent)
                    }
                    if let goal = profile?.goalWeightKg {
                        RuleMark(y: .value("Goal", goal))
                            .foregroundStyle(Theme.moderation)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Goal").font(.caption2).foregroundStyle(Theme.moderation)
                            }
                    }
                }
                .chartYScale(domain: weightDomain)
                .frame(height: 180)
            }
        }
    }

    private var weightDomain: ClosedRange<Double> {
        var values = weights.map(\.weightKg)
        if let goal = profile?.goalWeightKg { values.append(goal) }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        return (lo - 1)...(hi + 1)
    }

    private var kcalChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calories, last 30 days").font(.headline)
            if days.isEmpty {
                Text("Nothing logged in the last 30 days").font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(days) { d in
                        BarMark(x: .value("Day", d.date, unit: .day), y: .value("kcal", d.total.kcal))
                            .foregroundStyle(Theme.accent2)
                    }
                    RuleMark(y: .value("Goal", targets.kcal))
                        .foregroundStyle(Theme.moderation)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal").font(.caption2).foregroundStyle(Theme.moderation)
                        }
                }
                .frame(height: 180)
            }
        }
    }

    private func lineChart(_ title: String, value: KeyPath<Nutrients, Double>, limit: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if days.isEmpty {
                Text("Nothing logged in the last 30 days").font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(days) { d in
                        LineMark(x: .value("Day", d.date, unit: .day), y: .value(title, d.total[keyPath: value]))
                            .foregroundStyle(Theme.accent)
                        PointMark(x: .value("Day", d.date, unit: .day), y: .value(title, d.total[keyPath: value]))
                            .foregroundStyle(Theme.accent)
                    }
                    RuleMark(y: .value("Limit", limit))
                        .foregroundStyle(Theme.bad)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Limit").font(.caption2).foregroundStyle(Theme.bad)
                        }
                }
                .frame(height: 160)
            }
        }
    }

    // MARK: Loading

    private func load() async {
        let end = Backend.dayInterval(Date()).end
        let cal = Calendar.current
        let from30 = cal.date(byAdding: .day, value: -30, to: end) ?? end
        let from90 = cal.date(byAdding: .day, value: -90, to: end) ?? end
        do {
            let w = try await Backend.shared.weights(userId: userId, from: from90, to: end)
            let logs = try await Backend.shared.foodLogs(userId: userId, from: from30, to: end)
            if Task.isCancelled { return }
            weights = w
            days = Dictionary(grouping: logs, by: { cal.startOfDay(for: $0.loggedAt) })
                .map { DayPoint(date: $0.key, total: $0.value.map(\.total).sum()) }
                .sorted { $0.date < $1.date }
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }
}
