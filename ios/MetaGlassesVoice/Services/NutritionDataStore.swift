import Foundation
import Combine

// MARK: - Nutrition Data Store
// Persists everything to UserDefaults using JSON encoding.
// In production this would sync to CloudKit / a backend.

final class NutritionDataStore: ObservableObject {
    static let shared = NutritionDataStore()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: Keys
    private enum Key {
        static let userProfile   = "nutrition.userProfile"
        static let foodEntries   = "nutrition.foodEntries"
        static let mealPlans     = "nutrition.mealPlans"
        static let doctorSession = "nutrition.doctorSession"
        static let patients      = "nutrition.patients"
    }

    // MARK: - User Profile

    func loadProfile() -> UserProfile {
        guard
            let data = defaults.data(forKey: Key.userProfile),
            let profile = try? decoder.decode(UserProfile.self, from: data)
        else { return UserProfile() }
        return profile
    }

    func saveProfile(_ profile: UserProfile) {
        if let data = try? encoder.encode(profile) {
            defaults.set(data, forKey: Key.userProfile)
        }
    }

    // MARK: - Food Entries

    func loadEntries() -> [FoodEntry] {
        guard
            let data = defaults.data(forKey: Key.foodEntries),
            let entries = try? decoder.decode([FoodEntry].self, from: data)
        else { return [] }
        return entries
    }

    func saveEntries(_ entries: [FoodEntry]) {
        if let data = try? encoder.encode(entries) {
            defaults.set(data, forKey: Key.foodEntries)
        }
    }

    func addEntry(_ entry: FoodEntry) {
        var entries = loadEntries()
        entries.append(entry)
        saveEntries(entries)
    }

    func deleteEntry(id: UUID) {
        var entries = loadEntries()
        entries.removeAll { $0.id == id }
        saveEntries(entries)
    }

    func updateEntry(_ updated: FoodEntry) {
        var entries = loadEntries()
        if let idx = entries.firstIndex(where: { $0.id == updated.id }) {
            entries[idx] = updated
        }
        saveEntries(entries)
    }

    func entriesForDate(_ date: Date) -> [FoodEntry] {
        let calendar = Calendar.current
        return loadEntries().filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    func entriesForMonth(_ date: Date) -> [FoodEntry] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        return loadEntries().filter {
            let ec = calendar.dateComponents([.year, .month], from: $0.timestamp)
            return ec.year == comps.year && ec.month == comps.month
        }
    }

    func dailySummary(for date: Date) -> DailySummary {
        DailySummary(date: date, entries: entriesForDate(date))
    }

    func monthlySummaries(for date: Date) -> [Date: DailySummary] {
        let entries = entriesForMonth(date)
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            Calendar.current.startOfDay(for: entry.timestamp)
        }
        return grouped.mapValues { DailySummary(date: $0.first!.timestamp, entries: $0) }
    }

    // MARK: - Meal Plans

    func loadMealPlans() -> [MealPlan] {
        guard
            let data = defaults.data(forKey: Key.mealPlans),
            let plans = try? decoder.decode([MealPlan].self, from: data)
        else { return [] }
        return plans
    }

    func saveMealPlan(_ plan: MealPlan) {
        var plans = loadMealPlans()
        if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[idx] = plan
        } else {
            plans.append(plan)
        }
        if let data = try? encoder.encode(plans) {
            defaults.set(data, forKey: Key.mealPlans)
        }
    }

    func deleteMealPlan(id: UUID) {
        var plans = loadMealPlans()
        plans.removeAll { $0.id == id }
        if let data = try? encoder.encode(plans) {
            defaults.set(data, forKey: Key.mealPlans)
        }
    }

    func activeMealPlan(for userId: String) -> MealPlan? {
        loadMealPlans().first { $0.patientId == userId && $0.isActive }
    }

    // MARK: - Doctor Session

    func saveDoctorSession(_ session: DoctorSession) {
        if let data = try? encoder.encode(session) {
            defaults.set(data, forKey: Key.doctorSession)
        }
    }

    func loadDoctorSession() -> DoctorSession? {
        guard
            let data = defaults.data(forKey: Key.doctorSession),
            let session = try? decoder.decode(DoctorSession.self, from: data),
            session.isValid
        else { return nil }
        return session
    }

    func clearDoctorSession() {
        defaults.removeObject(forKey: Key.doctorSession)
    }

    // MARK: - Patients (doctor-side)

    func loadPatients() -> [PatientRecord] {
        guard
            let data = defaults.data(forKey: Key.patients),
            let patients = try? decoder.decode([PatientRecord].self, from: data)
        else {
            // Seed demo patients on first launch
            let demos = PatientRecord.demoPatients
            savePatients(demos)
            return demos
        }
        return patients
    }

    func savePatients(_ patients: [PatientRecord]) {
        if let data = try? encoder.encode(patients) {
            defaults.set(data, forKey: Key.patients)
        }
    }

    func updatePatient(_ updated: PatientRecord) {
        var patients = loadPatients()
        if let idx = patients.firstIndex(where: { $0.id == updated.id }) {
            patients[idx] = updated
        } else {
            patients.append(updated)
        }
        savePatients(patients)
    }

    // MARK: - Helpers

    func clearAllData() {
        [Key.userProfile, Key.foodEntries, Key.mealPlans, Key.doctorSession, Key.patients]
            .forEach { defaults.removeObject(forKey: $0) }
    }
}
