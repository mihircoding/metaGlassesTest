import Charts
import NutraCore
import SwiftUI

extension VitalKind: Identifiable {
    var id: String { rawValue }
    var title: String { self == .bloodPressure ? "Blood pressure" : "Blood sugar" }
}

extension BloodPressureCategory {
    var color: Color {
        switch self {
        case .normal: return Theme.good
        case .elevated: return .yellow
        case .stage1: return Theme.moderation
        case .stage2, .crisis: return Theme.bad
        }
    }
}

extension GlucoseCategory {
    var color: Color {
        switch self {
        case .inRange: return Theme.good
        case .high: return Theme.moderation
        case .low, .veryLow, .veryHigh: return Theme.bad
        }
    }
}

/// Glucose is stored in mg/dL; mmol/L is a display and entry preference.
enum GlucoseUnit: String, CaseIterable, Identifiable {
    case mgDl = "mg/dL", mmolL = "mmol/L"

    static let storageKey = "vitals.glucoseUnit"
    var id: String { rawValue }

    func value(_ mgDl: Double) -> Double { self == .mgDl ? mgDl : mgDl / GlucoseCategory.mgPerMmol }
    func mgDl(fromEntered value: Double) -> Double { self == .mgDl ? value : value * GlucoseCategory.mgPerMmol }

    func format(_ mgDl: Double) -> String {
        switch self {
        case .mgDl: return "\(Int(mgDl.rounded())) mg/dL"
        case .mmolL: return value(mgDl).formatted(.number.precision(.fractionLength(1))) + " mmol/L"
        }
    }
}

struct CategoryChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

/// One reading: value, when, context and note, with its category.
struct VitalRowView: View {
    let vital: VitalLogRow
    let unit: GlucoseUnit

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.body.monospacedDigit())
                Text(detail).font(.caption).foregroundStyle(.secondary)
                if let note = vital.note, !note.isEmpty {
                    Text(note).italic().font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let c = vital.bloodPressureCategory {
                CategoryChip(title: c.title, color: c.color)
            } else if let c = vital.glucoseCategory {
                CategoryChip(title: c.title, color: c.color)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var value: String {
        if let s = vital.systolic, let d = vital.diastolic {
            return "\(s)/\(d) mmHg" + (vital.pulse.map { " · pulse \($0)" } ?? "")
        }
        return vital.glucoseMgDl.map(unit.format) ?? ""
    }

    private var detail: String {
        let when = vital.measuredAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        if let context = vital.glucoseContext { return "\(when) · \(context.title)" }
        return when
    }
}

/// Systolic and diastolic over time, with the 130/80 goal most adults are given.
struct BloodPressureChart: View {
    /// Oldest first.
    let readings: [VitalLogRow]

    var body: some View {
        Chart {
            ForEach(readings) { v in
                if let s = v.systolic, let d = v.diastolic {
                    LineMark(x: .value("Date", v.measuredAt), y: .value("mmHg", s), series: .value("Reading", "Systolic"))
                        .foregroundStyle(Theme.bad)
                    LineMark(x: .value("Date", v.measuredAt), y: .value("mmHg", d), series: .value("Reading", "Diastolic"))
                        .foregroundStyle(Theme.accent2)
                }
            }
            RuleMark(y: .value("Goal", 130)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.secondary)
            RuleMark(y: .value("Goal", 80)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.secondary)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 140)
        .accessibilityLabel("Blood pressure chart")
        .accessibilityValue(summary)
    }

    private var summary: String {
        let bp = readings.compactMap { v in v.systolic.flatMap { s in v.diastolic.map { (s, $0) } } }
        guard !bp.isEmpty else { return "" }
        let s = bp.map(\.0).reduce(0, +) / bp.count
        let d = bp.map(\.1).reduce(0, +) / bp.count
        return "\(bp.count) readings, average \(s) over \(d)"
    }
}

/// Glucose readings as dots colored by category, between the 70 and 180 mg/dL lines.
struct GlucoseChart: View {
    /// Oldest first.
    let readings: [VitalLogRow]
    let unit: GlucoseUnit

    var body: some View {
        Chart {
            ForEach(readings) { v in
                if let mg = v.glucoseMgDl {
                    PointMark(x: .value("Date", v.measuredAt), y: .value(unit.rawValue, unit.value(mg)))
                        .foregroundStyle(v.glucoseCategory?.color ?? .secondary)
                        .symbolSize(30)
                }
            }
            RuleMark(y: .value("Low", unit.value(70))).lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(Theme.bad.opacity(0.6))
            RuleMark(y: .value("High", unit.value(180))).lineStyle(StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(Theme.moderation.opacity(0.6))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 140)
        .accessibilityLabel("Blood sugar chart")
        .accessibilityValue("\(readings.count) readings")
    }
}
