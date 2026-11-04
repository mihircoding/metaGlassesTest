import XCTest
@testable import NutraCore

final class TargetCalculatorTests: XCTestCase {
  let now = ISO8601DateFormatter().date(from: "2026-11-04T12:00:00Z")!
  func d(_ s: String) -> Date { ISO8601DateFormatter().date(from: s + "T12:00:00Z")! }
  lazy var man = BodyStats(sex: .male, birthDate: d("1996-01-15"), heightCm: 180, weightKg: 80, activity: .moderate)

  func testBMR() { XCTAssertEqual(TargetCalculator.bmr(man, now: now), 1780) }
  func testGeneralMaintenance() {
    XCTAssertEqual(TargetCalculator.targets(stats: man, conditionIds: [], weeklyRateKg: 0, now: now),
                   Targets(kcal: 2760, proteinG: 138, carbsG: 345, fatG: 92, satFatG: 31, sodiumMg: 2300, fiberG: 28))
  }
  func testDiabetesPlusHypertensionLosing() {
    XCTAssertEqual(TargetCalculator.targets(stats: man, conditionIds: ["t2_diabetes", "hypertension"], weeklyRateKg: -0.5, now: now),
                   Targets(kcal: 2210, proteinG: 138, carbsG: 221, fatG: 86, satFatG: 15, sodiumMg: 1500, fiberG: 30))
  }
  func testFemaleFloor() {
    let s = BodyStats(sex: .female, birthDate: d("1966-06-01"), heightCm: 155, weightKg: 50, activity: .sedentary)
    XCTAssertEqual(TargetCalculator.targets(stats: s, conditionIds: [], weeklyRateKg: -1, now: now).kcal, 1200)
  }
  func testPregnancyIgnoresLossAndAdds300() {
    let s = BodyStats(sex: .female, birthDate: d("1998-03-10"), heightCm: 165, weightKg: 60, activity: .light)
    XCTAssertEqual(TargetCalculator.targets(stats: s, conditionIds: ["pregnancy"], weeklyRateKg: -0.5, now: now).kcal, 2130)
  }
  func testMissingStats() {
    let s = BodyStats(sex: .unspecified, birthDate: nil, heightCm: nil, weightKg: 70, activity: .light)
    XCTAssertEqual(TargetCalculator.targets(stats: s, conditionIds: [], weeklyRateKg: -1, now: now).kcal, 2000)
  }
  func testTargetsJSONKeys() throws {
    let json = String(data: try JSONEncoder().encode(Targets.defaults), encoding: .utf8)!
    XCTAssertTrue(json.contains("\"kcal_target\":2000"))
  }
}
