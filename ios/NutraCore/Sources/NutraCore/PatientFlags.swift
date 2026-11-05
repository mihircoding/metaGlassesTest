import Foundation

public enum PatientFlags {
  /// Days over a limit among `days` (one entry per logged day, oldest to newest), as doctor-facing flag lines.
  public static func flags(days: [Nutrients], targets: Targets, dailyGoalKcal: Double) -> [String] {
    let total = days.count
    let checks: [(String, (Nutrients) -> Bool)] = [
      ("Sodium over limit", { $0.sodiumMg > targets.sodiumMg }),
      ("Saturated fat over limit", { $0.satFatG > targets.satFatG }),
      ("Calories over goal", { $0.kcal > dailyGoalKcal * 1.1 }),
    ]
    return checks.compactMap { check in
      let n = days.filter(check.1).count
      return n >= 1 ? "\(check.0) \(n) of last \(total) days" : nil
    }
  }
}
