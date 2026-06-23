import Foundation

// MARK: - Medical Condition

enum MedicalCondition: String, Codable, CaseIterable, Identifiable {
    case none            = "No Condition"
    case diabetes        = "Diabetes (Type 2)"
    case type1Diabetes   = "Diabetes (Type 1)"
    case weightTraining  = "Weight Training / Bodybuilding"
    case liverCirrhosis  = "Liver Cirrhosis / Liver Disease"
    case heartDisease    = "Heart Disease / Hypertension"
    case kidneyDisease   = "Chronic Kidney Disease"
    case celiacDisease   = "Celiac Disease / Gluten Intolerance"
    case obesity         = "Obesity / Weight Loss"
    case hypothyroidism  = "Hypothyroidism"
    case ibs             = "Irritable Bowel Syndrome (IBS)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none:           return "checkmark.circle.fill"
        case .diabetes, .type1Diabetes: return "drop.fill"
        case .weightTraining: return "figure.strengthtraining.traditional"
        case .liverCirrhosis: return "waveform.path.ecg"
        case .heartDisease:   return "heart.fill"
        case .kidneyDisease:  return "cross.fill"
        case .celiacDisease:  return "leaf.fill"
        case .obesity:        return "scalemass.fill"
        case .hypothyroidism: return "thermometer.medium"
        case .ibs:            return "stomach"
        }
    }

    var color: String {
        switch self {
        case .none:           return "green"
        case .diabetes, .type1Diabetes: return "blue"
        case .weightTraining: return "orange"
        case .liverCirrhosis: return "yellow"
        case .heartDisease:   return "red"
        case .kidneyDisease:  return "purple"
        case .celiacDisease:  return "brown"
        case .obesity:        return "teal"
        case .hypothyroidism: return "indigo"
        case .ibs:            return "mint"
        }
    }

    // MARK: - Dietary Guidelines per Condition

    var dietaryGuidelines: DietaryGuidelines {
        switch self {
        case .none:
            return DietaryGuidelines(
                title: "General Healthy Diet",
                summary: "Follow a balanced diet with whole foods, lean proteins, complex carbohydrates, and healthy fats.",
                dailyCaloricTarget: 2000,
                proteinTarget: 50,
                carbTarget: 250,
                fatTarget: 65,
                fiberTarget: 25,
                sodiumLimit: 2300,
                restrictions: [],
                recommendations: [
                    "Eat a variety of colorful fruits and vegetables",
                    "Choose whole grains over refined grains",
                    "Limit processed foods and added sugars",
                    "Stay hydrated with water",
                    "Maintain regular meal times"
                ],
                avoid: [
                    "Excessive processed foods",
                    "Trans fats",
                    "Added sugars in large quantities"
                ]
            )

        case .diabetes, .type1Diabetes:
            return DietaryGuidelines(
                title: "Diabetic Diet",
                summary: "Focus on low glycemic index foods. Monitor carbohydrate intake carefully — aim for 45–60g per meal. Consistent meal timing is critical.",
                dailyCaloricTarget: 1800,
                proteinTarget: 80,
                carbTarget: 180,
                fatTarget: 60,
                fiberTarget: 35,
                sodiumLimit: 2300,
                restrictions: ["Simple sugars", "High-GI foods", "Sugary drinks"],
                recommendations: [
                    "Choose low glycemic index foods (GI < 55)",
                    "Aim for 45–60g carbohydrates per meal",
                    "Include fiber-rich foods to slow glucose absorption",
                    "Eat regular, consistent meals",
                    "Choose lean proteins",
                    "Include non-starchy vegetables freely",
                    "Monitor blood sugar before and after meals"
                ],
                avoid: [
                    "White bread, white rice, refined pasta",
                    "Sugary beverages and fruit juices",
                    "Candy, cake, and pastries",
                    "High-sugar cereals",
                    "Sweetened dairy products"
                ]
            )

        case .weightTraining:
            return DietaryGuidelines(
                title: "Muscle Building / Weight Training Diet",
                summary: "High protein intake (1.6–2.2g/kg body weight) is essential. Sufficient carbohydrates fuel training. Aim for a 300–500 calorie surplus.",
                dailyCaloricTarget: 2800,
                proteinTarget: 180,
                carbTarget: 350,
                fatTarget: 80,
                fiberTarget: 30,
                sodiumLimit: 2800,
                restrictions: [],
                recommendations: [
                    "Consume 1.6–2.2g protein per kg of body weight daily",
                    "Eat protein within 30–60 minutes post-workout",
                    "Include complex carbs for sustained energy",
                    "Time carbohydrates around workouts",
                    "Stay well-hydrated during training",
                    "Include creatine-rich foods (red meat, fish)",
                    "Eat 4–6 meals per day for anabolic stimulus"
                ],
                avoid: [
                    "Highly processed junk foods",
                    "Alcohol (impairs muscle protein synthesis)",
                    "Training on empty stomach (reduces performance)"
                ]
            )

        case .liverCirrhosis:
            return DietaryGuidelines(
                title: "Liver Cirrhosis Diet",
                summary: "Adequate protein prevents muscle wasting. Sodium must be strictly limited. Small frequent meals prevent hypoglycemia. Avoid alcohol completely.",
                dailyCaloricTarget: 2000,
                proteinTarget: 100,
                carbTarget: 240,
                fatTarget: 55,
                fiberTarget: 20,
                sodiumLimit: 1500,
                restrictions: ["Alcohol", "High sodium foods", "Raw shellfish"],
                recommendations: [
                    "Eat 1.2–1.5g protein per kg body weight",
                    "Have 4–6 small meals per day",
                    "Include a late evening snack (complex carbs) to prevent overnight hypoglycemia",
                    "Ensure adequate zinc intake (meat, legumes, nuts)",
                    "Choose lean proteins (chicken, fish, eggs, legumes)",
                    "Include B-vitamin rich foods",
                    "Monitor fluid intake if edema is present"
                ],
                avoid: [
                    "ALL alcohol — strictly zero",
                    "Raw or undercooked shellfish (infection risk)",
                    "High-sodium processed foods, canned soups, soy sauce",
                    "Large amounts of red meat",
                    "High-fat fried foods"
                ]
            )

        case .heartDisease:
            return DietaryGuidelines(
                title: "Heart-Healthy / Hypertension Diet",
                summary: "DASH or Mediterranean diet approach. Strictly limit sodium and saturated fats. Increase potassium, omega-3 fatty acids, and fiber.",
                dailyCaloricTarget: 1900,
                proteinTarget: 70,
                carbTarget: 240,
                fatTarget: 55,
                fiberTarget: 30,
                sodiumLimit: 1500,
                restrictions: ["Saturated fat", "Trans fat", "High sodium", "Excess alcohol"],
                recommendations: [
                    "Follow DASH or Mediterranean diet principles",
                    "Increase omega-3 fatty acids (salmon, walnuts, flaxseed)",
                    "Choose potassium-rich foods (bananas, sweet potatoes)",
                    "Eat 7–9 servings of fruits and vegetables daily",
                    "Choose whole grains over refined grains",
                    "Include legumes 4× per week",
                    "Use olive oil instead of butter"
                ],
                avoid: [
                    "Saturated fats (red meat, full-fat dairy)",
                    "Trans fats (partially hydrogenated oils)",
                    "High-sodium processed and canned foods",
                    "Excessive alcohol",
                    "Fried foods"
                ]
            )

        case .kidneyDisease:
            return DietaryGuidelines(
                title: "Chronic Kidney Disease Diet",
                summary: "Limit potassium, phosphorus, and sodium. Protein restriction depends on disease stage. Fluids may also be limited.",
                dailyCaloricTarget: 1900,
                proteinTarget: 50,
                carbTarget: 270,
                fatTarget: 60,
                fiberTarget: 20,
                sodiumLimit: 1500,
                restrictions: ["High potassium foods", "High phosphorus foods", "Excess protein"],
                recommendations: [
                    "Follow your nephrologist's protein recommendations",
                    "Limit potassium (avoid bananas, oranges, potatoes in large amounts)",
                    "Limit phosphorus (limit dairy, nuts, whole grains)",
                    "Restrict sodium to under 1500mg/day",
                    "Choose kidney-friendly fruits (apples, grapes, berries)",
                    "Work with a renal dietitian for personalized plan"
                ],
                avoid: [
                    "Bananas, oranges, tomatoes, potatoes (high potassium)",
                    "Dairy products in large amounts (high phosphorus)",
                    "Nuts and seeds in large amounts",
                    "Salt substitutes (often high in potassium)",
                    "High-protein diets without medical guidance"
                ]
            )

        case .celiacDisease:
            return DietaryGuidelines(
                title: "Gluten-Free Diet (Celiac)",
                summary: "Strictly gluten-free. Even trace amounts cause intestinal damage. Focus on naturally gluten-free grains and whole foods.",
                dailyCaloricTarget: 2000,
                proteinTarget: 65,
                carbTarget: 260,
                fatTarget: 65,
                fiberTarget: 25,
                sodiumLimit: 2300,
                restrictions: ["Wheat", "Barley", "Rye", "Regular oats (cross-contamination)"],
                recommendations: [
                    "Read all food labels carefully for gluten",
                    "Choose naturally gluten-free grains: rice, quinoa, corn, potato",
                    "Use certified gluten-free oats if desired",
                    "Be aware of cross-contamination in kitchens",
                    "Supplement iron, B12, folate, vitamin D if deficient",
                    "Eat plenty of fruits, vegetables, and lean proteins"
                ],
                avoid: [
                    "Wheat (bread, pasta, most baked goods)",
                    "Barley and rye",
                    "Beer and malt beverages",
                    "Soy sauce (most contain wheat)",
                    "Non-certified oats"
                ]
            )

        case .obesity:
            return DietaryGuidelines(
                title: "Weight Loss Diet",
                summary: "Create a moderate caloric deficit (500–750 cal/day). Focus on high-volume, nutrient-dense, low-calorie foods. High protein helps preserve muscle mass.",
                dailyCaloricTarget: 1500,
                proteinTarget: 100,
                carbTarget: 150,
                fatTarget: 50,
                fiberTarget: 35,
                sodiumLimit: 2300,
                restrictions: ["High-calorie processed foods", "Sugary beverages"],
                recommendations: [
                    "Aim for a 500–750 calorie deficit per day",
                    "Prioritize high-protein foods for satiety",
                    "Fill half your plate with non-starchy vegetables",
                    "Choose high-fiber foods that keep you full",
                    "Drink water before meals",
                    "Avoid liquid calories (soda, juice, alcohol)",
                    "Eat slowly and mindfully"
                ],
                avoid: [
                    "Sugary beverages (soda, juice, sports drinks)",
                    "Ultra-processed snack foods",
                    "Fast food high in calories",
                    "Mindless snacking",
                    "Late-night eating"
                ]
            )

        case .hypothyroidism:
            return DietaryGuidelines(
                title: "Hypothyroidism Diet",
                summary: "Support thyroid function with iodine and selenium. Take levothyroxine away from certain foods that interfere with absorption.",
                dailyCaloricTarget: 1800,
                proteinTarget: 70,
                carbTarget: 220,
                fatTarget: 60,
                fiberTarget: 25,
                sodiumLimit: 2300,
                restrictions: ["Raw cruciferous vegetables in excess", "Soy near medication time"],
                recommendations: [
                    "Ensure adequate iodine intake (seafood, iodized salt)",
                    "Include selenium-rich foods (Brazil nuts, tuna, eggs)",
                    "Take thyroid medication 30–60 minutes before eating",
                    "Avoid soy within 4 hours of medication",
                    "Choose anti-inflammatory foods",
                    "Maintain healthy weight to support thyroid function"
                ],
                avoid: [
                    "Large amounts of raw goitrogens (kale, cabbage) near medication",
                    "Soy products close to thyroid medication time",
                    "Excess processed foods",
                    "Gluten (if also have Hashimoto's — check with doctor)"
                ]
            )

        case .ibs:
            return DietaryGuidelines(
                title: "IBS Diet (Low-FODMAP)",
                summary: "Follow a low-FODMAP diet to reduce fermentable sugars that trigger symptoms. Work with a dietitian to reintroduce foods systematically.",
                dailyCaloricTarget: 2000,
                proteinTarget: 70,
                carbTarget: 250,
                fatTarget: 65,
                fiberTarget: 25,
                sodiumLimit: 2300,
                restrictions: ["High-FODMAP foods", "Trigger foods specific to individual"],
                recommendations: [
                    "Follow low-FODMAP diet for 4–8 weeks, then reintroduce",
                    "Keep a food and symptom diary",
                    "Eat slowly and chew food well",
                    "Avoid eating very large meals",
                    "Manage stress (major IBS trigger)",
                    "Stay well hydrated",
                    "Soluble fiber may help (oats, bananas, carrots)"
                ],
                avoid: [
                    "High-FODMAP foods: garlic, onion, wheat, beans",
                    "Lactose (milk, soft cheeses) if sensitive",
                    "Excess fructose (apples, pears, mango)",
                    "Carbonated beverages",
                    "Artificial sweeteners (sorbitol, mannitol)"
                ]
            )
        }
    }
}

// MARK: - Dietary Guidelines

struct DietaryGuidelines {
    var title: String
    var summary: String
    var dailyCaloricTarget: Double
    var proteinTarget: Double    // grams
    var carbTarget: Double       // grams
    var fatTarget: Double        // grams
    var fiberTarget: Double      // grams
    var sodiumLimit: Double      // mg
    var restrictions: [String]
    var recommendations: [String]
    var avoid: [String]
}
