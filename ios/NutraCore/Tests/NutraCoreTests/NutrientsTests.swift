import XCTest
@testable import NutraCore

final class NutrientsTests: XCTestCase {
  func testAddScaleSum() {
    let a = Nutrients(kcal: 100, proteinG: 10, sodiumMg: 200)
    let b = Nutrients(kcal: 50, fiberG: 3)
    XCTAssertEqual((a + b).kcal, 150); XCTAssertEqual((a + b).fiberG, 3)
    XCTAssertEqual(a.scaled(by: 1.5), Nutrients(kcal: 150, proteinG: 15, sodiumMg: 300))
    XCTAssertEqual([a, b, a].sum().kcal, 250)
    XCTAssertEqual(Nutrients(carbsG: 10, fiberG: 12).netCarbsG, 0)
  }
  func testSnakeCaseJSON() throws {
    let json = String(data: try JSONEncoder().encode(Nutrients(satFatG: 2)), encoding: .utf8)!
    XCTAssertTrue(json.contains("\"sat_fat_g\":2"))
    let back = try JSONDecoder().decode(Nutrients.self, from: #"{"kcal":5,"protein_g":1,"carbs_g":0,"fat_g":0,"sat_fat_g":0,"sodium_mg":7,"fiber_g":0,"sugar_g":0}"#.data(using: .utf8)!)
    XCTAssertEqual(back.sodiumMg, 7)
  }
}
