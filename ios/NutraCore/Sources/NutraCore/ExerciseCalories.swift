import Foundation

public enum ExerciseKind: String, Codable, CaseIterable, Sendable {
    case running, walking, cycling, swimming, strength, hiit, yoga, other

    /// Metabolic equivalent of task.
    public var met: Double {
        switch self {
        case .running: return 9.8
        case .walking: return 3.5
        case .cycling: return 7.5
        case .swimming: return 6.0
        case .strength: return 5.0
        case .hiit: return 8.0
        case .yoga: return 2.5
        case .other: return 4.0
        }
    }

    public var title: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .strength: return "Strength"
        case .hiit: return "HIIT"
        case .yoga: return "Yoga"
        case .other: return "Other"
        }
    }

    /// SF Symbol name.
    public var symbol: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .strength: return "dumbbell"
        case .hiit: return "bolt.heart"
        case .yoga: return "figure.yoga"
        case .other: return "figure.mixed.cardio"
        }
    }

    /// An unknown stored value reads as `.other` so one odd row cannot fail a whole list.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ExerciseKind(rawValue: raw) ?? .other
    }
}

public enum ExerciseCalories {
    /// kcal = MET x kg x hours, whole number. No known weight counts as 70 kg.
    public static func kcal(kind: ExerciseKind, minutes: Double, weightKg: Double?) -> Double {
        (kind.met * (weightKg ?? 70) * minutes / 60).rounded()
    }
}
