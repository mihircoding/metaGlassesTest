import NutraCore
import SwiftUI

extension DayStatus {
    /// under = teal, near = green, over = red, no data = grey.
    var color: Color {
        switch self {
        case .noData: return Color.gray.opacity(0.25)
        case .under: return Theme.accent2
        case .near: return Theme.good
        case .over: return Theme.bad
        }
    }

    var label: String {
        switch self {
        case .noData: return "no data"
        case .under: return "under goal"
        case .near: return "near goal"
        case .over: return "over goal"
        }
    }
}

/// One month as a weekday-headed grid of coloured days, starting on the locale's first weekday.
struct MonthGrid: View {
    let month: Date
    var compact = false
    let status: (Date) -> DayStatus
    let onSelect: (Date) -> Void

    private var weekdayHeaders: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Leading blanks, then every day of the month.
    private var cells: [Date?] {
        let cal = Calendar.current
        guard let start = cal.dateInterval(of: .month, for: month)?.start,
              let count = cal.range(of: .day, in: .month, for: month)?.count else { return [] }
        let lead = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7
        var out = [Date?](repeating: nil, count: lead)
        for offset in 0..<count { out.append(cal.date(byAdding: .day, value: offset, to: start)) }
        return out
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: compact ? 2 : 6), count: 7)
        LazyVGrid(columns: columns, spacing: compact ? 2 : 6) {
            ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, symbol in
                Text(symbol).font(compact ? .system(size: 7) : .caption2).foregroundStyle(.secondary)
            }
            ForEach(cells.indices, id: \.self) { index in
                if let day = cells[index] {
                    cell(day)
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let state = status(day)
        let number = Calendar.current.component(.day, from: day)
        return Button { onSelect(day) } label: {
            RoundedRectangle(cornerRadius: compact ? 2 : 8)
                .fill(state.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text("\(number)")
                        .font(compact ? .system(size: 7) : .callout)
                        .foregroundStyle(state == .noData ? Color.primary : Color.white)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(.dateTime.month(.wide).day())), \(state.label)")
    }
}

/// The month page of Progress: the grid plus a colour legend.
struct MonthCalendarView: View {
    let month: Date
    let status: (Date) -> DayStatus
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(spacing: 12) {
            MonthGrid(month: month, status: status, onSelect: onSelect)
            ProgressLegend()
        }
    }
}

struct ProgressLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach([DayStatus.under, .near, .over, .noData], id: \.label) { state in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(state.color).frame(width: 12, height: 12)
                    Text(state.label).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
