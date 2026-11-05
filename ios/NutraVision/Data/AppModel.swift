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
    /// Bumped when a weight is logged so the Dashboard sparkline reloads.
    var weightsVersion = 0

    struct DoctorCredentials { var specialty: String; var license: String }
    /// Set by sign-up before the account exists; written to the doctor profile on first load (retried by refresh()).
    var pendingDoctorCredentials: DoctorCredentials?

    var targets: Targets { profile?.targets ?? .defaults }

    /// The calorie target, plus today's exercise when the profile adds it back.
    var dailyGoalKcal: Double { goalKcal(for: today) }

    /// Exercise kcal that count toward the goal for `day`: zero unless the profile adds exercise back.
    func countedExerciseKcal(for day: DayModel?) -> Double {
        Self.countedExerciseKcal(addExerciseKcal: profile?.addExerciseKcal == true, day: day)
    }

    /// The one goal definition: kcal target plus that day's counted exercise.
    func goalKcal(for day: DayModel?) -> Double {
        Self.goalKcal(targets: targets, addExerciseKcal: profile?.addExerciseKcal == true, day: day)
    }

    static func countedExerciseKcal(addExerciseKcal: Bool, day: DayModel?) -> Double {
        addExerciseKcal ? (day?.exerciseKcal ?? 0) : 0
    }

    /// Also used for a patient's profile in the doctor's read-only diary.
    static func goalKcal(targets: Targets, addExerciseKcal: Bool, day: DayModel?) -> Double {
        targets.kcal + countedExerciseKcal(addExerciseKcal: addExerciseKcal, day: day)
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
            var profile = try await Backend.shared.profile(id: userId)
            if profile.role == .doctor, let creds = pendingDoctorCredentials {
                profile.specialty = creds.specialty
                profile.licenseNumber = creds.license
                try await Backend.shared.updateProfile(profile)
                pendingDoctorCredentials = nil
            }
            banner = nil
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
