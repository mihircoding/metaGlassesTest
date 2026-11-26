import Foundation

/// How many days in a row the user has logged food.
public enum LoggingStreak {
    /// Consecutive days with at least one log, counting back from `today`. A day not logged *yet* doesn't break
    /// the streak: if today is empty, counting starts from yesterday. Returns 0 when neither has a log.
    public static func days(logged: [Date], today: Date, calendar: Calendar = .current) -> Int {
        let keys = Set(logged.map { DayKey.key(for: $0, calendar: calendar) })
        var day = calendar.startOfDay(for: today)
        if !keys.contains(DayKey.key(for: day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while keys.contains(DayKey.key(for: day, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
