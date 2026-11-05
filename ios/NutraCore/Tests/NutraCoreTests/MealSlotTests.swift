import XCTest
@testable import NutraCore

final class MealSlotTests: XCTestCase {
  let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
  func at(_ h: Int, _ m: Int) -> Date { utc.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: h, minute: m))! }
  func testBoundaries() {
    let cases: [(Int, Int, Meal)] = [(3,59,.snack),(4,0,.breakfast),(10,59,.breakfast),(11,0,.lunch),(14,59,.lunch),
                                     (15,0,.snack),(16,59,.snack),(17,0,.dinner),(21,29,.dinner),(21,30,.snack)]
    for (h, m, meal) in cases { XCTAssertEqual(MealSlot.meal(at: at(h, m), calendar: utc), meal, "\(h):\(m)") }
  }
  func testDayKeyUsesLocalZone() {
    var ny = Calendar(identifier: .gregorian); ny.timeZone = TimeZone(identifier: "America/New_York")!
    let lateEvening = ISO8601DateFormatter().date(from: "2026-11-04T03:30:00Z")!   // 22:30 on Nov 3 in New York
    XCTAssertEqual(DayKey.key(for: lateEvening, calendar: ny), "2026-11-03")
  }
}
