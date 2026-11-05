import Foundation
import NutraCore
import Observation

/// One local day (midnight to midnight) of a user's food logs and workouts.
@Observable
@MainActor
final class DayModel {
    let userId: UUID
    var date: Date
    var logs: [FoodLogRow] = []
    var workouts: [WorkoutRow] = []

    var consumed: Nutrients { logs.map(\.total).sum() }
    var exerciseKcal: Double { workouts.reduce(0) { $0 + $1.kcal } }

    init(userId: UUID, date: Date) {
        self.userId = userId
        self.date = date
    }

    func load() async throws {
        let day = Backend.dayInterval(date)
        logs = try await Backend.shared.foodLogs(userId: userId, from: day.start, to: day.end)
        workouts = try await Backend.shared.workouts(userId: userId, from: day.start, to: day.end)
    }
}
