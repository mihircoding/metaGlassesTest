import NutraCore
import SwiftUI

/// Twelve mini-months of the year that contains `year`.
struct YearHeatmapView: View {
    let year: Date
    let status: (Date) -> DayStatus
    let onSelect: (Date) -> Void

    private var months: [Date] {
        let cal = Calendar.current
        guard let start = cal.dateInterval(of: .year, for: year)?.start else { return [] }
        return (0..<12).compactMap { cal.date(byAdding: .month, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3),
                      spacing: 12) {
                ForEach(months, id: \.self) { month in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(month.formatted(.dateTime.month(.abbreviated))).font(.caption.bold())
                        MonthGrid(month: month, compact: true, status: status, onSelect: onSelect)
                    }
                }
            }
            ProgressLegend()
        }
    }
}
