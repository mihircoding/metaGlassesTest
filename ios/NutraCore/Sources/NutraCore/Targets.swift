import Foundation

public enum Sex: String, Codable, CaseIterable, Sendable { case male, female, unspecified }

public enum Activity: String, Codable, CaseIterable, Sendable {
  case sedentary, light, moderate, very, extra

  public var multiplier: Double {
    switch self {
    case .sedentary: return 1.2
    case .light: return 1.375
    case .moderate: return 1.55
    case .very: return 1.725
    case .extra: return 1.9
    }
  }

  public var title: String {
    switch self {
    case .sedentary: return "Sedentary"
    case .light: return "Lightly active"
    case .moderate: return "Moderately active"
    case .very: return "Very active"
    case .extra: return "Extra active"
    }
  }
}

public struct BodyStats: Sendable {
  public var sex: Sex
  public var birthDate: Date?
  public var heightCm: Double?
  public var weightKg: Double?
  public var activity: Activity

  public init(sex: Sex, birthDate: Date?, heightCm: Double?, weightKg: Double?, activity: Activity) {
    self.sex = sex
    self.birthDate = birthDate
    self.heightCm = heightCm
    self.weightKg = weightKg
    self.activity = activity
  }
}

public struct Targets: Codable, Equatable, Sendable {
  public var kcal: Double
  public var proteinG: Double
  public var carbsG: Double
  public var fatG: Double
  public var satFatG: Double
  public var sodiumMg: Double
  public var fiberG: Double

  public init(kcal: Double, proteinG: Double, carbsG: Double, fatG: Double, satFatG: Double,
              sodiumMg: Double, fiberG: Double) {
    self.kcal = kcal
    self.proteinG = proteinG
    self.carbsG = carbsG
    self.fatG = fatG
    self.satFatG = satFatG
    self.sodiumMg = sodiumMg
    self.fiberG = fiberG
  }

  enum CodingKeys: String, CodingKey {
    case kcal = "kcal_target"
    case proteinG = "protein_g"
    case carbsG = "carbs_g"
    case fatG = "fat_g"
    case satFatG = "sat_fat_g"
    case sodiumMg = "sodium_mg"
    case fiberG = "fiber_g"
  }

  public static let defaults = Targets(kcal: 2000, proteinG: 100, carbsG: 250, fatG: 67, satFatG: 22,
                                       sodiumMg: 2300, fiberG: 28)
}

public enum TargetCalculator {
  /// Mifflin-St Jeor BMR; nil when height, weight or birth date is missing.
  public static func bmr(_ s: BodyStats, now: Date) -> Double? {
    guard let h = s.heightCm, let w = s.weightKg, let birth = s.birthDate else { return nil }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
    let age = Double(cal.dateComponents([.year], from: birth, to: now).year ?? 0)
    let offset: Double
    switch s.sex {
    case .male: offset = 5
    case .female: offset = -161
    case .unspecified: offset = -78
    }
    return 10 * w + 6.25 * h - 5 * age + offset
  }

  public static func targets(stats: BodyStats, conditionIds: [String], weeklyRateKg: Double,
                             now: Date = Date()) -> Targets {
    let ids = conditionIds.isEmpty ? ["general"] : conditionIds
    let conds = ids.map { ConditionCatalog.condition(id: $0) }
    let primary = conds[0]

    var rawKcal = 2000.0
    if let bmr = bmr(stats, now: now) {
      var rate = weeklyRateKg
      let pregnant = ids.contains("pregnancy")
      if pregnant && rate < 0 { rate = 0 }
      var kcal = bmr * stats.activity.multiplier + rate * 7700 / 7
      if pregnant { kcal += 300 }
      let floor: Double
      switch stats.sex {
      case .male: floor = 1500
      case .female: floor = 1200
      case .unspecified: floor = 1350
      }
      rawKcal = max(kcal, floor)
    }

    let kcal = (rawKcal / 10).rounded() * 10
    let satPct = conds.map(\.satFatPctMax).min() ?? 10
    return Targets(
      kcal: kcal,
      proteinG: (kcal * primary.proteinPct / 100 / 4).rounded(),
      carbsG: (kcal * primary.carbsPct / 100 / 4).rounded(),
      fatG: (kcal * primary.fatPct / 100 / 9).rounded(),
      satFatG: (kcal * satPct / 100 / 9).rounded(),
      sodiumMg: conds.map(\.sodiumMg).min() ?? 2300,
      fiberG: conds.map(\.fiberG).max() ?? 28)
  }
}
