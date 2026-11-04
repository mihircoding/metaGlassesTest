import XCTest
@testable import NutraCore

final class ConditionCatalogTests: XCTestCase {
  func testTableValues() {
    XCTAssertEqual(ConditionCatalog.all.map(\.id), ["general","t2_diabetes","t1_diabetes","hypertension","heart_disease",
      "high_cholesterol","ckd","liver","celiac","weight_loss","hypothyroid","ibs","bodybuilding","endurance","pregnancy"])
    let h = ConditionCatalog.condition(id: "hypertension")
    XCTAssertEqual([h.proteinPct, h.carbsPct, h.fatPct, h.sodiumMg, h.satFatPctMax, h.fiberG], [18, 55, 27, 1500, 6, 30])
    let ckd = ConditionCatalog.condition(id: "ckd")
    XCTAssertEqual([ckd.proteinPct, ckd.sodiumMg], [12, 2000])
    XCTAssertEqual(ConditionCatalog.condition(id: "nope").id, "general")
  }
  func testEveryConditionHasUsablePlanAndGuidance() {
    for c in ConditionCatalog.all {
      XCTAssertEqual(c.proteinPct + c.carbsPct + c.fatPct, 100, c.id)
      XCTAssertEqual(Set(c.samplePlan.map(\.meal)), Set(Meal.allCases), c.id)
      let day = c.samplePlan.flatMap(\.items).map(\.nutrients).sum()
      XCTAssertTrue((1400...3400).contains(day.kcal), "\(c.id) kcal \(day.kcal)")
      XCTAssertLessThanOrEqual(day.sodiumMg, c.sodiumMg, c.id)
      XCTAssertFalse(c.recommend.isEmpty || c.avoid.isEmpty || c.summary.isEmpty, c.id)
    }
  }
  func testKeywordFlags() {
    XCTAssertTrue(KeywordFlag.gluten.matches("Whole Wheat Bread"))
    XCTAssertFalse(KeywordFlag.gluten.matches("Brown rice"))
    XCTAssertTrue(KeywordFlag.pregnancyAvoid.matches("Salmon sashimi"))
    XCTAssertTrue(KeywordFlag.highFodmap.matches("garlic naan"))
    XCTAssertEqual(ConditionCatalog.condition(id: "celiac").flag, .gluten)
  }
  func testPlanItemFlatJSON() throws {
    let item = try JSONDecoder().decode(PlanItem.self, from: #"{"name":"Oats","serving_desc":"1 cup","serving_grams":80,"kcal":300,"protein_g":10,"carbs_g":54,"fat_g":5,"sat_fat_g":1,"sodium_mg":5,"fiber_g":8,"sugar_g":1}"#.data(using: .utf8)!)
    XCTAssertEqual(item.nutrients.fiberG, 8)
    let json = String(data: try JSONEncoder().encode(item), encoding: .utf8)!
    XCTAssertTrue(json.contains("\"fiber_g\":8") && !json.contains("nutrients"))
  }
}
