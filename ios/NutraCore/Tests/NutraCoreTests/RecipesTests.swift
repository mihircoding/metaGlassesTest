import XCTest
@testable import NutraCore

final class RecipesTests: XCTestCase {
  func testDigestiveConditionsHaveLinkedRecipes() {
    for id in ["ibd", "ibs", "celiac", "eoe"] {
      let recipes = ConditionCatalog.recipes(for: id)
      XCTAssertGreaterThanOrEqual(recipes.count, 4, id)
      XCTAssertNotNil(ConditionCatalog.recipeNote(for: id), id)
      XCTAssertEqual(Set(recipes.map(\.url)).count, recipes.count, "\(id) lists a recipe twice")
      for r in recipes {
        XCTAssertEqual(r.url.host, "www.ginutritionfoundation.org", r.title)
        XCTAssertTrue(r.url.path.hasPrefix("/recipes/"), r.title)
        XCTAssertFalse(r.summary.isEmpty || r.diets.isEmpty, r.title)
      }
    }
    XCTAssertTrue(ConditionCatalog.recipes(for: "hypertension").isEmpty)
  }

  func testRecipeNamesDontTripTheirConditionsOwnFlags() {
    // A recipe suggested for a condition shouldn't be flagged by that condition's keyword check.
    for id in ["ibs", "celiac", "eoe"] {
      guard let flag = ConditionCatalog.condition(id: id).flag else { continue }
      for r in ConditionCatalog.recipes(for: id) {
        XCTAssertFalse(flag.matches(r.title), "\(id): \(r.title)")
      }
    }
  }
}
