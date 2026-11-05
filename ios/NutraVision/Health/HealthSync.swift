import Foundation
import HealthKit
import NutraCore
import Observation

/// Apple Health import (workouts, body mass) and export (food, weight). Permission is requested only from
/// `AppleHealthView`. Writes are best-effort: they never block or fail the app's own save.
@Observable
@MainActor
final class HealthSync {
    static let shared = HealthSync()

    private static let requestedPrefix = "hk.requested."
    private static let workoutsAnchorPrefix = "hk.anchor.workouts."
    private static let bodyMassAnchorPrefix = "hk.anchor.bodyMass."

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var importing = false

    /// Bumped when the stored flag changes so views re-read `requested` and `isAuthorized`.
    private var requestTick = 0

    private var requestedKey: String? { Backend.shared.userId.map { Self.requestedPrefix + $0.uuidString } }

    /// The request sheet has completed for the signed-in user (per user, so a new account must opt in).
    var requested: Bool {
        _ = requestTick
        return requestedKey.map { UserDefaults.standard.bool(forKey: $0) } ?? false
    }

    /// Requested, and the user did not tap "Don't Allow" (HealthKit hides read access, so write status is the proxy).
    var isAuthorized: Bool {
        Self.isAvailable && requested
            && store.authorizationStatus(for: HKQuantityType(.dietaryEnergyConsumed)) == .sharingAuthorized
    }

    nonisolated static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [HKObjectType.workoutType(), HKQuantityType(.bodyMass), HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned)]
    }

    private var nutrientTypes: [HKQuantityType] {
        [HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryProtein), HKQuantityType(.dietaryCarbohydrates),
         HKQuantityType(.dietaryFatTotal), HKQuantityType(.dietaryFatSaturated), HKQuantityType(.dietarySodium),
         HKQuantityType(.dietaryFiber), HKQuantityType(.dietarySugar)]
    }

    private var shareTypes: Set<HKSampleType> {
        Set(nutrientTypes.map { $0 as HKSampleType }).union([HKQuantityType(.bodyMass) as HKSampleType])
    }

    func requestAccess() async throws {
        guard Self.isAvailable else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        if let key = requestedKey { UserDefaults.standard.set(true, forKey: key) }
        requestTick += 1
    }

    // MARK: Import

    /// Pulls workouts and weights added since the stored anchors. An anchor is saved only after its upsert succeeded.
    func importNew(userId: UUID) async throws {
        guard Self.isAvailable, isAuthorized, !importing else { return }
        importing = true
        defer { importing = false }
        try await importWorkouts(userId: userId)
        try await importWeights(userId: userId)
    }

    private func importWorkouts(userId: UUID) async throws {
        let query = HKAnchoredObjectQueryDescriptor(predicates: [.workout()], anchor: loadAnchor(Self.workoutsAnchorPrefix + userId.uuidString))
        let result = try await query.result(for: store)
        let rows = result.addedSamples.filter { !isOwn($0) }.map { w in
            WorkoutRow(userId: userId, startedAt: w.startDate, kind: Self.kind(for: w.workoutActivityType),
                       durationMin: w.duration / 60, kcal: activeKcal(of: w), distanceKm: distanceKm(of: w), notes: nil,
                       source: .healthkit, healthkitUuid: w.uuid.uuidString)
        }
        try await Backend.shared.upsertWorkouts(rows)
        saveAnchor(result.newAnchor, key: Self.workoutsAnchorPrefix + userId.uuidString)
    }

    private func importWeights(userId: UUID) async throws {
        let query = HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
                                                    anchor: loadAnchor(Self.bodyMassAnchorPrefix + userId.uuidString))
        let result = try await query.result(for: store)
        let rows = result.addedSamples.filter { !isOwn($0) }.map { s in
            WeightLogRow(userId: userId, measuredAt: s.startDate,
                         weightKg: s.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                         source: .healthkit, healthkitUuid: s.uuid.uuidString)
        }
        try await Backend.shared.upsertWeights(rows)
        saveAnchor(result.newAnchor, key: Self.bodyMassAnchorPrefix + userId.uuidString)
    }

    /// Samples this app wrote itself (its own weights) must not come back as duplicates.
    private func isOwn(_ sample: HKSample) -> Bool {
        sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private static func kind(for type: HKWorkoutActivityType) -> ExerciseKind {
        switch type {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .strength
        case .highIntensityIntervalTraining: return .hiit
        case .yoga: return .yoga
        default: return .other
        }
    }

    private func activeKcal(of workout: HKWorkout) -> Double {
        workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    private func distanceKm(of workout: HKWorkout) -> Double? {
        let ids: [HKQuantityTypeIdentifier] = [.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
        for id in ids {
            if let meters = workout.statistics(for: HKQuantityType(id))?.sumQuantity()?.doubleValue(for: .meter()) {
                return meters / 1000
            }
        }
        return nil
    }

    private func loadAnchor(_ key: String) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor, key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: Today (display only)

    func todaySteps() async -> Int? {
        guard Self.isAvailable, isAuthorized else { return nil }
        return await todaySum(.stepCount, unit: .count()).map { Int($0.rounded()) }
    }

    func todayActiveKcal() async -> Double? {
        guard Self.isAvailable, isAuthorized else { return nil }
        return await todaySum(.activeEnergyBurned, unit: .kilocalorie())
    }

    private func todaySum(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let query = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: HKQuantityType(id), predicate: predicate),
                                                options: .cumulativeSum)
        let stats = try? await query.result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: unit)
    }

    // MARK: Export (best-effort)

    func save(_ log: FoodLogRow) async {
        guard Self.isAvailable, isAuthorized else { return }
        let total = log.total
        let values: [(HKQuantityTypeIdentifier, HKUnit, Double)] = [
            (.dietaryEnergyConsumed, .kilocalorie(), total.kcal),
            (.dietaryProtein, .gram(), total.proteinG),
            (.dietaryCarbohydrates, .gram(), total.carbsG),
            (.dietaryFatTotal, .gram(), total.fatG),
            (.dietaryFatSaturated, .gram(), total.satFatG),
            (.dietarySodium, .gramUnit(with: .milli), total.sodiumMg),
            (.dietaryFiber, .gram(), total.fiberG),
            (.dietarySugar, .gram(), total.sugarG),
        ]
        // The id goes on every sample too, so `remove` finds them whether or not deleting the correlation works.
        let metadata: [String: Any] = [HKMetadataKeyExternalUUID: log.id.uuidString]
        let samples: [HKSample] = values.filter { $0.2 > 0 }.map { id, unit, value in
            HKQuantitySample(type: HKQuantityType(id), quantity: HKQuantity(unit: unit, doubleValue: value),
                             start: log.loggedAt, end: log.loggedAt, metadata: metadata)
        }
        guard !samples.isEmpty else { return }
        var foodMetadata = metadata
        foodMetadata[HKMetadataKeyFoodType] = log.name
        let food = HKCorrelation(type: HKCorrelationType(.food), start: log.loggedAt, end: log.loggedAt,
                                 objects: Set(samples), metadata: foodMetadata)
        do { try await store.save(food) } catch { debugLog("food save", error) }
    }

    func remove(_ logId: UUID) async {
        guard Self.isAvailable, isAuthorized else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID,
                                                    allowedValues: [logId.uuidString])
        let types: [HKObjectType] = [HKCorrelationType(.food)] + nutrientTypes.map { $0 as HKObjectType }
        for type in types {
            do { _ = try await store.deleteObjects(of: type, predicate: predicate) } catch { debugLog("food remove", error) }
        }
    }

    func save(_ weight: WeightLogRow) async {
        guard Self.isAvailable, isAuthorized else { return }
        let sample = HKQuantitySample(type: HKQuantityType(.bodyMass),
                                      quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weight.weightKg),
                                      start: weight.measuredAt, end: weight.measuredAt,
                                      metadata: [HKMetadataKeyExternalUUID: weight.id.uuidString])
        do { try await store.save(sample) } catch { debugLog("weight save", error) }
    }

    private func debugLog(_ what: String, _ error: Error) {
        #if DEBUG
        print("HealthSync \(what) skipped: \(error)")
        #endif
    }
}
