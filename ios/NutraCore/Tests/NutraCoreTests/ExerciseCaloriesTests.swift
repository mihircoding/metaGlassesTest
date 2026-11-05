import XCTest
@testable import NutraCore

final class ExerciseCaloriesTests: XCTestCase {
  func testKcal() {
    XCTAssertEqual(ExerciseCalories.kcal(kind: .running, minutes: 30, weightKg: 70), 343)
    XCTAssertEqual(ExerciseCalories.kcal(kind: .yoga, minutes: 60, weightKg: 80), 200)
    XCTAssertEqual(ExerciseCalories.kcal(kind: .walking, minutes: 45, weightKg: nil), 184)
    XCTAssertEqual(ExerciseKind.allCases.map(\.met), [9.8, 3.5, 7.5, 6.0, 5.0, 8.0, 2.5, 4.0])
  }
  func testUnknownKindDecodesAsOther() throws {
    let kinds = try JSONDecoder().decode([ExerciseKind].self, from: Data(#"["running","rowing"]"#.utf8))
    XCTAssertEqual(kinds, [.running, .other])
  }
}
