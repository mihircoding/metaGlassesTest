import XCTest
@testable import NutraCore

final class DayStatusTests: XCTestCase {
  func testClassify() {
    XCTAssertEqual(DayStatus.classify(kcal: nil, goal: 2000), .noData)
    XCTAssertEqual(DayStatus.classify(kcal: 0, goal: 2000), .noData)
    XCTAssertEqual(DayStatus.classify(kcal: 1799, goal: 2000), .under)
    XCTAssertEqual(DayStatus.classify(kcal: 1800, goal: 2000), .near)
    XCTAssertEqual(DayStatus.classify(kcal: 2200, goal: 2000), .near)
    XCTAssertEqual(DayStatus.classify(kcal: 2201, goal: 2000), .over)
  }
}
