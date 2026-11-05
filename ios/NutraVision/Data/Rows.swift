import Foundation
import NutraCore

// Swift mirrors of the tables in supabase/migrations/0001_init.sql. Keys are spelled out (no global key
// strategy); nutrient and target columns are flattened into the row the way `PlanItem` does it.
// `created_at` is never read. Custom Codable lives in extensions so each row keeps its memberwise init.

enum Role: String, Codable { case patient, doctor }

enum TargetsSource: String, Codable { case auto, custom, doctor }

enum FoodSource: String, Codable { case manual, search, barcode, glassesAI = "glasses_ai", photoAI = "photo_ai", plan }

/// Where a workout or weight entry came from.
enum EntrySource: String, Codable { case manual, healthkit }

// MARK: - profiles

struct ProfileRow: Codable, Identifiable, Equatable {
    var id: UUID
    var role: Role
    var fullName: String
    var email: String
    var birthDate: String?  // Postgres date, "yyyy-MM-dd"
    var sex: Sex
    var heightCm: Double?
    var weightKg: Double?
    var activity: Activity
    var conditions: [String]  // ConditionCatalog ids, first = primary
    var goalWeightKg: Double?
    var weeklyRateKg: Double
    var targets: Targets
    var targetsSource: TargetsSource
    var addExerciseKcal: Bool
    var specialty: String?
    var licenseNumber: String?

    var bodyStats: BodyStats {
        BodyStats(sex: sex, birthDate: birthDate.flatMap(Self.date(fromDay:)), heightCm: heightCm,
                  weightKg: weightKg, activity: activity)
    }

    /// "yyyy-MM-dd" to midnight UTC, the calendar `TargetCalculator` counts age in.
    static func date(fromDay day: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withFullDate
        return formatter.date(from: day)
    }

    enum CodingKeys: String, CodingKey {
        case id, role, email, sex, activity, conditions, specialty
        case fullName = "full_name"
        case birthDate = "birth_date"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case goalWeightKg = "goal_weight_kg"
        case weeklyRateKg = "weekly_rate_kg"
        case targetsSource = "targets_source"
        case addExerciseKcal = "add_exercise_kcal"
        case licenseNumber = "license_number"
    }
}

extension ProfileRow {
    /// New sign-ups and doctors have null body columns; those decode to neutral defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(Role.self, forKey: .role)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        birthDate = try c.decodeIfPresent(String.self, forKey: .birthDate)
        sex = try c.decodeIfPresent(Sex.self, forKey: .sex) ?? .unspecified
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        activity = try c.decodeIfPresent(Activity.self, forKey: .activity) ?? .sedentary
        conditions = try c.decode([String].self, forKey: .conditions)
        goalWeightKg = try c.decodeIfPresent(Double.self, forKey: .goalWeightKg)
        weeklyRateKg = try c.decodeIfPresent(Double.self, forKey: .weeklyRateKg) ?? 0
        targets = try Targets(from: decoder)
        targetsSource = try c.decode(TargetsSource.self, forKey: .targetsSource)
        addExerciseKcal = try c.decode(Bool.self, forKey: .addExerciseKcal)
        specialty = try c.decodeIfPresent(String.self, forKey: .specialty)
        licenseNumber = try c.decodeIfPresent(String.self, forKey: .licenseNumber)
    }

    /// Every editable column, nil as null. `role` and `email` are never sent: a trigger rejects changing them.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(fullName, forKey: .fullName)
        try c.encode(birthDate, forKey: .birthDate)
        try c.encode(sex, forKey: .sex)
        try c.encode(heightCm, forKey: .heightCm)
        try c.encode(weightKg, forKey: .weightKg)
        try c.encode(activity, forKey: .activity)
        try c.encode(conditions, forKey: .conditions)
        try c.encode(goalWeightKg, forKey: .goalWeightKg)
        try c.encode(weeklyRateKg, forKey: .weeklyRateKg)
        try targets.encode(to: encoder)
        try c.encode(targetsSource, forKey: .targetsSource)
        try c.encode(addExerciseKcal, forKey: .addExerciseKcal)
        try c.encode(specialty, forKey: .specialty)
        try c.encode(licenseNumber, forKey: .licenseNumber)
    }
}

// MARK: - food_logs, custom_foods

struct FoodLogRow: Codable, Identifiable, Equatable {
    var id = UUID()
    var userId: UUID
    var loggedAt: Date
    var meal: Meal
    var name: String
    var brand: String?
    var servingDesc: String
    var servingGrams: Double?
    var servings: Double
    var perServing: Nutrients
    var source: FoodSource
    var sourceRef: String?
    var aiConfidence: String?
    var scanId: UUID?

    var total: Nutrients { perServing.scaled(by: servings) }

    enum CodingKeys: String, CodingKey {
        case id, meal, name, brand, servings, source
        case userId = "user_id"
        case loggedAt = "logged_at"
        case servingDesc = "serving_desc"
        case servingGrams = "serving_grams"
        case sourceRef = "source_ref"
        case aiConfidence = "ai_confidence"
        case scanId = "scan_id"
    }
}

extension FoodLogRow {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        loggedAt = try c.decode(Date.self, forKey: .loggedAt)
        meal = try c.decode(Meal.self, forKey: .meal)
        name = try c.decode(String.self, forKey: .name)
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        servingDesc = try c.decodeIfPresent(String.self, forKey: .servingDesc) ?? ""
        servingGrams = try c.decodeIfPresent(Double.self, forKey: .servingGrams)
        servings = try c.decode(Double.self, forKey: .servings)
        perServing = try Nutrients(from: decoder)
        source = try c.decode(FoodSource.self, forKey: .source)
        sourceRef = try c.decodeIfPresent(String.self, forKey: .sourceRef)
        aiConfidence = try c.decodeIfPresent(String.self, forKey: .aiConfidence)
        scanId = try c.decodeIfPresent(UUID.self, forKey: .scanId)
    }

    /// Every column, nil as null, so a bulk insert sends the same keys for each row and an update can clear a field.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encode(loggedAt, forKey: .loggedAt)
        try c.encode(meal, forKey: .meal)
        try c.encode(name, forKey: .name)
        try c.encode(brand, forKey: .brand)
        try c.encode(servingDesc, forKey: .servingDesc)
        try c.encode(servingGrams, forKey: .servingGrams)
        try c.encode(servings, forKey: .servings)
        try perServing.encode(to: encoder)
        try c.encode(source, forKey: .source)
        try c.encode(sourceRef, forKey: .sourceRef)
        try c.encode(aiConfidence, forKey: .aiConfidence)
        try c.encode(scanId, forKey: .scanId)
    }
}

struct CustomFoodRow: Codable, Identifiable, Equatable {
    var id = UUID()
    var userId: UUID
    var name: String
    var brand: String?
    var servingDesc: String
    var servingGrams: Double?
    var perServing: Nutrients

    enum CodingKeys: String, CodingKey {
        case id, name, brand
        case userId = "user_id"
        case servingDesc = "serving_desc"
        case servingGrams = "serving_grams"
    }
}

extension CustomFoodRow {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        servingDesc = try c.decodeIfPresent(String.self, forKey: .servingDesc) ?? ""
        servingGrams = try c.decodeIfPresent(Double.self, forKey: .servingGrams)
        perServing = try Nutrients(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encode(name, forKey: .name)
        try c.encode(brand, forKey: .brand)
        try c.encode(servingDesc, forKey: .servingDesc)
        try c.encode(servingGrams, forKey: .servingGrams)
        try perServing.encode(to: encoder)
    }
}

// MARK: - workouts, weight_logs

struct WorkoutRow: Codable, Identifiable, Equatable {
    var id = UUID()
    var userId: UUID
    var startedAt: Date
    var kind: ExerciseKind
    var durationMin: Double
    var kcal: Double
    var distanceKm: Double?
    var notes: String?
    var source: EntrySource
    var healthkitUuid: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, kcal, notes, source
        case userId = "user_id"
        case startedAt = "started_at"
        case durationMin = "duration_min"
        case distanceKm = "distance_km"
        case healthkitUuid = "healthkit_uuid"
    }
}

struct WeightLogRow: Codable, Identifiable, Equatable {
    var id = UUID()
    var userId: UUID
    var measuredAt: Date
    var weightKg: Double
    var source: EntrySource
    var healthkitUuid: String?

    enum CodingKeys: String, CodingKey {
        case id, source
        case userId = "user_id"
        case measuredAt = "measured_at"
        case weightKg = "weight_kg"
        case healthkitUuid = "healthkit_uuid"
    }
}

// MARK: - diet_plans

struct DietPlanRow: Codable, Identifiable, Equatable {
    var id = UUID()
    var userId: UUID
    var authorId: UUID
    var conditionId: String?
    var name: String
    var notes: String?
    var targets: Targets  // jsonb, same keys as the profile targets
    var meals: [PlanMeal]  // jsonb
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, notes, targets, meals
        case userId = "user_id"
        case authorId = "author_id"
        case conditionId = "condition_id"
        case isActive = "is_active"
    }
}

// MARK: - care_links, recommendations

enum CareLinkStatus: String, Codable { case pending, accepted, declined, revoked }

struct CareLinkRow: Codable, Identifiable, Equatable {
    var id: UUID
    var doctorId: UUID
    var patientId: UUID
    var patientEmail: String?  // as the doctor typed it
    var status: CareLinkStatus
    var respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case doctorId = "doctor_id"
        case patientId = "patient_id"
        case patientEmail = "patient_email"
        case respondedAt = "responded_at"
    }
}

enum RecommendationKind: String, Codable { case targets, dietPlan = "diet_plan", note }

enum RecommendationStatus: String, Codable { case pending, accepted, declined }

/// `{targets}` | `{diet_plan}` | `{}` (a note).
struct RecommendationPayload: Codable, Equatable {
    var targets: Targets?
    var dietPlan: DietPlanDraft?

    enum CodingKeys: String, CodingKey {
        case targets
        case dietPlan = "diet_plan"
    }
}

/// The plan `accept_recommendation` copies into the patient's diet_plans.
struct DietPlanDraft: Codable, Equatable {
    var name: String
    var conditionId: String
    var notes: String
    var targets: Targets
    var meals: [PlanMeal]

    enum CodingKeys: String, CodingKey {
        case name, notes, targets, meals
        case conditionId = "condition_id"
    }
}

struct RecommendationRow: Codable, Identifiable, Equatable {
    var id = UUID()
    var doctorId: UUID
    var patientId: UUID
    var kind: RecommendationKind
    var payload: RecommendationPayload
    var message: String?
    var status: RecommendationStatus = .pending
    var respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, payload, message, status
        case doctorId = "doctor_id"
        case patientId = "patient_id"
        case respondedAt = "responded_at"
    }
}
