import Foundation
import SwiftUI

// MARK: - Doctor View Model

@MainActor
final class DoctorViewModel: ObservableObject {

    @Published var isLoggedIn = false
    @Published var currentDoctor: Doctor?
    @Published var patients: [PatientRecord] = []
    @Published var selectedPatient: PatientRecord?
    @Published var mealPlans: [MealPlan] = []

    // Login state
    @Published var loginEmail = ""
    @Published var loginPassword = ""
    @Published var loginError: String?
    @Published var isLoggingIn = false

    // Create meal plan state
    @Published var isCreatingMealPlan = false

    private let store = NutritionDataStore.shared

    init() {
        // Restore session if still valid
        if let session = store.loadDoctorSession() {
            restoreSession(session)
        }
    }

    // MARK: - Authentication

    func login() {
        let email = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let password = loginPassword

        guard !email.isEmpty, !password.isEmpty else {
            loginError = "Enter your email and password."
            return
        }

        isLoggingIn = true
        loginError = nil

        // Demo credentials check (in production, call your auth backend)
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // simulate network
            if email == Doctor.demoDoctor.email.lowercased() && password == Doctor.demoPassword {
                let session = DoctorSession(
                    doctorId: Doctor.demoDoctor.id.uuidString,
                    email: Doctor.demoDoctor.email,
                    name: Doctor.demoDoctor.name,
                    expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
                )
                store.saveDoctorSession(session)
                restoreSession(session)
                loginEmail = ""
                loginPassword = ""
            } else {
                loginError = "Invalid email or password. (Demo: doctor@nutrition.app / doctor123)"
            }
            isLoggingIn = false
        }
    }

    func logout() {
        store.clearDoctorSession()
        isLoggedIn = false
        currentDoctor = nil
        patients = []
        mealPlans = []
        selectedPatient = nil
    }

    private func restoreSession(_ session: DoctorSession) {
        currentDoctor = Doctor.demoDoctor
        isLoggedIn = true
        loadPatients()
        loadMealPlans()
    }

    // MARK: - Patients

    func loadPatients() {
        patients = store.loadPatients()
    }

    func patientsForCurrentDoctor() -> [PatientRecord] {
        guard let doctor = currentDoctor else { return [] }
        return patients.filter { doctor.patientIds.contains($0.id) }
    }

    func updatePatientNotes(_ patient: PatientRecord, notes: String) {
        var updated = patient
        updated.notes = notes
        store.updatePatient(updated)
        loadPatients()
    }

    func patientDailySummaries(_ patient: PatientRecord, days: Int = 7) -> [(Date, DailySummary)] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset -> (Date, DailySummary)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let dayEntries = patient.foodLogSnapshot.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            if dayEntries.isEmpty { return nil }
            return (date, DailySummary(date: date, entries: dayEntries))
        }.reversed()
    }

    func averageDailyCalories(_ patient: PatientRecord) -> Double {
        let summaries = patientDailySummaries(patient, days: 7)
        guard !summaries.isEmpty else { return 0 }
        let total = summaries.reduce(0.0) { $0 + $1.1.totalCalories }
        return total / Double(summaries.count)
    }

    // MARK: - Meal Plans

    func loadMealPlans() {
        mealPlans = store.loadMealPlans()
    }

    func mealPlansForPatient(_ patient: PatientRecord) -> [MealPlan] {
        mealPlans.filter { $0.patientId == patient.id }
    }

    func createMealPlan(for patient: PatientRecord, plan: MealPlan) {
        // Deactivate old plans first
        var updatedPlans = mealPlans
        for i in updatedPlans.indices where updatedPlans[i].patientId == patient.id {
            updatedPlans[i].isActive = false
            store.saveMealPlan(updatedPlans[i])
        }
        store.saveMealPlan(plan)
        loadMealPlans()

        // Update patient record with new plan
        var updatedPatient = patient
        if !updatedPatient.mealPlanIds.contains(plan.id) {
            updatedPatient.mealPlanIds.append(plan.id)
        }
        store.updatePatient(updatedPatient)
        loadPatients()
    }

    func deleteMealPlan(_ plan: MealPlan) {
        store.deleteMealPlan(id: plan.id)
        loadMealPlans()
    }

    // MARK: - Condition Compliance Check

    func complianceWarnings(for patient: PatientRecord) -> [String] {
        let summaries = patientDailySummaries(patient, days: 3)
        guard !summaries.isEmpty else { return [] }
        var warnings: [String] = []
        let guidelines = patient.condition.dietaryGuidelines
        let avgCal = summaries.reduce(0.0) { $0 + $1.1.totalCalories } / Double(summaries.count)
        let avgSodium = summaries.reduce(0.0) { $0 + $1.1.totalSodium } / Double(summaries.count)
        let avgProtein = summaries.reduce(0.0) { $0 + $1.1.totalProtein } / Double(summaries.count)

        if avgCal > guidelines.dailyCaloricTarget * 1.2 {
            warnings.append("Avg calories (\(Int(avgCal)) kcal) significantly above target (\(Int(guidelines.dailyCaloricTarget)) kcal)")
        }
        if avgSodium > guidelines.sodiumLimit * 1.1 {
            warnings.append("Avg sodium (\(Int(avgSodium))mg) exceeds limit (\(Int(guidelines.sodiumLimit))mg)")
        }
        if patient.condition == .weightTraining && avgProtein < guidelines.proteinTarget * 0.8 {
            warnings.append("Protein intake (\(Int(avgProtein))g) below target (\(Int(guidelines.proteinTarget))g)")
        }
        return warnings
    }
}
