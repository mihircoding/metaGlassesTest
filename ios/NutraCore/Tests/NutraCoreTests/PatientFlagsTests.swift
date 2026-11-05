import XCTest
@testable import NutraCore

final class PatientFlagsTests: XCTestCase {
  func testFlags() {
    let t = Targets(kcal: 2000, proteinG: 100, carbsG: 250, fatG: 67, satFatG: 20, sodiumMg: 1500, fiberG: 28)
    let days = [Nutrients(kcal: 1900, satFatG: 10, sodiumMg: 1600), Nutrients(kcal: 2300, satFatG: 25, sodiumMg: 1400),
                Nutrients(kcal: 2000, sodiumMg: 1700)]
    XCTAssertEqual(PatientFlags.flags(days: days, targets: t, dailyGoalKcal: 2000),
                   ["Sodium over limit 2 of last 3 days", "Saturated fat over limit 1 of last 3 days", "Calories over goal 1 of last 3 days"])
    XCTAssertEqual(PatientFlags.flags(days: [], targets: t, dailyGoalKcal: 2000), [])
  }
}
