import Foundation
import Combine
import SwiftUI

// MARK: - Nutrition View Model

@MainActor
final class NutritionViewModel: ObservableObject {

    // MARK: Published State
    @Published var profile: UserProfile
    @Published var todayEntries: [FoodEntry] = []
    @Published var selectedDate: Date = Date()
    @Published var activeMealPlan: MealPlan?

    // Scan state
    @Published var scannedEntry: FoodEntry?
    @Published var isLoadingBarcode = false
    @Published var isAnalyzingFood  = false
    @Published var scanError: String?
    @Published var aiScanResult: AIFoodResult?
    @Published var capturedImage: UIImage?

    // Food search state
    @Published var searchQuery = ""
    @Published var searchResults: [FoodSearchResult] = []
    @Published var isSearching = false

    // Sheet / navigation
    @Published var showAddFoodSheet = false
    @Published var pendingEntry: FoodEntry?

    private let store = NutritionDataStore.shared
    private var searchTask: Task<Void, Never>?

    init() {
        self.profile = store.loadProfile()
        self.todayEntries = store.entriesForDate(Date())
        self.activeMealPlan = store.activeMealPlan(for: profile.id)
        applyConditionGoals()
    }

    // MARK: - Daily Summary

    var todaySummary: DailySummary { DailySummary(date: selectedDate, entries: entriesForDate(selectedDate)) }

    var calorieProgress: Double {
        guard profile.dailyCaloricLimit > 0 else { return 0 }
        return min(todaySummary.totalCalories / profile.dailyCaloricLimit, 1.0)
    }

    var caloriesRemaining: Double {
        max(profile.dailyCaloricLimit - todaySummary.totalCalories, 0)
    }

    func entriesForDate(_ date: Date) -> [FoodEntry] {
        store.entriesForDate(date)
    }

    func monthlySummaries() -> [Date: DailySummary] {
        store.monthlySummaries(for: selectedDate)
    }

    // MARK: - Adding / Removing Entries

    func addEntry(_ entry: FoodEntry) {
        store.addEntry(entry)
        refreshToday()
    }

    func deleteEntry(_ entry: FoodEntry) {
        store.deleteEntry(id: entry.id)
        refreshToday()
    }

    func updateEntry(_ entry: FoodEntry) {
        store.updateEntry(entry)
        refreshToday()
    }

    func confirmPendingEntry(mealType: FoodEntry.MealType) {
        guard var entry = pendingEntry else { return }
        entry.mealType = mealType
        addEntry(entry)
        pendingEntry = nil
        scannedEntry = nil
        aiScanResult = nil
        capturedImage = nil
    }

    func refreshToday() {
        todayEntries = store.entriesForDate(Date())
    }

    // MARK: - Barcode Scan

    func handleBarcodeDetected(_ barcode: String) {
        guard !isLoadingBarcode else { return }
        isLoadingBarcode = true
        scanError = nil
        Task {
            do {
                if let entry = try await FoodDatabaseService.shared.lookupBarcode(barcode) {
                    self.scannedEntry = entry
                    self.pendingEntry = entry
                } else {
                    self.scanError = "Product not found. Try manual entry."
                }
            } catch {
                self.scanError = error.localizedDescription
            }
            self.isLoadingBarcode = false
        }
    }

    // MARK: - AI Food Scan

    func analyzeImage(_ image: UIImage) {
        guard !isAnalyzingFood else { return }
        isAnalyzingFood = true
        capturedImage = image
        scanError = nil
        Task {
            do {
                let result = try await AIFoodScannerService.shared.analyzeFood(
                    image: image,
                    apiKey: profile.openAIKey
                )
                self.aiScanResult = result
                self.pendingEntry = result.toFoodEntry()
            } catch {
                self.scanError = error.localizedDescription
            }
            self.isAnalyzingFood = false
        }
    }

    // MARK: - Food Search

    func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { searchResults = []; return }

        searchTask?.cancel()
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // debounce 400ms
            guard !Task.isCancelled else { return }
            do {
                let results = try await FoodDatabaseService.shared.searchFood(query: query)
                if !Task.isCancelled {
                    self.searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    self.scanError = error.localizedDescription
                }
            }
            if !Task.isCancelled {
                self.isSearching = false
            }
        }
    }

    // MARK: - Profile

    func saveProfile() {
        store.saveProfile(profile)
        applyConditionGoals()
    }

    private func applyConditionGoals() {
        if profile.medicalCondition != .none {
            let g = profile.medicalCondition.dietaryGuidelines
            if profile.dailyCaloricLimit == 2000 { // only auto-apply if not customized
                profile.dailyCaloricLimit = g.dailyCaloricTarget
                profile.proteinGoal = g.proteinTarget
                profile.carbGoal = g.carbTarget
                profile.fatGoal = g.fatTarget
                profile.fiberGoal = g.fiberTarget
            }
        }
    }

    func updateCondition(_ condition: MedicalCondition) {
        profile.medicalCondition = condition
        profile.applyConditionDefaults()
        saveProfile()
        activeMealPlan = store.activeMealPlan(for: profile.id)
    }

    // MARK: - Meal Plan

    func refreshActiveMealPlan() {
        activeMealPlan = store.activeMealPlan(for: profile.id)
    }
}

// MARK: - Formatting Helpers

extension Double {
    var calorieString: String { String(format: "%.0f", self) }
    var macroString: String   { String(format: "%.1f", self) }
    var gramString: String    { String(format: "%.0fg", self) }
}
