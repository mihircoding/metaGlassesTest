import Charts
import NutraCore
import SwiftUI

/// Conditions where a symptom diary is part of routine care.
enum SymptomDiary {
    static let conditions: Set<String> = ["ibs", "ibd", "celiac", "eoe"]

    static func severityColor(_ severity: Int) -> Color {
        switch severity {
        case ..<4: return Theme.good
        case ..<SymptomSeverity.severe: return Theme.moderation
        default: return Theme.bad
        }
    }

    /// Patient-facing advice for an entry, or nil when there's nothing urgent to say.
    static func advice(symptoms: Set<Symptom>, severity: Int) -> String? {
        if symptoms.contains(.foodStuck) {
            return "If food is stuck and you can't swallow your own saliva, or it hurts to breathe, go to the emergency room now. Don't try to force it down with more food or drink. Tell your doctor about any episode, even one that cleared."
        }
        if symptoms.contains(.bloodInStool) {
            return "Tell your doctor about blood in your stool. Get urgent care if there's a lot of it, or you feel faint, dizzy or very weak."
        }
        if severity >= SymptomSeverity.severe {
            return "Severe pain that doesn't ease, or that comes with a fever, vomiting or a hard, swollen belly, needs urgent care. Otherwise, let your doctor know if it keeps happening."
        }
        return nil
    }
}

/// One diary entry: symptoms, when, severity, stool type and note.
struct SymptomRowView: View {
    let row: SymptomLogRow

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if row.symptoms.contains(where: \.isRedFlag) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.bad)
                            .accessibilityLabel("Important")
                    }
                    Text(row.symptoms.map(\.title).joined(separator: ", "))
                }
                Text(detail).font(.caption).foregroundStyle(.secondary)
                if let note = row.note, !note.isEmpty {
                    Text(note).italic().font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            CategoryChip(title: "\(row.severity)/10", color: SymptomDiary.severityColor(row.severity))
                .accessibilityLabel("Severity \(row.severity) of 10, \(SymptomSeverity.title(row.severity))")
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let when = row.loggedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        guard let bristol = row.bristol else { return when }
        return "\(when) · Bristol type \(bristol)"
    }
}

/// The worst severity logged each day, for the last two weeks.
struct SymptomChart: View {
    /// Any order.
    let rows: [SymptomLogRow]
    var days = 14

    private struct Day: Identifiable {
        let day: Date
        let worst: Int
        var id: Date { day }
    }

    private var data: [Day] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date())) ?? Date()
        let byDay = Dictionary(grouping: rows.filter { $0.loggedAt >= start }) { calendar.startOfDay(for: $0.loggedAt) }
        return byDay.map { Day(day: $0.key, worst: $0.value.map(\.severity).max() ?? 0) }.sorted { $0.day < $1.day }
    }

    var body: some View {
        let data = self.data
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        Chart(data) { d in
            BarMark(x: .value("Day", d.day, unit: .day), y: .value("Worst", d.worst))
                .foregroundStyle(SymptomDiary.severityColor(d.worst))
        }
        .chartXScale(domain: start...end)
        .chartYScale(domain: 0...10)
        .chartYAxis { AxisMarks(values: [0, 5, 10]) }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 120)
        .accessibilityLabel("Worst symptoms each day, last \(days) days")
        .accessibilityValue("Symptoms on \(data.count) of \(days) days")
    }
}

/// Foods that were often followed by symptoms, with how often.
struct TriggerRows: View {
    let result: SymptomTriggers.Result

    var body: some View {
        ForEach(result.candidates, id: \.name) { c in
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(.subheadline.weight(.semibold))
                Text("Symptoms within 6 hours after \(c.followed) of \(c.eaten) times · after \(Int((c.otherRate * 100).rounded()))% of other meals")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
