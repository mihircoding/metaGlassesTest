import Foundation
import NutraCore
import Supabase

enum BackendError: LocalizedError {
    /// The server's own words: an Edge Function's `{error}`, a Postgres exception or an auth failure.
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

/// One async method per Supabase operation. Row-level security decides what the signed-in user may touch;
/// updates to diet_plans, care_links and recommendations send only the columns the database grants.
@MainActor
final class Backend {
    static let shared = Backend()

    let client = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabaseAnonKey,
        // Emit the stored session at launch, even offline; requests refresh an expired token themselves.
        options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
    )

    private init() {}

    var userId: UUID? { client.auth.currentUser?.id }

    /// Local midnight to midnight.
    static func dayInterval(_ date: Date) -> DateInterval {
        Calendar.current.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    // MARK: Auth

    /// `full_name` and `role` become the new profile through the `handle_new_user` trigger.
    func signUp(email: String, password: String, fullName: String, role: Role) async throws {
        try await run {
            try await client.auth.signUp(email: email, password: password,
                                         data: ["full_name": .string(fullName), "role": .string(role.rawValue)])
        }
    }

    func signIn(email: String, password: String) async throws {
        try await run { try await client.auth.signIn(email: email, password: password) }
    }

    func signOut() async throws {
        try await run { try await client.auth.signOut() }
    }

    // MARK: Profiles

    func profile(id: UUID) async throws -> ProfileRow {
        try await run { try await client.from("profiles").select().eq("id", value: id).single().execute().value }
    }

    func profiles(ids: [UUID]) async throws -> [ProfileRow] {
        guard !ids.isEmpty else { return [] }
        return try await run { try await client.from("profiles").select().in("id", values: ids).execute().value }
    }

    func updateProfile(_ profile: ProfileRow) async throws {
        try await run { try await client.from("profiles").update(profile).eq("id", value: profile.id).execute() }
    }

    // MARK: Food logs

    func foodLogs(userId: UUID, day: Date) async throws -> [FoodLogRow] {
        let range = Self.dayInterval(day)
        return try await foodLogs(userId: userId, from: range.start, to: range.end)
    }

    /// Logs with `from <= logged_at < to`, oldest first.
    func foodLogs(userId: UUID, from: Date, to: Date) async throws -> [FoodLogRow] {
        // ponytail: PostgREST caps a response at 1000 rows by default (~8 months of logs); page if a range needs more.
        try await run {
            try await client.from("food_logs").select().eq("user_id", value: userId)
                .gte("logged_at", value: from).lt("logged_at", value: to)
                .order("logged_at").execute().value
        }
    }

    func insertFoodLogs(_ logs: [FoodLogRow]) async throws {
        guard !logs.isEmpty else { return }
        try await run { try await client.from("food_logs").insert(logs).execute() }
    }

    func updateFoodLog(_ log: FoodLogRow) async throws {
        try await run { try await client.from("food_logs").update(log).eq("id", value: log.id).execute() }
    }

    func deleteFoodLog(id: UUID) async throws {
        try await run { try await client.from("food_logs").delete().eq("id", value: id).execute() }
    }

    /// Newest first, one row per food name (case-insensitive).
    func recentFoods(userId: UUID, limit: Int = 30) async throws -> [FoodLogRow] {
        // ponytail: dedupes the newest limit x 5 logs on the device; a distinct-on view if that misses foods.
        let rows: [FoodLogRow] = try await run {
            try await client.from("food_logs").select().eq("user_id", value: userId)
                .order("logged_at", ascending: false).limit(limit * 5).execute().value
        }
        var seen = Set<String>()
        return Array(rows.filter { seen.insert($0.name.lowercased()).inserted }.prefix(limit))
    }

    // MARK: Custom foods

    /// The signed-in user's own foods (row-level security) whose name contains `query`.
    func customFoods(matching query: String) async throws -> [CustomFoodRow] {
        try await run {
            try await client.from("custom_foods").select().ilike("name", pattern: "%\(query)%")
                .order("name").execute().value
        }
    }

    func insertCustomFood(_ food: CustomFoodRow) async throws {
        try await run { try await client.from("custom_foods").insert(food).execute() }
    }

    // MARK: Edge Functions

    func searchFoods(query: String) async throws -> [FoodItem] {
        try await run {
            let response: FoodItems = try await client.functions.invoke("food-search", options: .init(body: ["query": query]))
            return response.items
        }
    }

    func lookupBarcode(_ code: String) async throws -> [FoodItem] {
        try await run {
            let response: FoodItems = try await client.functions.invoke("food-search", options: .init(body: ["barcode": code]))
            return response.items
        }
    }

    func analyzePhoto(jpeg: Data) async throws -> AnalyzeResult {
        try await run {
            try await client.functions.invoke("analyze-food", options: .init(body: [
                "image_base64": jpeg.base64EncodedString(),
                "media_type": "image/jpeg",
            ]))
        }
    }

    private struct FoodItems: Decodable { let items: [FoodItem] }

    // MARK: Workouts

    func workouts(userId: UUID, from: Date, to: Date) async throws -> [WorkoutRow] {
        try await run {
            try await client.from("workouts").select().eq("user_id", value: userId)
                .gte("started_at", value: from).lt("started_at", value: to)
                .order("started_at").execute().value
        }
    }

    func insertWorkout(_ workout: WorkoutRow) async throws {
        try await run { try await client.from("workouts").insert(workout).execute() }
    }

    /// Apple Health imports: a workout already stored under the same `healthkit_uuid` is left as it is.
    func upsertWorkouts(_ workouts: [WorkoutRow]) async throws {
        guard !workouts.isEmpty else { return }
        try await run {
            try await client.from("workouts")
                .upsert(workouts, onConflict: "user_id,healthkit_uuid", returning: .minimal, ignoreDuplicates: true)
                .execute()
        }
    }

    func deleteWorkout(id: UUID) async throws {
        try await run { try await client.from("workouts").delete().eq("id", value: id).execute() }
    }

    // MARK: Weights

    func weights(userId: UUID, from: Date, to: Date) async throws -> [WeightLogRow] {
        try await run {
            try await client.from("weight_logs").select().eq("user_id", value: userId)
                .gte("measured_at", value: from).lt("measured_at", value: to)
                .order("measured_at").execute().value
        }
    }

    func insertWeight(_ weight: WeightLogRow) async throws {
        try await run { try await client.from("weight_logs").insert(weight).execute() }
    }

    /// Apple Health imports: a weight already stored under the same `healthkit_uuid` is left as it is.
    func upsertWeights(_ weights: [WeightLogRow]) async throws {
        guard !weights.isEmpty else { return }
        try await run {
            try await client.from("weight_logs")
                .upsert(weights, onConflict: "user_id,healthkit_uuid", returning: .minimal, ignoreDuplicates: true)
                .execute()
        }
    }

    // MARK: Diet plans

    /// Newest first.
    func dietPlans(userId: UUID) async throws -> [DietPlanRow] {
        try await run {
            try await client.from("diet_plans").select().eq("user_id", value: userId)
                .order("created_at", ascending: false).execute().value
        }
    }

    /// Updates the plan if it exists (granted columns only), otherwise inserts it authored by the signed-in user.
    /// An active plan deactivates the user's other plans first (one active plan per user).
    func saveDietPlan(_ plan: DietPlanRow) async throws {
        try await run {
            if plan.isActive { try await deactivatePlans(userId: plan.userId, except: plan.id) }
            let edit: [String: AnyJSON] = try [
                "condition_id": plan.conditionId.map(AnyJSON.string) ?? .null,
                "name": .string(plan.name),
                "notes": plan.notes.map(AnyJSON.string) ?? .null,
                "targets": AnyJSON(plan.targets),
                "meals": AnyJSON(plan.meals),
                "is_active": .bool(plan.isActive),
            ]
            let updated: [DietPlanRow] = try await client.from("diet_plans").update(edit)
                .eq("id", value: plan.id).execute().value
            if updated.isEmpty {
                var row = plan
                row.authorId = userId ?? plan.authorId
                try await client.from("diet_plans").insert(row).execute()
            }
        }
    }

    func activatePlan(id: UUID, userId: UUID) async throws {
        try await run {
            try await deactivatePlans(userId: userId, except: id)
            try await client.from("diet_plans").update(["is_active": true]).eq("id", value: id).execute()
        }
    }

    private func deactivatePlans(userId: UUID, except id: UUID) async throws {
        try await client.from("diet_plans").update(["is_active": false])
            .eq("user_id", value: userId).eq("is_active", value: true).neq("id", value: id).execute()
    }

    // MARK: Care links (rows are created only by request_patient)

    /// Every link the signed-in doctor or patient is part of, newest first.
    func careLinks() async throws -> [CareLinkRow] {
        try await run {
            try await client.from("care_links").select().order("created_at", ascending: false).execute().value
        }
    }

    /// Doctor: ask a patient (by account email) to share their log. Fails with "No patient with that email".
    func requestPatient(email: String) async throws {
        try await run { try await client.rpc("request_patient", params: ["patient_email": email]).execute() }
    }

    /// Patient: accept or decline a pending request.
    func respondCareLink(id: UUID, accept: Bool) async throws {
        try await run {
            try await client.rpc("respond_care_link",
                                 params: ["link_id": AnyJSON.string(id.uuidString), "accept": AnyJSON.bool(accept)])
                .execute()
        }
    }

    /// Either side ends a link.
    func revokeCareLink(id: UUID) async throws {
        try await run {
            try await client.from("care_links").update(["status": CareLinkStatus.revoked]).eq("id", value: id).execute()
        }
    }

    // MARK: Recommendations

    /// Sent (doctor) or received (patient), newest first.
    func recommendations() async throws -> [RecommendationRow] {
        try await run {
            try await client.from("recommendations").select().order("created_at", ascending: false).execute().value
        }
    }

    /// Doctor only, for an accepted patient; `status` must be pending.
    func sendRecommendation(_ recommendation: RecommendationRow) async throws {
        try await run { try await client.from("recommendations").insert(recommendation).execute() }
    }

    /// Applies targets or a plan to the patient's account in one transaction.
    func acceptRecommendation(id: UUID) async throws {
        try await run { try await client.rpc("accept_recommendation", params: ["rec_id": id.uuidString]).execute() }
    }

    func declineRecommendation(id: UUID) async throws {
        try await run {
            try await client.from("recommendations").update(["status": RecommendationStatus.declined])
                .eq("id", value: id).execute()
        }
    }

    // MARK: Errors

    /// Runs one Supabase call and rethrows server failures as `BackendError.message` with the server's text.
    @discardableResult
    private func run<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch FunctionsError.httpError(_, let data) {
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw BackendError.message(body?.error ?? "Something went wrong. Please try again.")
        } catch let error as PostgrestError {
            throw BackendError.message(error.message)
        } catch let error as AuthError {
            throw BackendError.message(error.message)
        }
    }

    private struct ErrorBody: Decodable { let error: String }
}
