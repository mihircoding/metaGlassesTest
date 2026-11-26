import XCTest
@testable import NutraCore

final class LoggingStreakTests: XCTestCase {
  let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
  /// Noon on 2026-11-`day` (UTC).
  func nov(_ day: Int, hour: Int = 12) -> Date { utc.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))! }

  func testCountsBackFromToday() {
    let logged = [nov(20), nov(21), nov(22, hour: 8), nov(22, hour: 19), nov(23), nov(24)]
    XCTAssertEqual(LoggingStreak.days(logged: logged, today: nov(24), calendar: utc), 5)
  }

  func testEmptyTodayStillCountsThroughYesterday() {
    XCTAssertEqual(LoggingStreak.days(logged: [nov(22), nov(23)], today: nov(24, hour: 7), calendar: utc), 2)
  }

  func testGapEndsTheStreak() {
    XCTAssertEqual(LoggingStreak.days(logged: [nov(18), nov(19), nov(21), nov(22)], today: nov(22), calendar: utc), 2)
  }

  func testNothingRecentIsZero() {
    XCTAssertEqual(LoggingStreak.days(logged: [nov(10)], today: nov(24), calendar: utc), 0)
    XCTAssertEqual(LoggingStreak.days(logged: [], today: nov(24), calendar: utc), 0)
  }

  func testCrossesMonths() {
    let oct31 = utc.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12))!
    XCTAssertEqual(LoggingStreak.days(logged: [oct31, nov(1), nov(2)], today: nov(2), calendar: utc), 3)
  }
}
