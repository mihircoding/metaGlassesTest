import Foundation

/// How a day's intake compares with its calorie goal (calendar colours).
public enum DayStatus: Equatable, Sendable {
  case noData, under, near, over

  /// `near` is within +-10 % of the goal, inclusive. Nothing logged (nil or 0 kcal) is `noData`.
  public static func classify(kcal: Double?, goal: Double) -> DayStatus {
    guard let kcal, kcal > 0 else { return .noData }
    if abs(kcal - goal) <= goal * 0.1 { return .near }
    return kcal < goal ? .under : .over
  }
}
