import Foundation
import NutraCore

/// A patient's food log as a CSV file a doctor can open in a spreadsheet or attach to a chart note.
@MainActor
enum DiaryExport {
    static let days = 30

    /// Fetches the last `days` days of `patient`'s food log and writes it to a temporary .csv file.
    static func file(for patient: ProfileRow) async throws -> URL {
        let end = Backend.dayInterval(Date()).end
        let from = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        let logs = try await Backend.shared.foodLogs(userId: patient.id, from: from, to: end)
        let csv = CSV.document(header: header, rows: logs.map(row))
        let name = (patient.fullName.isEmpty ? "patient" : patient.fullName)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-food-log-\(DayKey.key(for: Date())).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static let header = ["date", "time", "meal", "food", "brand", "serving", "servings",
                                 "kcal", "protein_g", "carbs_g", "fat_g", "sat_fat_g", "sodium_mg", "fiber_g", "sugar_g"]

    /// 24-hour "HH:mm" in the device's time zone, whatever the user's 12/24-hour setting.
    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static func row(_ log: FoodLogRow) -> [String] {
        let n = log.total
        return [DayKey.key(for: log.loggedAt), timeFormat.string(from: log.loggedAt), log.meal.title,
                CSV.text(log.name), CSV.text(log.brand ?? ""), CSV.text(log.servingDesc),
                number(log.servings, 2), number(n.kcal, 0), number(n.proteinG, 1), number(n.carbsG, 1), number(n.fatG, 1),
                number(n.satFatG, 1), number(n.sodiumMg, 0), number(n.fiberG, 1), number(n.sugarG, 1)]
    }

    /// Fixed "." decimal separator whatever the locale, so spreadsheets parse it.
    private static func number(_ value: Double, _ digits: Int) -> String {
        String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
