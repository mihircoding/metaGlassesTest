import XCTest
@testable import NutraCore

final class VerdictTests: XCTestCase {
  let T = Targets(kcal: 2000, proteinG: 100, carbsG: 250, fatG: 67, satFatG: 20, sodiumMg: 2000, fiberG: 28)

  func eval(_ item: Nutrients, _ ids: [String], name: String = "Food") -> Verdict {
    HealthVerdict.evaluate(name: name, item: item, targets: T, dailyGoalKcal: 2000, consumed: .zero, conditionIds: ids)
  }
  func evalWith(consumed: Double, kcal: Double, _ ids: [String]) -> Verdict {
    HealthVerdict.evaluate(name: "Food", item: Nutrients(kcal: kcal), targets: T, dailyGoalKcal: 2000,
                           consumed: Nutrients(kcal: consumed), conditionIds: ids)
  }

  func testCaesarForHypertensiveDiabetic() {
    var t = T; t.sodiumMg = 1500; t.satFatG = 15
    let v = HealthVerdict.evaluate(name: "Chicken Caesar salad",
      item: Nutrients(kcal: 470, proteinG: 34, carbsG: 20, fatG: 30, satFatG: 8, sodiumMg: 1100, fiberG: 4, sugarG: 4),
      targets: t, dailyGoalKcal: 2210, consumed: Nutrients(kcal: 1500, sodiumMg: 900), conditionIds: ["t2_diabetes", "hypertension"])
    XCTAssertEqual(v.level, .notRecommended)
    XCTAssertEqual(v.reasons.map(\.text), ["High sodium, 1100 mg, 73% of your daily limit", "Puts you over today's sodium limit"])
  }
  func testGeneralSodiumIsCaution() {
    let v = HealthVerdict.evaluate(name: "Soup", item: Nutrients(kcal: 150, sodiumMg: 900), targets: T, dailyGoalKcal: 2000, consumed: .zero, conditionIds: [])
    XCTAssertEqual(v, Verdict(level: .moderation, reasons: [VerdictReason(severity: .caution, text: "High sodium, 900 mg, 45% of your daily limit")]))
  }
  func testHeartSatFatBad() {
    XCTAssertEqual(eval(Nutrients(kcal: 300, satFatG: 11), ["heart_disease"]),
                   Verdict(level: .notRecommended, reasons: [VerdictReason(severity: .bad, text: "High saturated fat, 11 g")]))
  }
  func testDiabetesCarbsAndSugar() {
    XCTAssertEqual(eval(Nutrients(kcal: 300, carbsG: 60, fiberG: 5), ["t2_diabetes"]).reasons.first, VerdictReason(severity: .bad, text: "High carbs, 55 g net carbs"))
    XCTAssertEqual(eval(Nutrients(kcal: 300, carbsG: 40, fiberG: 5), ["t2_diabetes"]).level, .moderation)
    XCTAssertEqual(eval(Nutrients(kcal: 100, sugarG: 20), ["t1_diabetes"]).reasons.first?.severity, .caution)
    XCTAssertEqual(eval(Nutrients(kcal: 100, sugarG: 30), ["t1_diabetes"]).reasons.first?.severity, .bad)
  }
  func testKidneyProtein() { XCTAssertEqual(eval(Nutrients(kcal: 300, proteinG: 35), ["ckd"]).reasons.first?.text, "High protein for a kidney diet, 35 g") }
  func testCalories() {
    XCTAssertEqual(evalWith(consumed: 1800, kcal: 300, ["general"]).reasons.first, VerdictReason(severity: .caution, text: "Puts you 100 kcal over today's goal"))
    XCTAssertEqual(evalWith(consumed: 1800, kcal: 300, ["weight_loss"]).level, .moderation)
    XCTAssertEqual(evalWith(consumed: 2000, kcal: 300, ["weight_loss"]).level, .notRecommended)
  }
  func testKeywords() {
    XCTAssertEqual(eval(Nutrients(kcal: 80), ["celiac"], name: "Whole wheat bread").reasons.first?.text, "May contain gluten")
    XCTAssertEqual(eval(Nutrients(kcal: 80), ["pregnancy"], name: "Salmon sashimi").level, .notRecommended)
    XCTAssertEqual(eval(Nutrients(kcal: 80), ["ibs"], name: "Garlic bread").level, .moderation)
  }
  func testPositives() {
    XCTAssertEqual(eval(Nutrients(kcal: 248, proteinG: 46.5, fatG: 5.4, satFatG: 1.5, sodiumMg: 111), ["bodybuilding"]),
                   Verdict(level: .goodFit, reasons: [VerdictReason(severity: .good, text: "Great protein source")]))
    XCTAssertEqual(eval(Nutrients(kcal: 200, carbsG: 30), ["endurance"]).reasons.first?.text, "Good carb fuel")
    XCTAssertEqual(eval(Nutrients(kcal: 100, fiberG: 6), []).reasons.first?.text, "Good source of fiber")
    XCTAssertEqual(eval(Nutrients(kcal: 100), []), Verdict(level: .goodFit, reasons: []))
  }
  func testOrderingAndCap() {
    let v = eval(Nutrients(kcal: 300, carbsG: 60, fiberG: 6, sodiumMg: 900), ["t2_diabetes"])
    XCTAssertEqual(v.reasons.map(\.severity), [.bad, .caution])   // fiber's "good" is cut by the cap
  }
}
