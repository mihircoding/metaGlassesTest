import Foundation

public enum Meal: String, Codable, CaseIterable, Sendable {
    case breakfast, lunch, dinner, snack

    public var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snacks"
        }
    }
}

public enum MealSlot {
    /// 04:00-10:59 breakfast, 11:00-14:59 lunch, 17:00-21:29 dinner, everything else snack.
    public static func meal(at date: Date, calendar: Calendar = .current) -> Meal {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        switch minutes {
        case 4 * 60 ..< 11 * 60: return .breakfast
        case 11 * 60 ..< 15 * 60: return .lunch
        case 17 * 60 ..< (21 * 60 + 30): return .dinner
        default: return .snack
        }
    }
}

public enum DayKey {
    /// "yyyy-MM-dd" in the calendar's time zone.
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        func pad(_ n: Int, _ width: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(width - s.count, 0)) + s
        }
        return "\(pad(y, 4))-\(pad(m, 2))-\(pad(d, 2))"
    }
}
