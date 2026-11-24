import Foundation

/// AHA/ACC 2017 adult blood pressure categories.
public enum BloodPressureCategory: Int, Sendable, Comparable, CaseIterable {
  case normal, elevated, stage1, stage2, crisis

  /// The higher of the two numbers' categories decides.
  public static func classify(systolic: Int, diastolic: Int) -> BloodPressureCategory {
    if systolic > 180 || diastolic > 120 { return .crisis }
    if systolic >= 140 || diastolic >= 90 { return .stage2 }
    if systolic >= 130 || diastolic >= 80 { return .stage1 }
    if systolic >= 120 { return .elevated }
    return .normal
  }

  public var title: String {
    switch self {
    case .normal: return "Normal"
    case .elevated: return "Elevated"
    case .stage1: return "High (stage 1)"
    case .stage2: return "High (stage 2)"
    case .crisis: return "Very high"
    }
  }

  public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// When a glucose reading was taken; the targets differ before and after eating.
public enum GlucoseContext: String, Codable, Sendable, CaseIterable {
  case fasting, beforeMeal = "before_meal", afterMeal = "after_meal", bedtime, other

  public var title: String {
    switch self {
    case .fasting: return "Fasting"
    case .beforeMeal: return "Before a meal"
    case .afterMeal: return "1–2 h after a meal"
    case .bedtime: return "Bedtime"
    case .other: return "Other"
    }
  }
}

/// ADA targets for most non-pregnant adults with diabetes: 80–130 mg/dL before meals, under 180
/// after; under 70 is low and under 54 is very low. 250 and over is flagged as very high.
public enum GlucoseCategory: Int, Sendable, Comparable {
  case veryLow, low, inRange, high, veryHigh

  public static let mgPerMmol = 18.0

  public static func classify(mgDl: Double, context: GlucoseContext) -> GlucoseCategory {
    if mgDl < 54 { return .veryLow }
    if mgDl < 70 { return .low }
    if mgDl >= 250 { return .veryHigh }
    switch context {
    case .fasting, .beforeMeal: return mgDl > 130 ? .high : .inRange
    case .afterMeal, .bedtime, .other: return mgDl > 180 ? .high : .inRange
    }
  }

  public var title: String {
    switch self {
    case .veryLow: return "Very low"
    case .low: return "Low"
    case .inRange: return "In range"
    case .high: return "High"
    case .veryHigh: return "Very high"
    }
  }

  public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Doctor-facing flag lines from a patient's recent readings and fluid totals, like `PatientFlags`.
public enum VitalFlags {
  public static func flags(bloodPressure: [(systolic: Int, diastolic: Int)],
                           glucose: [(mgDl: Double, context: GlucoseContext)],
                           fluidDays: [Double], fluidLimitMl: Double?) -> [String] {
    var out: [String] = []
    let bp = bloodPressure.map { BloodPressureCategory.classify(systolic: $0.systolic, diastolic: $0.diastolic) }
    let crises = bp.filter { $0 == .crisis }.count
    if crises > 0 {
      out.append("Blood pressure over 180/120 \(times(crises))")
    }
    let stage2 = bp.filter { $0 == .stage2 }.count
    if stage2 > 0 {
      out.append("Blood pressure 140/90 or higher on \(stage2) of \(bp.count) readings")
    }
    let g = glucose.map { GlucoseCategory.classify(mgDl: $0.mgDl, context: $0.context) }
    let lows = g.filter { $0 <= .low }.count
    if lows > 0 { out.append("Low glucose (under 70) \(times(lows))") }
    let veryHigh = g.filter { $0 == .veryHigh }.count
    if veryHigh > 0 { out.append("Glucose 250 or higher \(times(veryHigh))") }
    if let limit = fluidLimitMl, limit > 0 {
      let over = fluidDays.filter { $0 > limit }.count
      if over > 0 { out.append("Fluids over limit \(over) of last \(fluidDays.count) days") }
    }
    return out
  }

  private static func times(_ n: Int) -> String { n == 1 ? "once" : "\(n) times" }
}
