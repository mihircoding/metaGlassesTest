import Foundation

public struct PlanItem: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var name: String
  public var servingDesc: String
  public var servingGrams: Double?
  public var nutrients: Nutrients

  public init(id: UUID = UUID(), name: String, servingDesc: String, servingGrams: Double? = nil, nutrients: Nutrients) {
    self.id = id
    self.name = name
    self.servingDesc = servingDesc
    self.servingGrams = servingGrams
    self.nutrients = nutrients
  }

  enum CodingKeys: String, CodingKey {
    case id, name
    case servingDesc = "serving_desc"
    case servingGrams = "serving_grams"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    name = try c.decode(String.self, forKey: .name)
    servingDesc = try c.decode(String.self, forKey: .servingDesc)
    servingGrams = try c.decodeIfPresent(Double.self, forKey: .servingGrams)
    nutrients = try Nutrients(from: decoder)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(servingDesc, forKey: .servingDesc)
    try c.encodeIfPresent(servingGrams, forKey: .servingGrams)
    try nutrients.encode(to: encoder)
  }
}

public struct PlanMeal: Codable, Equatable, Sendable {
  public var meal: Meal
  public var items: [PlanItem]

  public init(meal: Meal, items: [PlanItem]) {
    self.meal = meal
    self.items = items
  }
}

/// One sample day per condition, built from a small low-sodium food library (USDA-style values).
/// Day totals (kcal / sodium mg): base 1582/458, diabetes 1742/522, dash 1467/341, ckd 1530/303,
/// liver 1555/530, celiac 1783/587, weight loss 1602/732, hypothyroid 1763/522, ibs 1800/391,
/// bodybuilding 2488/521, endurance 2341/428, pregnancy 1743/585.
enum SamplePlans {
  // ponytail: one shared plan reused where conditions' foods overlap; split per condition if dietitians want variety.
  private static func f(_ name: String, _ desc: String, _ g: Double, _ kcal: Double, _ p: Double, _ c: Double,
                        _ fat: Double, _ sat: Double, _ na: Double, _ fib: Double, _ sug: Double) -> PlanItem {
    PlanItem(name: name, servingDesc: desc, servingGrams: g,
             nutrients: Nutrients(kcal: kcal, proteinG: p, carbsG: c, fatG: fat, satFatG: sat,
                                  sodiumMg: na, fiberG: fib, sugarG: sug))
  }

  private static func x(_ n: Double, _ i: PlanItem) -> PlanItem {
    var r = i
    r.servingDesc = "\(Int(n)) x \(i.servingDesc)"
    r.servingGrams = i.servingGrams.map { $0 * n }
    r.nutrients = i.nutrients.scaled(by: n)
    return r
  }

  private static func day(_ b: [PlanItem], _ l: [PlanItem], _ d: [PlanItem], _ s: [PlanItem]) -> [PlanMeal] {
    [PlanMeal(meal: .breakfast, items: b), PlanMeal(meal: .lunch, items: l),
     PlanMeal(meal: .dinner, items: d), PlanMeal(meal: .snack, items: s)]
  }

  // name, serving, g, kcal, protein, carbs, fat, satFat, sodium, fiber, sugar
  private static let oats = f("Oatmeal, cooked", "1 cup", 234, 166, 6, 28, 3.6, 0.6, 9, 4, 1)
  private static let banana = f("Banana", "1 medium", 118, 105, 1.3, 27, 0.4, 0.1, 1, 3.1, 14)
  private static let eggs = f("Eggs, hard-boiled", "2 large", 100, 155, 13, 1.1, 11, 3.3, 124, 0, 1.1)
  private static let chicken = f("Chicken breast, grilled", "150 g", 150, 248, 46, 0, 5.4, 1.5, 111, 0, 0)
  private static let brownRice = f("Brown rice, cooked", "1 cup", 195, 216, 5, 45, 1.8, 0.4, 10, 3.5, 0.7)
  private static let whiteRice = f("White rice, cooked", "1 cup", 158, 205, 4.3, 45, 0.4, 0.1, 2, 0.6, 0.1)
  private static let broccoli = f("Broccoli, steamed", "1 cup", 156, 55, 3.7, 11, 0.6, 0.1, 64, 5.1, 2.2)
  private static let salmon = f("Salmon, baked", "150 g", 150, 312, 34, 0, 18, 3.8, 100, 0, 0)
  private static let yogurt = f("Greek yogurt, plain nonfat", "170 g", 170, 100, 17, 6, 0.7, 0.4, 60, 0, 6)
  private static let almonds = f("Almonds", "28 g", 28, 164, 6, 6, 14, 1.1, 0, 3.5, 1.2)
  private static let apple = f("Apple", "1 medium", 182, 95, 0.5, 25, 0.3, 0.1, 2, 4.4, 19)
  private static let oil = f("Olive oil", "1 tbsp", 14, 119, 0, 0, 13.5, 1.9, 0, 0, 0)
  private static let sweetPotato = f("Sweet potato, baked", "130 g", 130, 112, 2, 26, 0.1, 0, 72, 3.9, 5.4)
  private static let quinoa = f("Quinoa, cooked", "1 cup", 185, 222, 8, 39, 3.6, 0.4, 13, 5.2, 1.6)
  private static let lentils = f("Lentils, cooked", "1 cup", 198, 230, 18, 40, 0.8, 0.1, 4, 15.6, 3.6)
  private static let salad = f("Mixed greens salad", "2 cups", 85, 20, 1.5, 4, 0.2, 0, 30, 2, 1.5)
  private static let blueberries = f("Blueberries", "1 cup", 148, 84, 1.1, 21, 0.5, 0, 1, 3.6, 15)
  private static let eggWhites = f("Egg whites", "4 large", 132, 68, 14.4, 0.9, 0.2, 0, 220, 0, 0.9)
  private static let whey = f("Whey protein shake", "1 scoop", 30, 120, 24, 3, 1.5, 1, 50, 0, 2)
  private static let pasta = f("Spaghetti, cooked", "1 cup", 140, 220, 8, 43, 1.3, 0.2, 1, 2.5, 0.8)

  // kcal 1582, sodium 458
  static let base = day([oats, banana], [chicken, brownRice, salad], [salmon, sweetPotato, broccoli], [yogurt, blueberries, almonds])
  // kcal 1742, sodium 522
  static let diabetes = day([eggs, oats, blueberries], [chicken, quinoa, salad], [salmon, broccoli, brownRice], [yogurt, almonds])
  // kcal 1467, sodium 341
  static let dash = day([oats, banana, almonds], [lentils, salad, oil],
                        [salmon, sweetPotato, broccoli], [yogurt, blueberries])
  // kcal 1530, sodium 303
  static let ckd = day([oats, blueberries, apple], [whiteRice, broccoli, oil],
                       [x(2, pasta), eggWhites, oil], [apple, blueberries])
  // kcal 1555, sodium 530
  static let liver = day([eggs, oats], [chicken, brownRice, broccoli], [salmon, sweetPotato, salad], [oats, banana])
  // kcal 1783, sodium 587
  static let celiac = day([eggs, quinoa, blueberries], [chicken, brownRice, broccoli], [salmon, sweetPotato, salad],
                          [yogurt, almonds, apple])
  // kcal 1602, sodium 732
  static let weightLoss = day([eggWhites, oats, blueberries], [chicken, salad, quinoa], [salmon, broccoli, sweetPotato],
                              [yogurt, apple, whey])
  // kcal 1763, sodium 522
  static let hypothyroid = day([eggs, oats, banana], [chicken, brownRice, broccoli], [salmon, quinoa, salad], [yogurt, almonds])
  // kcal 1800, sodium 391
  static let ibs = day([eggs, oats, blueberries], [chicken, whiteRice, oil], [salmon, quinoa, salad], [banana, almonds])
  // kcal 2488, sodium 521
  static let bodybuilding = day([x(2, oats), eggs, banana], [chicken, x(2, brownRice), broccoli],
                                [salmon, x(2, pasta), salad], [whey, banana, almonds])
  // kcal 2341, sodium 428
  static let endurance = day([x(2, oats), banana, blueberries], [x(2, pasta), chicken, broccoli],
                             [x(2, whiteRice), salmon, broccoli], [banana, yogurt, apple])
  // kcal 1743, sodium 585 (everything fully cooked, pasteurized dairy)
  static let pregnancy = day([eggs, oats, blueberries], [chicken, quinoa, salad], [salmon, sweetPotato, broccoli],
                             [yogurt, banana, almonds])
}
