import Foundation

// MARK: - User Profile

struct UserProfile: Codable {
    var id: String = "local_user"
    var name: String = "My Profile"
    var email: String = ""
    var dateOfBirth: Date?
    var weightKg: Double?
    var heightCm: Double?
    var sex: BiologicalSex = .preferNotToSay
    var activityLevel: ActivityLevel = .moderatelyActive
    var medicalCondition: MedicalCondition = .none
    var dailyCaloricLimit: Double = 2000
    var proteinGoal: Double = 50
    var carbGoal: Double = 250
    var fatGoal: Double = 65
    var fiberGoal: Double = 25
    var openAIKey: String = ""          // stored locally only — never sent to our servers
    var assignedDoctorId: String?
    var patientCode: String?             // code doctor uses to link to patient

    enum BiologicalSex: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case preferNotToSay = "Prefer not to say"
    }

    enum ActivityLevel: String, Codable, CaseIterable {
        case sedentary        = "Sedentary (little or no exercise)"
        case lightlyActive    = "Lightly Active (1–3 days/week)"
        case moderatelyActive = "Moderately Active (3–5 days/week)"
        case veryActive       = "Very Active (6–7 days/week)"
        case extraActive      = "Extra Active (physical job or 2× training)"

        var multiplier: Double {
            switch self {
            case .sedentary:        return 1.2
            case .lightlyActive:    return 1.375
            case .moderatelyActive: return 1.55
            case .veryActive:       return 1.725
            case .extraActive:      return 1.9
            }
        }
    }

    // Mifflin–St Jeor BMR estimate (returns nil if data missing)
    var estimatedBMR: Double? {
        guard let weight = weightKg, let height = heightCm, let dob = dateOfBirth else { return nil }
        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
        let base = 10 * weight + 6.25 * height - 5 * Double(age)
        switch sex {
        case .male:             return base + 5
        case .female:           return base - 161
        case .preferNotToSay:   return base - 78
        }
    }

    var estimatedTDEE: Double? {
        guard let bmr = estimatedBMR else { return nil }
        return bmr * activityLevel.multiplier
    }

    mutating func applyConditionDefaults() {
        let guidelines = medicalCondition.dietaryGuidelines
        dailyCaloricLimit = guidelines.dailyCaloricTarget
        proteinGoal = guidelines.proteinTarget
        carbGoal = guidelines.carbTarget
        fatGoal = guidelines.fatTarget
        fiberGoal = guidelines.fiberTarget
    }
}
