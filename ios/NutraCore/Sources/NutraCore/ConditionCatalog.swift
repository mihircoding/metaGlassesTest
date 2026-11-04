import Foundation

public enum KeywordFlag: Sendable {
  case gluten, highFodmap, pregnancyAvoid

  // ponytail: word-start keyword match — misses unnamed ingredients and fused compounds like "wholewheat".
  public var keywords: [String] {
    switch self {
    case .gluten:
      return ["bread", "pasta", "wheat", "flour", "bagel", "pizza", "cracker", "cake", "cookie", "beer",
              "barley", "rye", "couscous", "noodle", "tortilla"]
    case .highFodmap:
      return ["onion", "garlic", "beans", "lentil", "chickpea", "apple", "pear", "mango", "watermelon",
              "wheat", "milk", "ice cream", "honey"]
    case .pregnancyAvoid:
      return ["sushi", "sashimi", "raw", "unpasteurized", "deli", "salami", "pâté", "swordfish",
              "king mackerel", "shark", "tilefish"]
    }
  }

  public func matches(_ foodName: String) -> Bool {
    let n = foodName.lowercased()
    if self == .gluten && (n.contains("gluten-free") || n.contains("gluten free")) { return false }
    let words = n.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
    return keywords.contains { keyword in
      let kw = keyword.split(separator: " ")
      guard !kw.isEmpty, words.count >= kw.count else { return false }
      return (0...(words.count - kw.count)).contains { i in
        kw.indices.allSatisfy { j in words[i + j].hasPrefix(kw[j]) }
      }
    }
  }
}

public struct Condition: Identifiable, Sendable {
  public let id: String
  public let name: String
  public let icon: String
  public let proteinPct: Double
  public let carbsPct: Double
  public let fatPct: Double
  public let sodiumMg: Double
  public let satFatPctMax: Double
  public let fiberG: Double
  public let summary: String
  public let recommend: [String]
  public let avoid: [String]
  public let flag: KeywordFlag?
  public let samplePlan: [PlanMeal]

  public init(id: String, name: String, icon: String, proteinPct: Double, carbsPct: Double, fatPct: Double,
              sodiumMg: Double, satFatPctMax: Double, fiberG: Double, summary: String,
              recommend: [String], avoid: [String], flag: KeywordFlag? = nil, samplePlan: [PlanMeal]) {
    self.id = id
    self.name = name
    self.icon = icon
    self.proteinPct = proteinPct
    self.carbsPct = carbsPct
    self.fatPct = fatPct
    self.sodiumMg = sodiumMg
    self.satFatPctMax = satFatPctMax
    self.fiberG = fiberG
    self.summary = summary
    self.recommend = recommend
    self.avoid = avoid
    self.flag = flag
    self.samplePlan = samplePlan
  }
}

public enum ConditionCatalog {
  public static func condition(id: String) -> Condition {
    all.first { $0.id == id } ?? all[0]
  }

  private static let diabetesSummary = "Focus on low glycemic index foods. Monitor carbohydrate intake carefully - aim for 45-60 g per meal. Consistent meal timing is critical."
  private static let diabetesRecommend = [
    "Choose low glycemic index foods (GI < 55)",
    "Aim for 45-60 g carbohydrates per meal",
    "Include fiber-rich foods to slow glucose absorption",
    "Eat regular, consistent meals",
    "Choose lean proteins",
    "Include non-starchy vegetables freely",
    "Monitor blood sugar before and after meals",
  ]
  private static let diabetesAvoid = [
    "White bread, white rice, refined pasta",
    "Sugary beverages and fruit juices",
    "Candy, cake, and pastries",
    "High-sugar cereals",
    "Sweetened dairy products",
  ]
  private static let heartSummary = "DASH or Mediterranean diet approach. Strictly limit sodium and saturated fats. Increase potassium, omega-3 fatty acids, and fiber."
  private static let heartRecommend = [
    "Follow DASH or Mediterranean diet principles",
    "Increase omega-3 fatty acids (salmon, walnuts, flaxseed)",
    "Choose potassium-rich foods (bananas, sweet potatoes)",
    "Eat 7-9 servings of fruits and vegetables daily",
    "Choose whole grains over refined grains",
    "Include legumes 4 times per week",
    "Use olive oil instead of butter",
  ]
  private static let heartAvoid = [
    "Saturated fats (red meat, full-fat dairy)",
    "Trans fats (partially hydrogenated oils)",
    "High-sodium processed and canned foods",
    "Excessive alcohol",
    "Fried foods",
  ]

  public static let all: [Condition] = [
    Condition(
      id: "general", name: "No condition", icon: "checkmark.circle.fill",
      proteinPct: 20, carbsPct: 50, fatPct: 30, sodiumMg: 2300, satFatPctMax: 10, fiberG: 28,
      summary: "Follow a balanced diet with whole foods, lean proteins, complex carbohydrates, and healthy fats.",
      recommend: [
        "Eat a variety of colorful fruits and vegetables",
        "Choose whole grains over refined grains",
        "Limit processed foods and added sugars",
        "Stay hydrated with water",
        "Maintain regular meal times",
      ],
      avoid: ["Excessive processed foods", "Trans fats", "Added sugars in large quantities"],
      samplePlan: SamplePlans.base),
    Condition(
      id: "t2_diabetes", name: "Type 2 diabetes", icon: "drop.fill",
      proteinPct: 25, carbsPct: 40, fatPct: 35, sodiumMg: 2300, satFatPctMax: 10, fiberG: 30,
      summary: diabetesSummary, recommend: diabetesRecommend, avoid: diabetesAvoid,
      samplePlan: SamplePlans.diabetes),
    Condition(
      id: "t1_diabetes", name: "Type 1 diabetes", icon: "drop.fill",
      proteinPct: 20, carbsPct: 45, fatPct: 35, sodiumMg: 2300, satFatPctMax: 10, fiberG: 30,
      summary: diabetesSummary, recommend: diabetesRecommend, avoid: diabetesAvoid,
      samplePlan: SamplePlans.diabetes),
    Condition(
      id: "hypertension", name: "Hypertension (DASH)", icon: "heart.text.square",
      proteinPct: 18, carbsPct: 55, fatPct: 27, sodiumMg: 1500, satFatPctMax: 6, fiberG: 30,
      summary: "The DASH eating pattern lowers blood pressure: lots of vegetables, fruit, whole grains and legumes, lean protein, and very little salt.",
      recommend: [
        "Keep sodium under 1,500 mg per day",
        "Eat 4-5 servings each of vegetables and fruit daily",
        "Choose potassium-rich foods (bananas, sweet potatoes, beans)",
        "Pick whole grains and low-fat dairy",
        "Choose fish, poultry and legumes over red meat",
        "Cook with herbs and spices instead of salt",
      ],
      avoid: [
        "Canned soups, deli meats and other processed foods",
        "Salty snacks and fast food",
        "Soy sauce and salty condiments",
        "Excessive alcohol",
        "Sugary drinks",
      ],
      samplePlan: SamplePlans.dash),
    Condition(
      id: "heart_disease", name: "Heart disease", icon: "heart.fill",
      proteinPct: 20, carbsPct: 50, fatPct: 30, sodiumMg: 1500, satFatPctMax: 6, fiberG: 30,
      summary: heartSummary, recommend: heartRecommend, avoid: heartAvoid,
      samplePlan: SamplePlans.dash),
    Condition(
      id: "high_cholesterol", name: "High cholesterol", icon: "drop.triangle",
      proteinPct: 20, carbsPct: 50, fatPct: 30, sodiumMg: 2300, satFatPctMax: 6, fiberG: 30,
      summary: "Lower LDL cholesterol by cutting saturated fat, replacing it with unsaturated fats, and eating plenty of soluble fiber.",
      recommend: [
        "Eat soluble fiber daily (oats, beans, lentils, apples, barley)",
        "Use olive or canola oil instead of butter",
        "Eat fatty fish such as salmon twice a week",
        "Snack on a handful of nuts",
        "Fill half your plate with vegetables",
      ],
      avoid: [
        "Fatty red meat and processed meats",
        "Full-fat dairy and butter",
        "Trans fats (partially hydrogenated oils)",
        "Fried foods and commercial baked goods",
        "Coconut and palm oil in large amounts",
      ],
      samplePlan: SamplePlans.dash),
    Condition(
      id: "ckd", name: "Chronic kidney disease", icon: "cross.fill",
      proteinPct: 12, carbsPct: 58, fatPct: 30, sodiumMg: 2000, satFatPctMax: 10, fiberG: 25,
      summary: "Limit potassium, phosphorus, and sodium. Protein restriction depends on disease stage. Fluids may also be limited.",
      recommend: [
        "Follow your nephrologist's protein recommendations",
        "Limit potassium (avoid bananas, oranges, potatoes in large amounts)",
        "Limit phosphorus (limit dairy, nuts, whole grains)",
        "Keep sodium low and check labels",
        "Choose kidney-friendly fruits (apples, grapes, berries)",
        "Work with a renal dietitian for a personalized plan",
      ],
      avoid: [
        "Bananas, oranges, tomatoes, potatoes (high potassium)",
        "Dairy products in large amounts (high phosphorus)",
        "Nuts and seeds in large amounts",
        "Salt substitutes (often high in potassium)",
        "High-protein diets without medical guidance",
      ],
      samplePlan: SamplePlans.ckd),
    Condition(
      id: "liver", name: "Liver disease / cirrhosis", icon: "waveform.path.ecg",
      proteinPct: 20, carbsPct: 50, fatPct: 30, sodiumMg: 2000, satFatPctMax: 10, fiberG: 28,
      summary: "Adequate protein prevents muscle wasting. Sodium must be strictly limited. Small frequent meals prevent hypoglycemia. Avoid alcohol completely.",
      recommend: [
        "Eat 1.2-1.5 g protein per kg body weight",
        "Have 4-6 small meals per day",
        "Include a late evening snack (complex carbs) to prevent overnight hypoglycemia",
        "Ensure adequate zinc intake (meat, legumes, nuts)",
        "Choose lean proteins (chicken, fish, eggs, legumes)",
        "Monitor fluid intake if edema is present",
      ],
      avoid: [
        "ALL alcohol - strictly zero",
        "Raw or undercooked shellfish (infection risk)",
        "High-sodium processed foods, canned soups, soy sauce",
        "Large amounts of red meat",
        "High-fat fried foods",
      ],
      samplePlan: SamplePlans.liver),
    Condition(
      id: "celiac", name: "Celiac disease", icon: "leaf.fill",
      proteinPct: 20, carbsPct: 50, fatPct: 30, sodiumMg: 2300, satFatPctMax: 10, fiberG: 28,
      summary: "Strictly gluten-free. Even trace amounts cause intestinal damage. Focus on naturally gluten-free grains and whole foods.",
      recommend: [
        "Read all food labels carefully for gluten",
        "Choose naturally gluten-free grains: rice, quinoa, corn, potato",
        "Use certified gluten-free oats if desired",
        "Be aware of cross-contamination in kitchens",
        "Supplement iron, B12, folate, vitamin D if deficient",
        "Eat plenty of fruits, vegetables, and lean proteins",
      ],
      avoid: [
        "Wheat (bread, pasta, most baked goods)",
        "Barley and rye",
        "Beer and malt beverages",
        "Soy sauce (most contain wheat)",
        "Non-certified oats",
      ],
      flag: .gluten,
      samplePlan: SamplePlans.celiac),
    Condition(
      id: "weight_loss", name: "Obesity / weight loss", icon: "scalemass.fill",
      proteinPct: 30, carbsPct: 40, fatPct: 30, sodiumMg: 2300, satFatPctMax: 10, fiberG: 30,
      summary: "Create a moderate caloric deficit (500-750 kcal/day). Focus on high-volume, nutrient-dense, low-calorie foods. High protein helps preserve muscle mass.",
      recommend: [
        "Aim for a 500-750 kcal deficit per day",
        "Prioritize high-protein foods for satiety",
        "Fill half your plate with non-starchy vegetables",
        "Choose high-fiber foods that keep you full",
        "Drink water before meals",
        "Eat slowly and mindfully",
      ],
      avoid: [
        "Sugary beverages (soda, juice, sports drinks)",
        "Ultra-processed snack foods",
        "Fast food high in calories",
        "Mindless snacking",
        "Late-night eating",
      ],
      samplePlan: SamplePlans.weightLoss),
    Condition(
      id: "hypothyroid", name: "Hypothyroidism", icon: "thermometer.medium",
      proteinPct: 25, carbsPct: 45, fatPct: 30, sodiumMg: 2300, satFatPctMax: 10, fiberG: 30,
      summary: "Support thyroid function with iodine and selenium. Take levothyroxine away from foods that interfere with absorption.",
      recommend: [
        "Ensure adequate iodine intake (seafood, dairy, iodized salt)",
        "Include selenium-rich foods (Brazil nuts, tuna, eggs)",
        "Take thyroid medication 30-60 minutes before eating",
        "Avoid soy within 4 hours of medication",
        "Choose anti-inflammatory foods",
        "Maintain a healthy weight to support thyroid function",
      ],
      avoid: [
        "Large amounts of raw goitrogens (kale, cabbage) near medication time",
        "Soy products close to thyroid medication time",
        "Excess processed foods",
        "Gluten (if you also have Hashimoto's - check with your doctor)",
      ],
      samplePlan: SamplePlans.hypothyroid),
    Condition(
      id: "ibs", name: "IBS (low-FODMAP)", icon: "stomach",
      proteinPct: 20, carbsPct: 50, fatPct: 30, sodiumMg: 2300, satFatPctMax: 10, fiberG: 25,
      summary: "Follow a low-FODMAP diet to reduce fermentable sugars that trigger symptoms. Work with a dietitian to reintroduce foods systematically.",
      recommend: [
        "Follow a low-FODMAP diet for 4-8 weeks, then reintroduce foods",
        "Keep a food and symptom diary",
        "Eat slowly and chew food well",
        "Avoid very large meals",
        "Manage stress (a major IBS trigger)",
        "Soluble fiber may help (oats, bananas, carrots)",
      ],
      avoid: [
        "High-FODMAP foods: garlic, onion, wheat, beans",
        "Lactose (milk, soft cheeses) if sensitive",
        "Excess fructose (apples, pears, mango)",
        "Carbonated beverages",
        "Artificial sweeteners (sorbitol, mannitol)",
      ],
      flag: .highFodmap,
      samplePlan: SamplePlans.ibs),
    Condition(
      id: "bodybuilding", name: "Bodybuilding / weight training", icon: "figure.strengthtraining.traditional",
      proteinPct: 30, carbsPct: 45, fatPct: 25, sodiumMg: 2300, satFatPctMax: 10, fiberG: 30,
      summary: "High protein intake (1.6-2.2 g/kg body weight) is essential. Sufficient carbohydrates fuel training. Aim for a 300-500 kcal surplus when building.",
      recommend: [
        "Consume 1.6-2.2 g protein per kg of body weight daily",
        "Eat protein within 30-60 minutes after a workout",
        "Include complex carbs for sustained energy",
        "Time carbohydrates around workouts",
        "Stay well hydrated during training",
        "Spread protein over 4-6 meals per day",
      ],
      avoid: [
        "Highly processed junk foods",
        "Alcohol (impairs muscle protein synthesis)",
        "Training on an empty stomach (reduces performance)",
      ],
      samplePlan: SamplePlans.bodybuilding),
    Condition(
      id: "endurance", name: "Endurance athlete", icon: "figure.run",
      proteinPct: 18, carbsPct: 60, fatPct: 22, sodiumMg: 2300, satFatPctMax: 10, fiberG: 30,
      summary: "Carbohydrates are the main fuel for long efforts. Match intake to training load, refuel quickly after sessions, and keep fluids and electrolytes up.",
      recommend: [
        "Eat carbohydrate-rich meals 2-4 hours before long sessions",
        "Take 30-60 g carbs per hour during efforts over 90 minutes",
        "Refuel with carbs and protein within an hour after training",
        "Drink to thirst and replace sodium on long or hot sessions",
        "Eat iron-rich foods (lean meat, lentils, leafy greens)",
      ],
      avoid: [
        "Trying new foods on race day",
        "Very high-fiber or high-fat meals right before training",
        "Alcohol close to hard sessions",
        "Chronic under-eating relative to training load",
      ],
      samplePlan: SamplePlans.endurance),
    Condition(
      id: "pregnancy", name: "Pregnancy", icon: "figure.and.child.holdinghands",
      proteinPct: 20, carbsPct: 50, fatPct: 30, sodiumMg: 2300, satFatPctMax: 10, fiberG: 28,
      summary: "Eat nutrient-dense foods for you and your baby, with enough folate, iron, calcium and protein, and avoid foods that carry infection or mercury risk.",
      recommend: [
        "Eat folate-rich foods (leafy greens, lentils, fortified grains)",
        "Choose iron sources (lean meat, beans) with vitamin C",
        "Have 2-3 servings of pasteurized dairy or calcium-rich alternatives",
        "Eat low-mercury fish such as salmon 2-3 times a week, fully cooked",
        "Cook meat and eggs thoroughly",
        "Limit caffeine to about 200 mg a day",
      ],
      avoid: [
        "Raw or undercooked fish, meat and eggs (sushi, sashimi)",
        "Unpasteurized milk and soft cheeses",
        "Deli meats unless heated until steaming",
        "High-mercury fish (swordfish, shark, king mackerel, tilefish)",
        "Alcohol",
      ],
      flag: .pregnancyAvoid,
      samplePlan: SamplePlans.pregnancy),
  ]
}
