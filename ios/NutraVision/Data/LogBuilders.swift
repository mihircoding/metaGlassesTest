import Foundation
import NutraCore

extension FoodLogRow {
    /// Today logs at the current time; another day logs at noon of that day.
    static func loggedAt(for date: Date) -> Date {
        if Calendar.current.isDateInToday(date) { return Date() }
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    init(item: FoodItem, userId: UUID, date: Date, meal: Meal, servings: Double, source: FoodSource) {
        self.init(userId: userId, loggedAt: Self.loggedAt(for: date), meal: meal, name: item.name, brand: item.brand,
                  servingDesc: item.servingDesc, servingGrams: item.servingGrams, servings: servings,
                  perServing: item.perServing, source: source, sourceRef: item.sourceRef)
    }

    /// One row per analyzed item: servings 1, the serving is the item's grams, nutrients as given.
    init(analyzed: AnalyzedItem, userId: UUID, date: Date, meal: Meal, source: FoodSource, scanId: UUID) {
        self.init(userId: userId, loggedAt: Self.loggedAt(for: date), meal: meal, name: analyzed.name, brand: nil,
                  servingDesc: "\(Int(analyzed.grams)) g", servingGrams: analyzed.grams, servings: 1,
                  perServing: analyzed.nutrients, source: source, sourceRef: analyzed.sourceRef,
                  aiConfidence: analyzed.confidence.rawValue, scanId: scanId)
    }
}

extension AppModel {
    /// Inserts the rows, then refreshes today so Dashboard and Diary show them. A failed refresh is not an
    /// error: the rows are saved, and a retry would duplicate them.
    func addLogs(_ rows: [FoodLogRow]) async throws {
        try await Backend.shared.insertFoodLogs(rows)
        try? await today?.load()
    }

    func verdict(name: String, item: Nutrients) -> Verdict {
        HealthVerdict.evaluate(name: name, item: item, targets: targets, dailyGoalKcal: dailyGoalKcal,
                               consumed: today?.consumed ?? .zero, conditionIds: profile?.conditions ?? [])
    }
}
