import XCTest
@testable import NutraCore

final class VoiceTests: XCTestCase {
func testParse() {
  let cases: [(String, VoiceCommand)] = [("Hey, scan this", .scan), ("What’s this?", .scan), ("what am I eating", .scan),
    ("add it to dinner", .add(.dinner)), ("log it", .add(nil)), ("yeah", .add(nil)), ("no thanks", .skip), ("cancel", .skip),
    ("I know that", .none), ("how am I doing?", .status), ("calories left", .status), ("stop glasses mode", .exit), ("", .none)]
  for (s, c) in cases { XCTAssertEqual(VoiceCommand.parse(s), c, s) }
}
func testFlow() {
  XCTAssertTrue(VoiceFlow.next(.idle, .scan) == (.analyzing, [.captureAndAnalyze]))
  XCTAssertTrue(VoiceFlow.next(.awaitingConfirm, .scan) == (.analyzing, [.discard, .captureAndAnalyze]))
  XCTAssertTrue(VoiceFlow.next(.analyzing, .add(nil)) == (.analyzing, []))
  XCTAssertTrue(VoiceFlow.next(.awaitingConfirm, .add(.lunch)) == (.idle, [.log(.lunch)]))
  XCTAssertTrue(VoiceFlow.next(.idle, .add(nil)) == (.idle, [.speak(SpokenText.nothingPending)]))
  XCTAssertTrue(VoiceFlow.next(.awaitingConfirm, .skip) == (.idle, [.discard, .speak(SpokenText.skipped)]))
  XCTAssertTrue(VoiceFlow.next(.idle, .skip) == (.idle, []))
  XCTAssertTrue(VoiceFlow.next(.idle, .status) == (.idle, [.speakStatus]))
  XCTAssertTrue(VoiceFlow.next(.analyzing, .status) == (.analyzing, []))
  XCTAssertTrue(VoiceFlow.next(.awaitingConfirm, .exit) == (.idle, [.discard, .stop]))
  XCTAssertTrue(VoiceFlow.next(.idle, .none) == (.idle, []))
}
func testSpokenText() {
  let v = Verdict(level: .notRecommended, reasons: [VerdictReason(severity: .bad, text: "High sodium, 1100 mg, 73% of your daily limit")])
  XCTAssertEqual(SpokenText.scanResult(itemNames: ["Chicken Caesar salad"], total: Nutrients(kcal: 470.4, proteinG: 33.6), lowConfidence: false, verdict: v, conditionName: "Hypertension (DASH)"),
    "Chicken Caesar salad, about 470 calories and 34 grams of protein. Not recommended for your Hypertension plan: high sodium, 1100 mg, 73% of your daily limit. Say add it or skip.")
  XCTAssertEqual(SpokenText.scanResult(itemNames: ["Rice", "Beans"], total: Nutrients(kcal: 400, proteinG: 15), lowConfidence: true, verdict: Verdict(level: .goodFit, reasons: []), conditionName: nil),
    "I think this is 2 items, about 400 calories and 15 grams of protein. Good fit. Say add it or skip.")
  XCTAssertEqual(SpokenText.scanResult(itemNames: ["Rice", "Beans", "Salsa"], total: Nutrients(kcal: 520, proteinG: 18), lowConfidence: false, verdict: Verdict(level: .goodFit, reasons: []), conditionName: nil),
    "3 items, about 520 calories and 18 grams of protein. Good fit. Say add it or skip.")
  XCTAssertEqual(SpokenText.added(consumedKcal: 1240, goalKcal: 2000), "Added. 1240 of 2000 calories today.")
  XCTAssertEqual(SpokenText.status(consumedKcal: 1030, goalKcal: 2000, closestLimit: ("Sodium", 85)), "You have 970 calories left today. Sodium is at 85% of your limit.")
  XCTAssertEqual(SpokenText.status(consumedKcal: 2120, goalKcal: 2000, closestLimit: nil), "You're 120 calories over today's goal.")
}
}
