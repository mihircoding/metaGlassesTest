import Charts
import NutraCore
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var app
    @State private var weights: [WeightLogRow] = []
    @State private var weightError: String?
    @State private var glassesMode: GlassesSource?
    @State private var careTeam = CareTeamModel()
    @State private var steps: Int?
    @State private var activeKcal: Double?
    /// When food was logged over the last 90 days before today; today's logs come live from `app.today`.
    @State private var earlierLogTimes: [Date] = []
    /// The newest blood pressure and blood sugar readings from the last 30 days.
    @State private var latestBloodPressure: VitalLogRow?
    @State private var latestGlucose: VitalLogRow?
    @AppStorage(GlucoseUnit.storageKey) private var glucoseUnit = GlucoseUnit.mgDl

    /// Conditions where blood pressure or blood sugar is part of routine care.
    private static let vitalsConditions: Set<String> = ["t1_diabetes", "t2_diabetes", "hypertension", "heart_disease", "ckd"]
    private var showsVitals: Bool {
        latestBloodPressure != nil || latestGlucose != nil
            || !Self.vitalsConditions.isDisjoint(with: app.profile?.conditions ?? [])
    }

    private var streak: Int {
        LoggingStreak.days(logged: earlierLogTimes + (app.today?.logs.map(\.loggedAt) ?? []), today: Date())
    }

    private var consumed: Nutrients { app.today?.consumed ?? .zero }
    private var exercise: Double { app.today?.exerciseKcal ?? 0 }
    private var goal: Double { app.goalKcal(for: app.today) }
    private var remaining: Double { goal - consumed.kcal }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let text = careTeam.bannerText {
                        NavigationLink { CareTeamView() } label: {
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text(text).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Theme.accent2, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    ring
                    Menu {
                        Button("Meta glasses", systemImage: "eyeglasses") { glassesMode = .glasses }
                        Button("Phone camera", systemImage: "iphone") { glassesMode = .phone }
                    } label: {
                        Label("Glasses Mode", systemImage: "eyeglasses").font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.large)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MacroCard(title: "Protein", value: consumed.proteinG, target: app.targets.proteinG, unit: "g")
                        MacroCard(title: "Carbs", value: consumed.carbsG, target: app.targets.carbsG, unit: "g")
                        MacroCard(title: "Fat", value: consumed.fatG, target: app.targets.fatG, unit: "g")
                        MacroCard(title: "Sat fat", value: consumed.satFatG, target: app.targets.satFatG, unit: "g", warnOver: true)
                        MacroCard(title: "Sodium", value: consumed.sodiumMg, target: app.targets.sodiumMg, unit: "mg", warnOver: true)
                        exerciseTile
                        if HealthSync.shared.isAuthorized {
                            healthTile("Steps", steps.map { $0.formatted() } ?? "–", "today")
                            healthTile("Active energy", activeKcal.map { "\(Int($0.rounded())) kcal" } ?? "–", "Apple Health")
                        }
                    }
                    if streak >= 2 { streakCard }
                    if showsVitals { vitalsCard }
                    FluidCard()
                    weightCard
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await app.refresh()
                await careTeam.load()
                await loadWeights()
                await loadEarlierLogs()
                await loadVitals()
            }
            // Re-fetched when the day rolls over, so yesterday moves into the history.
            .task(id: DayKey.key(for: app.today?.date ?? Date())) { await loadEarlierLogs() }
            .task(id: app.weightsVersion) { await loadWeights() }
            .task(id: app.vitalsVersion) { await loadVitals() }
            .task(id: app.today?.consumed.kcal) { await loadHealth() }  // display only, not added to the goal
            .onAppear { Task { await loadHealth() } }  // after connecting from More
            .onAppear { Task { await careTeam.load() } }  // reload when returning from Care Team
            .fullScreenCover(item: $glassesMode) { mode in GlassesModeView(useGlasses: mode == .glasses) }
        }
    }

    /// "From 84.1 kg to 82.0 kg", for VoiceOver.
    private var weightSummary: String {
        guard let first = weights.first, let last = weights.last else { return "" }
        let f = { (kg: Double) in kg.formatted(.number.precision(.fractionLength(1))) }
        return "From \(f(first.weightKg)) kg to \(f(last.weightKg)) kg"
    }

    private var streakCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill").font(.title3).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak)-day logging streak").font(.subheadline.weight(.semibold))
                Text(app.today?.logs.isEmpty == false ? "Logged today. Keep it going!" : "Log something today to keep it going.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    /// Best effort: without it the streak card just stays hidden.
    private func loadEarlierLogs() async {
        guard let userId = Backend.shared.userId else { return }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard let from = Calendar.current.date(byAdding: .day, value: -90, to: startOfToday) else { return }
        if let logs = try? await Backend.shared.foodLogs(userId: userId, from: from, to: startOfToday) {
            earlierLogTimes = logs.map(\.loggedAt)
        }
    }

    private var vitalsCard: some View {
        NavigationLink { VitalsView() } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Vitals", systemImage: "heart.text.square").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.bad)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                HStack(alignment: .top, spacing: 12) {
                    vitalTile("Blood pressure", latestBloodPressure.flatMap { v in
                        v.systolic.flatMap { s in v.diastolic.map { d in "\(s)/\(d)" } }
                    }, latestBloodPressure?.bloodPressureCategory.map { ($0.title, $0.color) })
                    vitalTile("Blood sugar", latestGlucose?.glucoseMgDl.map(glucoseUnit.format),
                              latestGlucose?.glucoseCategory.map { ($0.title, $0.color) })
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows your readings and lets you log a new one")
    }

    private func vitalTile(_ title: String, _ value: String?, _ category: (String, Color)?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            Text(value ?? "Tap to log").font(value == nil ? Font.subheadline : Font.headline.monospacedDigit())
                .foregroundStyle(value == nil ? Color.secondary : Color.primary)
            if let category { CategoryChip(title: category.0, color: category.1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Best effort: without it the card shows "Tap to log".
    private func loadVitals() async {
        guard let userId = Backend.shared.userId else { return }
        let now = Date()
        guard let rows = try? await Backend.shared.vitals(userId: userId, from: now.addingTimeInterval(-30 * 86_400),
                                                           to: now.addingTimeInterval(86_400)) else { return }
        latestBloodPressure = rows.last { $0.kind == .bloodPressure }
        latestGlucose = rows.last { $0.kind == .glucose }
    }

    private var exerciseTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Exercise").font(.footnote).foregroundStyle(.secondary)
            Text("\(Int(exercise.rounded())) kcal").font(.headline)
            Text("burned today").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func healthTile(_ title: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            Text(value).font(.headline)
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func loadHealth() async {
        steps = await HealthSync.shared.todaySteps()
        activeKcal = await HealthSync.shared.todayActiveKcal()
    }

    private var ring: some View {
        let fraction = goal > 0 ? min(max(consumed.kcal / goal, 0), 1) : 0
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 16)
            Circle().trim(from: 0, to: fraction)
                .stroke(remaining < 0 ? Theme.bad : Theme.accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack {
                Text("\(Int(abs(remaining).rounded()))").font(.system(size: 40, weight: .bold))
                Text(remaining < 0 ? "kcal over" : "kcal remaining").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var weightCard: some View {
        if let weightError {
            HStack {
                Text(weightError).font(.footnote).foregroundStyle(Theme.bad)
                Spacer()
                Button("Retry") { Task { await loadWeights() } }.buttonStyle(.bordered)
            }
        } else if weights.count >= 2 {
            NavigationLink { WeightHistoryView() } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Weight, last 30 days").font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    Chart(weights) { w in
                        LineMark(x: .value("Date", w.measuredAt), y: .value("kg", w.weightKg))
                            .foregroundStyle(Theme.accent)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    // Three date labels fit; four ran off the edge ("Nov…").
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .frame(height: 80)
                    .accessibilityLabel("Weight over the last 30 days")
                    .accessibilityValue(weightSummary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows every weigh-in")
        }
    }

    private func loadWeights() async {
        guard let userId = Backend.shared.userId else { return }
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        do {
            weights = try await Backend.shared.weights(userId: userId, from: from, to: now.addingTimeInterval(86_400))
            weightError = nil
        } catch {
            if Task.isCancelled { return }
            weightError = error.localizedDescription
        }
    }
}
