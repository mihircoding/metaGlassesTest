import Foundation

// MARK: - Doctor

struct Doctor: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var email: String
    var specialization: String = "General Nutrition"
    var licenseNumber: String = ""
    var patientIds: [String] = []
    var createdAt: Date = Date()
}

// MARK: - Patient (Doctor's View)

struct PatientRecord: Codable, Identifiable {
    var id: String                         // matches UserProfile.id
    var name: String
    var email: String
    var condition: MedicalCondition
    var assignedDoctorId: String?
    var mealPlanIds: [UUID] = []
    var foodLogSnapshot: [FoodEntry] = []  // last 30 days loaded from shared store
    var notes: String = ""
    var dateAdded: Date = Date()
}

// MARK: - Meal Plan

struct MealPlan: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var condition: MedicalCondition
    var doctorId: String
    var doctorName: String
    var patientId: String
    var createdAt: Date = Date()
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var dailyMeals: [DailyMealTemplate]
    var doctorNotes: String = ""
    var calorieTarget: Double
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double
}

// MARK: - Daily Meal Template

struct DailyMealTemplate: Codable, Identifiable {
    var id: UUID = UUID()
    var mealType: FoodEntry.MealType
    var suggestedFoods: [SuggestedFood]
    var targetCalories: Double
    var notes: String = ""
}

// MARK: - Suggested Food

struct SuggestedFood: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var estimatedCalories: Double
    var estimatedProtein: Double
    var estimatedCarbs: Double
    var estimatedFat: Double
    var servingNote: String     // e.g. "1 cup", "150g", "1 medium piece"
    var isRequired: Bool = false
    var alternatives: [String] = []
}

// MARK: - Doctor Login Session (local / demo)

struct DoctorSession: Codable {
    var doctorId: String
    var email: String
    var name: String
    var expiresAt: Date
    var isValid: Bool { Date() < expiresAt }
}

// MARK: - Demo / Seed Data

extension Doctor {
    static let demoDoctor = Doctor(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Dr. Sarah Chen",
        email: "doctor@nutrition.app",
        specialization: "Clinical Nutrition & Dietetics",
        licenseNumber: "RD-12345",
        patientIds: ["demo_patient_1", "demo_patient_2", "demo_patient_3"]
    )

    static let demoPassword = "doctor123"
}

extension PatientRecord {
    static let demoPatients: [PatientRecord] = [
        PatientRecord(
            id: "demo_patient_1",
            name: "Alex Johnson",
            email: "alex.j@example.com",
            condition: .diabetes,
            assignedDoctorId: "00000000-0000-0000-0000-000000000001",
            foodLogSnapshot: PatientRecord.sampleFoodLog(name: "Alex Johnson", condition: .diabetes),
            notes: "Type 2 diabetic, on metformin. Struggling to reduce simple carbs.",
            dateAdded: Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        ),
        PatientRecord(
            id: "demo_patient_2",
            name: "Marcus Williams",
            email: "m.williams@example.com",
            condition: .weightTraining,
            assignedDoctorId: "00000000-0000-0000-0000-000000000001",
            foodLogSnapshot: PatientRecord.sampleFoodLog(name: "Marcus Williams", condition: .weightTraining),
            notes: "Competitive bodybuilder. Preparing for summer show in 3 months.",
            dateAdded: Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        ),
        PatientRecord(
            id: "demo_patient_3",
            name: "Elena Rodriguez",
            email: "e.rodriguez@example.com",
            condition: .liverCirrhosis,
            assignedDoctorId: "00000000-0000-0000-0000-000000000001",
            foodLogSnapshot: PatientRecord.sampleFoodLog(name: "Elena Rodriguez", condition: .liverCirrhosis),
            notes: "Child-Pugh Class B. Monitoring sodium and protein intake closely.",
            dateAdded: Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        )
    ]

    static func sampleFoodLog(name: String, condition: MedicalCondition) -> [FoodEntry] {
        // Generate last 7 days of sample entries
        var entries: [FoodEntry] = []
        let calendar = Calendar.current
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dayEntries = sampleEntriesForCondition(condition, on: day)
            entries.append(contentsOf: dayEntries)
        }
        return entries
    }

    static func sampleEntriesForCondition(_ condition: MedicalCondition, on date: Date) -> [FoodEntry] {
        let calendar = Calendar.current
        func timeOn(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }

        switch condition {
        case .diabetes:
            return [
                FoodEntry(name: "Steel-cut oatmeal", calories: 150, protein: 5, carbs: 27, fat: 3, fiber: 4, sodium: 5, sugar: 1, servingSize: "1 cup cooked", timestamp: timeOn(8), mealType: .breakfast, source: .manual),
                FoodEntry(name: "Grilled chicken salad", calories: 320, protein: 35, carbs: 15, fat: 12, fiber: 5, sodium: 350, sugar: 4, servingSize: "1 large bowl", timestamp: timeOn(12, 30), mealType: .lunch, source: .manual),
                FoodEntry(name: "Apple", calories: 95, protein: 0, carbs: 25, fat: 0, fiber: 4, sodium: 2, sugar: 19, servingSize: "1 medium", timestamp: timeOn(15), mealType: .snack, source: .manual),
                FoodEntry(name: "Baked salmon with vegetables", calories: 400, protein: 40, carbs: 20, fat: 18, fiber: 6, sodium: 320, sugar: 5, servingSize: "1 portion", timestamp: timeOn(19), mealType: .dinner, source: .manual)
            ]
        case .weightTraining:
            return [
                FoodEntry(name: "Protein shake with banana", calories: 350, protein: 35, carbs: 42, fat: 5, fiber: 3, sodium: 150, sugar: 20, servingSize: "1 shake", timestamp: timeOn(7), mealType: .breakfast, source: .manual),
                FoodEntry(name: "Chicken breast with rice", calories: 550, protein: 55, carbs: 65, fat: 8, fiber: 2, sodium: 400, sugar: 1, servingSize: "1 large plate", timestamp: timeOn(12), mealType: .lunch, source: .manual),
                FoodEntry(name: "Greek yogurt with almonds", calories: 220, protein: 20, carbs: 15, fat: 8, fiber: 2, sodium: 80, sugar: 10, servingSize: "1 cup + handful", timestamp: timeOn(15, 30), mealType: .snack, source: .manual),
                FoodEntry(name: "Steak with sweet potato", calories: 650, protein: 60, carbs: 45, fat: 20, fiber: 5, sodium: 480, sugar: 8, servingSize: "1 portion", timestamp: timeOn(19, 30), mealType: .dinner, source: .manual),
                FoodEntry(name: "Casein protein before bed", calories: 120, protein: 24, carbs: 4, fat: 1, fiber: 0, sodium: 120, sugar: 2, servingSize: "1 scoop", timestamp: timeOn(22), mealType: .snack, source: .manual)
            ]
        case .liverCirrhosis:
            return [
                FoodEntry(name: "Scrambled eggs on whole grain toast", calories: 280, protein: 18, carbs: 28, fat: 10, fiber: 3, sodium: 200, sugar: 2, servingSize: "2 eggs + 1 slice", timestamp: timeOn(8), mealType: .breakfast, source: .manual),
                FoodEntry(name: "Lentil soup (low sodium)", calories: 220, protein: 15, carbs: 35, fat: 3, fiber: 8, sodium: 180, sugar: 4, servingSize: "1.5 cups", timestamp: timeOn(12), mealType: .lunch, source: .manual),
                FoodEntry(name: "Cottage cheese with berries", calories: 150, protein: 18, carbs: 12, fat: 3, fiber: 2, sodium: 110, sugar: 8, servingSize: "3/4 cup", timestamp: timeOn(15), mealType: .snack, source: .manual),
                FoodEntry(name: "Baked chicken thigh with steamed broccoli", calories: 350, protein: 38, carbs: 15, fat: 14, fiber: 5, sodium: 250, sugar: 3, servingSize: "1 portion", timestamp: timeOn(18, 30), mealType: .dinner, source: .manual),
                FoodEntry(name: "Whole grain crackers (late evening snack)", calories: 130, protein: 4, carbs: 22, fat: 3, fiber: 2, sodium: 150, sugar: 1, servingSize: "4 crackers", timestamp: timeOn(21), mealType: .snack, source: .manual)
            ]
        default:
            return [
                FoodEntry(name: "Mixed breakfast bowl", calories: 350, protein: 15, carbs: 45, fat: 12, fiber: 6, sodium: 300, sugar: 8, servingSize: "1 bowl", timestamp: timeOn(8), mealType: .breakfast, source: .manual),
                FoodEntry(name: "Grilled chicken wrap", calories: 420, protein: 30, carbs: 40, fat: 15, fiber: 4, sodium: 450, sugar: 3, servingSize: "1 wrap", timestamp: timeOn(12, 30), mealType: .lunch, source: .manual),
                FoodEntry(name: "Mixed dinner", calories: 500, protein: 35, carbs: 50, fat: 18, fiber: 6, sodium: 400, sugar: 5, servingSize: "1 plate", timestamp: timeOn(19), mealType: .dinner, source: .manual)
            ]
        }
    }
}
