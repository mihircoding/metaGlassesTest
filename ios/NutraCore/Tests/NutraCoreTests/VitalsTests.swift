import XCTest
@testable import NutraCore

final class VitalsTests: XCTestCase {
  func testBloodPressureCategoriesUseTheHigherNumber() {
    XCTAssertEqual(BloodPressureCategory.classify(systolic: 118, diastolic: 76), .normal)
    XCTAssertEqual(BloodPressureCategory.classify(systolic: 124, diastolic: 78), .elevated)
    XCTAssertEqual(BloodPressureCategory.classify(systolic: 118, diastolic: 82), .stage1)
    XCTAssertEqual(BloodPressureCategory.classify(systolic: 134, diastolic: 70), .stage1)
    XCTAssertEqual(BloodPressureCategory.classify(systolic: 128, diastolic: 92), .stage2)
    XCTAssertEqual(BloodPressureCategory.classify(systolic: 180, diastolic: 110), .stage2)
    XCTAssertEqual(BloodPressureCategory.classify(systolic: 181, diastolic: 100), .crisis)
    XCTAssertEqual(BloodPressureCategory.classify(systolic: 150, diastolic: 121), .crisis)
  }

  func testGlucoseTargetsDependOnContext() {
    XCTAssertEqual(GlucoseCategory.classify(mgDl: 50, context: .fasting), .veryLow)
    XCTAssertEqual(GlucoseCategory.classify(mgDl: 64, context: .bedtime), .low)
    XCTAssertEqual(GlucoseCategory.classify(mgDl: 120, context: .fasting), .inRange)
    XCTAssertEqual(GlucoseCategory.classify(mgDl: 150, context: .fasting), .high)
    XCTAssertEqual(GlucoseCategory.classify(mgDl: 150, context: .afterMeal), .inRange)
    XCTAssertEqual(GlucoseCategory.classify(mgDl: 200, context: .afterMeal), .high)
    XCTAssertEqual(GlucoseCategory.classify(mgDl: 260, context: .afterMeal), .veryHigh)
    XCTAssertEqual(GlucoseContext(rawValue: "after_meal"), .afterMeal)
  }

  func testFlagsCountTheReadingsThatMatter() {
    let flags = VitalFlags.flags(
      bloodPressure: [(150, 95), (122, 78), (185, 100)],
      glucose: [(64, .bedtime), (110, .fasting), (270, .afterMeal), (52, .fasting)],
      fluidDays: [1400, 1700, 1800], fluidLimitMl: 1500)
    XCTAssertEqual(flags, [
      "Blood pressure over 180/120 once",
      "Blood pressure 140/90 or higher on 1 of 3 readings",
      "Low glucose (under 70) 2 times",
      "Glucose 250 or higher once",
      "Fluids over limit 2 of last 3 days",
    ])
    XCTAssertEqual(VitalFlags.flags(bloodPressure: [(118, 76)], glucose: [(100, .fasting)],
                                    fluidDays: [3000], fluidLimitMl: nil), [])
  }
}
