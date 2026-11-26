import XCTest
@testable import NutraCore

final class SymptomsTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_799_971_200)
  private func at(day: Int, hour: Double) -> Date { start.addingTimeInterval(Double(day) * 86_400 + hour * 3600) }

  func testSeverityTitles() {
    XCTAssertEqual(SymptomSeverity.title(1), "Mild")
    XCTAssertEqual(SymptomSeverity.title(3), "Mild")
    XCTAssertEqual(SymptomSeverity.title(4), "Moderate")
    XCTAssertEqual(SymptomSeverity.title(7), "Moderate")
    XCTAssertEqual(SymptomSeverity.title(8), "Severe")
    XCTAssertEqual(SymptomSeverity.title(10), "Severe")
  }

  func testRawValuesMatchTheDatabase() {
    XCTAssertEqual(Symptom.allCases.map(\.rawValue), [
      "abdominal_pain", "bloating", "gas", "diarrhea", "constipation", "urgency", "nausea", "heartburn",
      "trouble_swallowing", "food_stuck", "fatigue", "blood_in_stool",
    ])
    XCTAssertEqual(Symptom.allCases.filter(\.isRedFlag), [.foodStuck, .bloodInStool])
    XCTAssertEqual(BristolScale.range.map(BristolScale.title).count, 7)
  }

  /// Yogurt every third day, always followed by bloating three hours later; other meals daily.
  func testFindsTheFoodFollowedBySymptoms() {
    var meals: [(name: String, time: Date)] = []
    var symptoms: [SymptomEntry] = []
    for day in 0..<21 {
      meals.append((name: "Oatmeal", time: at(day: day, hour: 8)))
      meals.append((name: "Chicken and rice", time: at(day: day, hour: 12.5)))
      if day % 3 == 0 {
        meals.append((name: day == 0 ? "Greek yogurt " : "greek yogurt", time: at(day: day, hour: 15.5)))
        symptoms.append(SymptomEntry(time: at(day: day, hour: 18), symptoms: [.bloating, .gas], severity: 6))
      }
    }
    let result = SymptomTriggers.analyze(meals: meals, symptoms: symptoms, asOf: at(day: 22, hour: 0))
    // Lunch is also within 6 hours of those entries, but on only 7 of its 21 days: not much more
    // often than the other meals.
    XCTAssertEqual(result.candidates.map(\.name), ["Greek yogurt"])
    XCTAssertEqual(result.candidates.first?.eaten, 7)
    XCTAssertEqual(result.candidates.first?.followed, 7)
    XCTAssertEqual(result.candidates.first?.otherRate ?? 0, 7.0 / 42.0, accuracy: 0.0001)
    XCTAssertEqual(result.baseline, 14.0 / 49.0, accuracy: 0.0001)
  }

  func testIgnoresMildEntriesRareFoodsAndRecentMeals() {
    let meals: [(name: String, time: Date)] = (0..<6).map { (name: "Curry", time: at(day: $0, hour: 19)) }
      + [(name: "Pizza", time: at(day: 1, hour: 12)), (name: "Pizza", time: at(day: 2, hour: 12))]
    let mild = (0..<6).map { SymptomEntry(time: at(day: $0, hour: 21), symptoms: [.gas], severity: 2) }
    XCTAssertTrue(SymptomTriggers.analyze(meals: meals, symptoms: mild, asOf: at(day: 9, hour: 0)).candidates.isEmpty)

    let pizzaOnly = [1, 2].map { SymptomEntry(time: at(day: $0, hour: 14), symptoms: [.abdominalPain], severity: 6) }
    XCTAssertTrue(SymptomTriggers.analyze(meals: meals, symptoms: pizzaOnly, asOf: at(day: 9, hour: 0)).candidates.isEmpty,
                  "two meals are too few to call a pattern")

    let curry = (0..<6).map { SymptomEntry(time: at(day: $0, hour: 21), symptoms: [.diarrhea], severity: 5) }
    XCTAssertEqual(SymptomTriggers.analyze(meals: meals, symptoms: curry, asOf: at(day: 9, hour: 0)).candidates.first?.followed, 6)
    // Curry is most of the meals; it's compared with the others (pizza), not with itself.
    XCTAssertEqual(SymptomTriggers.analyze(meals: meals, symptoms: curry, asOf: at(day: 9, hour: 0)).candidates.first?.otherRate, 0)
    // At 2 am on day 3 only the curries on days 0–2 are old enough to count.
    XCTAssertEqual(SymptomTriggers.analyze(meals: meals, symptoms: curry, asOf: at(day: 3, hour: 2)).candidates.first?.eaten, 3)
  }

  func testSymptomsBeforeOrLongAfterAMealDontCount() {
    let meals: [(name: String, time: Date)] = (0..<5).map { (name: "Beans", time: at(day: $0, hour: 12)) }
    let before = (0..<5).map { SymptomEntry(time: at(day: $0, hour: 11), symptoms: [.gas], severity: 5) }
    let late = (0..<5).map { SymptomEntry(time: at(day: $0, hour: 18.5), symptoms: [.gas], severity: 5) }
    XCTAssertTrue(SymptomTriggers.analyze(meals: meals, symptoms: before + late, asOf: at(day: 9, hour: 0)).candidates.isEmpty)
  }

  func testFlags() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let entries = [
      SymptomEntry(time: at(day: 0, hour: 9), symptoms: [.diarrhea, .bloodInStool], severity: 6),
      SymptomEntry(time: at(day: 0, hour: 20), symptoms: [.abdominalPain], severity: 9),
      SymptomEntry(time: at(day: 2, hour: 9), symptoms: [.foodStuck], severity: 4),
      SymptomEntry(time: at(day: 3, hour: 9), symptoms: [.bloating], severity: 3),
      SymptomEntry(time: at(day: 5, hour: 9), symptoms: [.bloodInStool], severity: 5),
    ]
    XCTAssertEqual(SymptomFlags.flags(entries: entries, days: 7, calendar: calendar), [
      "Blood in stool reported 2 times",
      "Food stuck when swallowing once",
      "Severe symptoms (8+ of 10) once",
      "Symptoms on 4 of the last 7 days",
    ])
    XCTAssertEqual(SymptomFlags.flags(entries: Array(entries[3...3]), days: 7, calendar: calendar), [])
  }
}
