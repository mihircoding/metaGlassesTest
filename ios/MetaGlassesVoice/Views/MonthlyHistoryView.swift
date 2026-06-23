import SwiftUI

// MARK: - Monthly History View

struct MonthlyHistoryView: View {
    @EnvironmentObject var nutrition: NutritionViewModel
    @State private var displayMonth = Date()
    @State private var selectedDay: Date?

    private var calendar = Calendar.current

    private var summaries: [Date: DailySummary] {
        NutritionDataStore.shared.monthlySummaries(for: displayMonth)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month navigator
                    MonthNavigator(month: $displayMonth)
                        .padding(.horizontal)

                    // Calendar grid
                    CalendarGrid(
                        month: displayMonth,
                        summaries: summaries,
                        caloricLimit: nutrition.profile.dailyCaloricLimit,
                        selectedDay: $selectedDay
                    )
                    .padding(.horizontal)

                    // Monthly stats
                    MonthlyStatsCard(summaries: summaries, limit: nutrition.profile.dailyCaloricLimit)
                        .padding(.horizontal)

                    // Selected day detail
                    if let day = selectedDay {
                        SelectedDayCard(date: day, summaries: summaries)
                            .padding(.horizontal)
                    }

                    // Calorie trend chart
                    CalorieTrendCard(summaries: summaries, limit: nutrition.profile.dailyCaloricLimit)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("History")
        }
    }
}

// MARK: - Month Navigator

private struct MonthNavigator: View {
    @Binding var month: Date
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private let calendar = Calendar.current

    var body: some View {
        HStack {
            Button {
                month = calendar.date(byAdding: .month, value: -1, to: month)!
            } label: {
                Image(systemName: "chevron.left").font(.title3)
            }
            Spacer()
            Text(Self.fmt.string(from: month))
                .font(.title3.weight(.semibold))
            Spacer()
            Button {
                let next = calendar.date(byAdding: .month, value: 1, to: month)!
                if next <= Date() { month = next }
            } label: {
                Image(systemName: "chevron.right").font(.title3)
            }
            .disabled({
                let next = calendar.date(byAdding: .month, value: 1, to: month)!
                return calendar.compare(next, to: Date(), toGranularity: .month) == .orderedDescending
            }())
        }
    }
}

// MARK: - Calendar Grid

private struct CalendarGrid: View {
    let month: Date
    let summaries: [Date: DailySummary]
    let caloricLimit: Double
    @Binding var selectedDay: Date?
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLetters = ["S","M","T","W","T","F","S"]

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year,.month], from: month)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: first) - 1
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for d in range {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: first))
        }
        return days
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(dayLetters, id: \.self) { l in
                    Text(l).font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            summary: summaries[calendar.startOfDay(for: date)],
                            limit: caloricLimit,
                            isSelected: selectedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            isToday: calendar.isDateInToday(date)
                        ) {
                            selectedDay = selectedDay.map { calendar.isDate($0, inSameDayAs: date) } == true ? nil : date
                        }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct DayCell: View {
    let date: Date
    let summary: DailySummary?
    let limit: Double
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void
    private let calendar = Calendar.current

    private var fillRatio: Double {
        guard let s = summary, limit > 0 else { return 0 }
        return min(s.totalCalories / limit, 1.0)
    }

    private var cellColor: Color {
        guard let s = summary, s.totalCalories > 0 else { return .clear }
        if s.totalCalories > limit * 1.1 { return .red.opacity(0.7) }
        if fillRatio > 0.8  { return .orange.opacity(0.7) }
        return .green.opacity(0.7)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.orange : cellColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? Color.orange : .clear, lineWidth: 2)
                    )

                VStack(spacing: 1) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(summary != nil ? .white : .primary)

                    if let s = summary, s.totalCalories > 0 {
                        Text("\(Int(s.totalCalories / 100) * 100)")
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Monthly Stats Card

private struct MonthlyStatsCard: View {
    let summaries: [Date: DailySummary]
    let limit: Double

    private var loggedDays: [DailySummary] { summaries.values.filter { $0.totalCalories > 0 } }
    private var avgCalories: Double {
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + $1.totalCalories } / Double(loggedDays.count)
    }
    private var daysUnder: Int { loggedDays.filter { $0.totalCalories <= limit }.count }
    private var daysOver:  Int { loggedDays.filter { $0.totalCalories > limit }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Summary").font(.headline).padding(.top)

            HStack(spacing: 0) {
                StatBlock(value: "\(loggedDays.count)", label: "Days Logged", color: .blue)
                Divider().frame(height: 50)
                StatBlock(value: "\(Int(avgCalories))", label: "Avg Calories", color: .orange)
                Divider().frame(height: 50)
                StatBlock(value: "\(daysUnder)", label: "Days Under Goal", color: .green)
                Divider().frame(height: 50)
                StatBlock(value: "\(daysOver)", label: "Days Over Goal", color: .red)
            }

            // Color legend
            HStack(spacing: 12) {
                LegendDot(color: .green, label: "Under 80%")
                LegendDot(color: .orange, label: "80–110%")
                LegendDot(color: .red, label: "Over 110%")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
        .padding(.horizontal)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct StatBlock: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LegendDot: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Selected Day Card

private struct SelectedDayCard: View {
    let date: Date
    let summaries: [Date: DailySummary]
    private let calendar = Calendar.current

    private var summary: DailySummary? {
        summaries[calendar.startOfDay(for: date)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(DateFormatter.longDate.string(from: date))
                .font(.headline)
                .padding(.top)

            if let s = summary, !s.entries.isEmpty {
                VStack(spacing: 4) {
                    DayStatRow(label: "Calories", value: "\(Int(s.totalCalories)) kcal")
                    DayStatRow(label: "Protein",  value: "\(s.totalProtein.macroString)g")
                    DayStatRow(label: "Carbs",    value: "\(s.totalCarbs.macroString)g")
                    DayStatRow(label: "Fat",      value: "\(s.totalFat.macroString)g")
                }
                Divider()
                ForEach(s.entries.prefix(5)) { entry in
                    HStack {
                        Text(entry.name).font(.caption).lineLimit(1)
                        Spacer()
                        Text("\(Int(entry.scaledCalories)) kcal").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if s.entries.count > 5 {
                    Text("+\(s.entries.count - 5) more items")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("No food logged this day").foregroundStyle(.secondary).font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct DayStatRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.semibold))
        }
    }
}

// MARK: - Calorie Trend Card

private struct CalorieTrendCard: View {
    let summaries: [Date: DailySummary]
    let limit: Double

    private var sortedDays: [(Date, Double)] {
        summaries
            .filter { $0.value.totalCalories > 0 }
            .map { ($0.key, $0.value.totalCalories) }
            .sorted { $0.0 < $1.0 }
            .suffix(14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("14-Day Calorie Trend").font(.headline).padding(.top)

            if sortedDays.isEmpty {
                Text("No data to display").foregroundStyle(.secondary).font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center).padding()
            } else {
                let maxCal = max((sortedDays.map { $0.1 }.max() ?? 0) * 1.1, limit * 1.1)
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        // Limit line
                        let limitY = geo.size.height * (1 - limit / maxCal)
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: limitY))
                            p.addLine(to: CGPoint(x: geo.size.width, y: limitY))
                        }
                        .stroke(Color.red.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))

                        // Bars
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(sortedDays, id: \.0) { (_, cal) in
                                let barH = max(geo.size.height * (cal / maxCal), 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cal > limit ? Color.red.opacity(0.7) : Color.orange.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: barH)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 4)

                Text("Red line = daily goal (\(Int(limit)) kcal)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
        }
        .padding(.horizontal)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Date Formatter

extension DateFormatter {
    static let longDate: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .long; return f
    }()
}
