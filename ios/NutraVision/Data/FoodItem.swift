import Foundation
import NutraCore

// Swift mirrors of the Edge Function types in spec section 4.

enum NutrientSource: String, Codable { case usda, off, aiEstimate = "ai_estimate" }

/// A `food-search` hit (USDA FoodData Central or Open Food Facts); nutrients are per labeled serving.
struct FoodItem: Codable, Equatable, Identifiable {
    var name: String
    var brand: String?
    var source: NutrientSource
    var sourceRef: String  // FDC id or barcode, as a string
    var servingDesc: String
    var servingGrams: Double?
    var perServing: Nutrients

    var id: String { "\(source.rawValue):\(sourceRef)" }

    enum CodingKeys: String, CodingKey {
        case name, brand, source
        case sourceRef = "source_ref"
        case servingDesc = "serving_desc"
        case servingGrams = "serving_grams"
        case perServing = "per_serving"
    }
}

/// One food found in a photo; `nutrients` are already scaled to `grams`.
struct AnalyzedItem: Codable, Equatable, Identifiable {
    enum Confidence: String, Codable { case high, medium, low }

    var id = UUID()  // local only, for editable lists
    var name: String
    var grams: Double
    var confidence: Confidence
    var source: NutrientSource
    var sourceRef: String?
    var nutrients: Nutrients

    enum CodingKeys: String, CodingKey {
        case name, grams, confidence, source, nutrients
        case sourceRef = "source_ref"
    }
}

extension AnalyzedItem {
    /// One labeled serving of a barcode hit, so it uses the same scan card and logging path as a photo item.
    init(product: FoodItem) {
        self.init(name: product.name, grams: product.servingGrams ?? 100, confidence: .high,
                  source: product.source, sourceRef: product.sourceRef, nutrients: product.perServing)
    }
}

/// `analyze-food` response.
struct AnalyzeResult: Codable, Equatable {
    var isFood: Bool
    var items: [AnalyzedItem]
    var totals: Nutrients
    var notes: String

    enum CodingKeys: String, CodingKey {
        case items, totals, notes
        case isFood = "is_food"
    }
}
