import Foundation
import UIKit

// MARK: - AI Food Scanner Service
// Uses OpenAI GPT-4 Vision to analyze food images from the glasses camera
// and return estimated nutritional information.

final class AIFoodScannerService {

    static let shared = AIFoodScannerService()
    private init() {}

    private let endpoint = "https://api.openai.com/v1/chat/completions"

    // MARK: - Analyze Food Image

    func analyzeFood(image: UIImage, apiKey: String) async throws -> AIFoodResult {
        guard !apiKey.isEmpty else { throw AIFoodError.noAPIKey }

        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            throw AIFoodError.imageConversionFailed
        }
        let base64 = jpegData.base64EncodedString()

        let systemPrompt = """
You are a professional nutritionist and dietitian with expertise in food identification and calorie estimation. \
Analyze the food image and provide accurate nutritional estimates.

Always respond with ONLY valid JSON in this exact format (no markdown, no explanation):
{
  "foods": [
    {
      "name": "food name",
      "quantity": "estimated quantity/serving description",
      "calories": 000,
      "protein": 00.0,
      "carbs": 00.0,
      "fat": 00.0,
      "fiber": 0.0,
      "sodium": 000,
      "sugar": 00.0,
      "confidence": "high|medium|low"
    }
  ],
  "totalCalories": 000,
  "totalProtein": 00.0,
  "totalCarbs": 00.0,
  "totalFat": 00.0,
  "mealDescription": "brief description of what you see",
  "notes": "any important nutritional notes or caveats"
}
All nutritional values should be numbers (not strings). Calories in kcal, macros in grams, sodium in mg.
If you cannot identify food in the image, set foods to an empty array and totalCalories to 0.
"""

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Please analyze this food image and estimate the nutritional content. Be as accurate as possible based on typical portion sizes."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64)",
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIFoodError.networkError
        }

        if http.statusCode == 401 { throw AIFoodError.invalidAPIKey }
        if http.statusCode == 429 { throw AIFoodError.rateLimited }
        guard http.statusCode == 200 else { throw AIFoodError.networkError }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices.first?.message.content else {
            throw AIFoodError.emptyResponse
        }

        // Clean up markdown if present
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") { jsonString = String(jsonString.dropFirst(7)) }
        if jsonString.hasPrefix("```")    { jsonString = String(jsonString.dropFirst(3)) }
        if jsonString.hasSuffix("```")    { jsonString = String(jsonString.dropLast(3)) }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIFoodError.parseError
        }

        let result = try JSONDecoder().decode(AIFoodResult.self, from: jsonData)
        return result
    }
}

// MARK: - Result Models

struct AIFoodResult: Codable {
    var foods: [AIFoodItem]
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var mealDescription: String
    var notes: String

    func toFoodEntry(mealType: FoodEntry.MealType = .other) -> FoodEntry {
        let name = foods.count == 1 ? foods[0].name : mealDescription
        return FoodEntry(
            name: name.isEmpty ? "Scanned meal" : name,
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: foods.reduce(0) { $0 + $1.fiber },
            sodium: foods.reduce(0) { $0 + $1.sodium },
            sugar: foods.reduce(0) { $0 + $1.sugar },
            servingSize: foods.first?.quantity,
            mealType: mealType,
            source: .aiScan,
            notes: notes.isEmpty ? nil : notes
        )
    }
}

struct AIFoodItem: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantity: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sodium: Double
    var sugar: Double
    var confidence: String

    enum CodingKeys: String, CodingKey {
        case name, quantity, calories, protein, carbs, fat, fiber, sodium, sugar, confidence
    }
}

// MARK: - Errors

enum AIFoodError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case rateLimited
    case networkError
    case emptyResponse
    case parseError
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No OpenAI API key set. Add your key in Settings → Profile."
        case .invalidAPIKey:
            return "Invalid API key. Check your OpenAI API key in Settings → Profile."
        case .rateLimited:
            return "OpenAI rate limit reached. Please wait a moment and try again."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .emptyResponse:
            return "AI returned an empty response. Try again."
        case .parseError:
            return "Could not parse AI response. Try again."
        case .imageConversionFailed:
            return "Could not process the image. Try again."
        }
    }
}

// MARK: - OpenAI API Response Models

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

private struct OpenAIMessage: Codable {
    let content: String
}
