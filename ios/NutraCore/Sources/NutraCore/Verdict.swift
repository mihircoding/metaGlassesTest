import Foundation

public enum Severity: Int, Comparable, Sendable {
  case bad, caution, good
  public static func < (l: Severity, r: Severity) -> Bool { l.rawValue < r.rawValue }
}

public struct VerdictReason: Equatable, Sendable {
  public var severity: Severity
  public var text: String
  public init(severity: Severity, text: String) {
    self.severity = severity
    self.text = text
  }
}

public enum VerdictLevel: String, Sendable {
  case goodFit = "Good fit"
  case moderation = "OK in moderation"
  case notRecommended = "Not recommended"
}

public struct Verdict: Equatable, Sendable {
  public var level: VerdictLevel
  public var reasons: [VerdictReason]
  public init(level: VerdictLevel, reasons: [VerdictReason]) {
    self.level = level
    self.reasons = reasons
  }
}

public enum HealthVerdict {
  public static func evaluate(name: String, item: Nutrients, targets: Targets, dailyGoalKcal: Double,
                              consumed: Nutrients, conditionIds: [String]) -> Verdict {
    let idList = conditionIds.isEmpty ? ["general"] : conditionIds
    let ids = Set(idList)
    func has(_ xs: String...) -> Bool { xs.contains { ids.contains($0) } }
    func n(_ x: Double) -> Int { Int(x.rounded()) }

    var out: [VerdictReason] = []
    func add(_ s: Severity, _ t: String) { out.append(VerdictReason(severity: s, text: t)) }

    // item sodium / day sodium
    let sodiumSev: Severity = has("hypertension", "heart_disease", "ckd", "liver") ? .bad : .caution
    if item.sodiumMg > 0.4 * targets.sodiumMg {
      // A zero target would make the percentage infinite (and Int(inf) traps), so word it without one.
      let pct = targets.sodiumMg > 0 ? ", \(n(item.sodiumMg / targets.sodiumMg * 100))% of your daily limit" : ""
      add(sodiumSev, "High sodium, \(n(item.sodiumMg)) mg\(pct)")
    }
    if consumed.sodiumMg + item.sodiumMg > targets.sodiumMg {
      add(sodiumSev, "Puts you over today's sodium limit")
    }

    // saturated fat
    if item.satFatG > 0.3 * targets.satFatG {
      let sev: Severity = has("heart_disease", "high_cholesterol") && item.satFatG > 0.5 * targets.satFatG ? .bad : .caution
      add(sev, "High saturated fat, \(n(item.satFatG)) g")
    }

    // diabetes
    if has("t1_diabetes", "t2_diabetes") {
      let net = item.netCarbsG
      if net > 45 { add(.bad, "High carbs, \(n(net)) g net carbs") }
      else if net > 30 { add(.caution, "High carbs, \(n(net)) g net carbs") }
      if item.sugarG > 25 { add(.bad, "High sugar, \(n(item.sugarG)) g") }
      else if item.sugarG > 15 { add(.caution, "High sugar, \(n(item.sugarG)) g") }
    }

    // ckd protein
    if has("ckd") && item.proteinG > 30 {
      add(.caution, "High protein for a kidney diet, \(n(item.proteinG)) g")
    }

    // calories
    let total = consumed.kcal + item.kcal
    if total > dailyGoalKcal {
      let sev: Severity = has("weight_loss") && total > dailyGoalKcal * 1.1 ? .bad : .caution
      add(sev, "Puts you \(n(total - dailyGoalKcal)) kcal over today's goal")
    }

    // keyword flags
    for id in idList {
      guard let flag = ConditionCatalog.condition(id: id).flag, flag.matches(name) else { continue }
      switch flag {
      case .gluten: add(.bad, "May contain gluten")
      case .pregnancyAvoid: add(.bad, "Not advised during pregnancy")
      case .highFodmap: add(.caution, "High-FODMAP ingredient")
      }
    }

    // positives
    if has("bodybuilding", "endurance") && item.kcal > 0 && item.proteinG * 100 / item.kcal >= 10 {
      add(.good, "Great protein source")
    }
    if has("endurance") && item.kcal > 0 && item.carbsG * 4 / item.kcal >= 0.5 {
      add(.good, "Good carb fuel")
    }
    if item.fiberG >= 5 { add(.good, "Good source of fiber") }

    // stable sort by severity (index tiebreak), cap at 2
    let sorted = out.enumerated().sorted { a, b in
      a.element.severity != b.element.severity ? a.element.severity < b.element.severity : a.offset < b.offset
    }
    let level: VerdictLevel = out.contains { $0.severity == .bad } ? .notRecommended
      : out.contains { $0.severity == .caution } ? .moderation : .goodFit
    return Verdict(level: level, reasons: sorted.prefix(2).map { $0.element })
  }
}
