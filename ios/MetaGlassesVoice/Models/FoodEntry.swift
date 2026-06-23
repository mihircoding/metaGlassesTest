import Foundation

// MARK: - Food Entry

struct FoodEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double     // grams
    var carbs: Double       // grams
    var fat: Double         // grams
    var fiber: Double       // grams
    var sodium: Double      // mg
    var sugar: Double       // grams
    var servingSize: String?
    var servingQty: Double = 1.0
    var timestamp: Date = Date()
    var mealType: MealType = .other
    var source: EntrySource = .manual
    var barcode: String?
    var imageData: Data?
    var userId: String = "local_user"
    var notes: String?

    enum MealType: String, Codable, CaseIterable {
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snack = "Snack"
        case other = "Other"

        var icon: String {
            switch self {
            case .breakfast: return "sun.rise.fill"
            case .lunch:     return "sun.max.fill"
            case .dinner:    return "moon.stars.fill"
            case .snack:     return "leaf.fill"
            case .other:     return "fork.knife"
            }
        }
    }

    enum EntrySource: String, Codable {
        case barcode = "Barcode"
        case aiScan  = "AI Scan"
        case manual  = "Manual"
    }

    // Scaled nutrient helpers
    var scaledCalories: Double { calories * servingQty }
    var scaledProtein:  Double { protein  * servingQty }
    var scaledCarbs:    Double { carbs    * servingQty }
    var scaledFat:      Double { fat      * servingQty }
    var scaledFiber:    Double { fiber    * servingQty }
    var scaledSodium:   Double { sodium   * servingQty }
    var scaledSugar:    Double { sugar    * servingQty }
}

// MARK: - Daily Nutrition Summary

struct DailySummary {
    var date: Date
    var entries: [FoodEntry]

    var totalCalories: Double { entries.reduce(0) { $0 + $1.scaledCalories } }
    var totalProtein:  Double { entries.reduce(0) { $0 + $1.scaledProtein  } }
    var totalCarbs:    Double { entries.reduce(0) { $0 + $1.scaledCarbs    } }
    var totalFat:      Double { entries.reduce(0) { $0 + $1.scaledFat      } }
    var totalFiber:    Double { entries.reduce(0) { $0 + $1.scaledFiber    } }
    var totalSodium:   Double { entries.reduce(0) { $0 + $1.scaledSodium   } }

    var entriesByMeal: [FoodEntry.MealType: [FoodEntry]] {
        Dictionary(grouping: entries, by: \.mealType)
    }
}
