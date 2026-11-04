import Foundation
import NutraCore
import Observation
import Supabase

/// App-wide state: who is signed in, their profile and today's totals.
@Observable
@MainActor
final class AppModel {
    enum Phase { case loading, signedOut, onboarding, patient, doctor }

    var phase: Phase = .loading
    var profile: ProfileRow?
    var today: DayModel?
    var banner: String?

    var targets: Targets { profile?.targets ?? .defaults }

    /// The calorie target, plus today's exercise when the profile adds it back.
    var dailyGoalKcal: Double {
        targets.kcal + (profile?.addExerciseKcal == true ? (today?.exerciseKcal ?? 0) : 0)
    }

    /// Follows the auth state for the app's lifetime; call once from the root view's `.task`.
    func start() async {
        for await (event, session) in Backend.shared.client.auth.authStateChanges {
            if let session {
                if event == .initialSession || event == .signedIn { await load(userId: session.user.id) }
            } else {
                profile = nil
                today = nil
                phase = .signedOut
            }
        }
    }

    /// Saves the profile, recomputing targets first while they are automatic.
    func saveProfile(_ profile: ProfileRow) async throws {
        var updated = profile
        if updated.targetsSource == .auto {
            updated.targets = TargetCalculator.targets(stats: updated.bodyStats, conditionIds: updated.conditions,
                                                       weeklyRateKg: updated.weeklyRateKg)
        }
        try await Backend.shared.updateProfile(updated)
        self.profile = updated
        if updated.role == .patient { phase = updated.heightCm == nil ? .onboarding : .patient }
    }

    func refresh() async {
        guard let userId = Backend.shared.userId else { return }
        await load(userId: userId)
    }

    private func load(userId: UUID) async {
        do {
            let profile = try await Backend.shared.profile(id: userId)
            self.profile = profile
            guard profile.role == .patient else {
                today = nil
                phase = .doctor
                return
            }
            phase = profile.heightCm == nil ? .onboarding : .patient
            // Keep today's model on refresh; start a new one after midnight or for another user.
            if today?.userId != userId || !Calendar.current.isDateInToday(today?.date ?? .distantPast) {
                today = DayModel(userId: userId, date: Date())
            }
            try await today?.load()
        } catch {
            banner = error.localizedDescription
        }
    }
}
