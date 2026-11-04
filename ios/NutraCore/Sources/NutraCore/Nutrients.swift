import Foundation

public struct Nutrients: Codable, Equatable, Sendable {
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var satFatG: Double
    public var sodiumMg: Double
    public var fiberG: Double
    public var sugarG: Double

    public init(kcal: Double = 0, proteinG: Double = 0, carbsG: Double = 0, fatG: Double = 0,
                satFatG: Double = 0, sodiumMg: Double = 0, fiberG: Double = 0, sugarG: Double = 0) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.satFatG = satFatG
        self.sodiumMg = sodiumMg
        self.fiberG = fiberG
        self.sugarG = sugarG
    }

    public static let zero = Nutrients()

    enum CodingKeys: String, CodingKey {
        case kcal
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case satFatG = "sat_fat_g"
        case sodiumMg = "sodium_mg"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
    }

    public static func + (l: Nutrients, r: Nutrients) -> Nutrients {
        Nutrients(kcal: l.kcal + r.kcal, proteinG: l.proteinG + r.proteinG, carbsG: l.carbsG + r.carbsG,
                  fatG: l.fatG + r.fatG, satFatG: l.satFatG + r.satFatG, sodiumMg: l.sodiumMg + r.sodiumMg,
                  fiberG: l.fiberG + r.fiberG, sugarG: l.sugarG + r.sugarG)
    }

    public func scaled(by factor: Double) -> Nutrients {
        Nutrients(kcal: kcal * factor, proteinG: proteinG * factor, carbsG: carbsG * factor,
                  fatG: fatG * factor, satFatG: satFatG * factor, sodiumMg: sodiumMg * factor,
                  fiberG: fiberG * factor, sugarG: sugarG * factor)
    }

    public var netCarbsG: Double { max(carbsG - fiberG, 0) }
}

extension Sequence where Element == Nutrients {
    public func sum() -> Nutrients { reduce(Nutrients.zero, +) }
}
