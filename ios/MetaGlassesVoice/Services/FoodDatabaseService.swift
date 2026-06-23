import Foundation

// MARK: - Open Food Facts API Service
// Docs: https://world.openfoodfacts.org/data

final class FoodDatabaseService {

    static let shared = FoodDatabaseService()
    private init() {}

    private let baseURL = "https://world.openfoodfacts.org/api/v0/product"
    private let searchURL = "https://world.openfoodfacts.org/cgi/search.pl"

    // MARK: - Barcode Lookup

    func lookupBarcode(_ barcode: String) async throws -> FoodEntry? {
        let url = URL(string: "\(baseURL)/\(barcode).json")!
        var request = URLRequest(url: url)
        request.setValue("NutritionApp/1.0 (iOS; nutrition-tracker)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FoodDBError.networkError
        }

        let result = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard result.status == 1, let product = result.product else {
            throw FoodDBError.productNotFound
        }

        return mapToFoodEntry(product: product, barcode: barcode)
    }

    // MARK: - Text Search

    func searchFood(query: String) async throws -> [FoodSearchResult] {
        var components = URLComponents(string: searchURL)!
        components.queryItems = [
            URLQueryItem(name: "search_terms",   value: query),
            URLQueryItem(name: "search_simple",  value: "1"),
            URLQueryItem(name: "action",         value: "process"),
            URLQueryItem(name: "json",           value: "1"),
            URLQueryItem(name: "page_size",      value: "20"),
            URLQueryItem(name: "fields",         value: "product_name,brands,nutriments,serving_size,image_url")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("NutritionApp/1.0 (iOS; nutrition-tracker)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(OFFSearchResponse.self, from: data)

        return (result.products ?? []).compactMap { product in
            guard let name = product.product_name, !name.isEmpty else { return nil }
            let nut = product.nutriments ?? OFFNutriments()
            return FoodSearchResult(
                name: name,
                brand: product.brands,
                calories: (nut.energyKcal100g ?? nut.energy_value).flatMap { $0 } ?? 0,
                protein: nut.proteins_100g ?? 0,
                carbs: nut.carbohydrates_100g ?? 0,
                fat: nut.fat_100g ?? 0,
                fiber: nut.fiber_100g ?? 0,
                sodium: (nut.sodium_100g ?? 0) * 1000,
                sugar: nut.sugars_100g ?? 0,
                servingSize: product.serving_size
            )
        }
    }

    // MARK: - Mapping

    private func mapToFoodEntry(product: OFFProduct, barcode: String) -> FoodEntry? {
        guard let name = product.product_name, !name.isEmpty else { return nil }
        let nut = product.nutriments ?? OFFNutriments()

        // OFF stores per-100g; serving_size_g helps scale
        let servingG = product.serving_quantity.flatMap { Double($0) } ?? 100.0
        let scale = servingG / 100.0

        let cal = ((nut.energyKcal100g ?? nut.energy_value).flatMap { $0 } ?? 0) * scale

        return FoodEntry(
            name: name,
            brand: product.brands,
            calories: cal > 0 ? cal : (nut.energyKcal_serving ?? 0),
            protein: (nut.proteins_100g ?? 0) * scale,
            carbs: (nut.carbohydrates_100g ?? 0) * scale,
            fat: (nut.fat_100g ?? 0) * scale,
            fiber: (nut.fiber_100g ?? 0) * scale,
            sodium: ((nut.sodium_100g ?? 0) * scale) * 1000,
            sugar: (nut.sugars_100g ?? 0) * scale,
            servingSize: product.serving_size ?? "\(Int(servingG))g",
            source: .barcode,
            barcode: barcode
        )
    }
}

// MARK: - Errors

enum FoodDBError: LocalizedError {
    case productNotFound
    case networkError
    case parseError

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "Product not found in database. Try entering nutrition info manually."
        case .networkError:    return "Network error. Check your connection and try again."
        case .parseError:      return "Could not read product data."
        }
    }
}

// MARK: - Search Result Model

struct FoodSearchResult: Identifiable {
    let id = UUID()
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sodium: Double
    var sugar: Double
    var servingSize: String?

    func toFoodEntry(mealType: FoodEntry.MealType = .other) -> FoodEntry {
        FoodEntry(
            name: name,
            brand: brand,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sodium: sodium,
            sugar: sugar,
            servingSize: servingSize,
            mealType: mealType,
            source: .manual
        )
    }
}

// MARK: - Open Food Facts API Response Models

private struct OFFProductResponse: Codable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFSearchResponse: Codable {
    let products: [OFFProduct]?
}

private struct OFFProduct: Codable {
    let product_name: String?
    let brands: String?
    let serving_size: String?
    let serving_quantity: String?
    let nutriments: OFFNutriments?
    let image_url: String?
}

private struct OFFNutriments: Codable {
    // Per 100g
    let energyKcal100g: Double?
    let energy_value: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let fiber_100g: Double?
    let sodium_100g: Double?
    let sugars_100g: Double?
    // Per serving (fallback)
    let energyKcal_serving: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g     = "energy-kcal_100g"
        case energy_value       = "energy_value"
        case proteins_100g      = "proteins_100g"
        case carbohydrates_100g = "carbohydrates_100g"
        case fat_100g           = "fat_100g"
        case fiber_100g         = "fiber_100g"
        case sodium_100g        = "sodium_100g"
        case sugars_100g        = "sugars_100g"
        case energyKcal_serving = "energy-kcal_serving"
    }
}
