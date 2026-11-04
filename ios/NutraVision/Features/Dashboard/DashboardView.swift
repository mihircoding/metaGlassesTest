import Charts
import NutraCore
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var app
    @State private var weights: [WeightLogRow] = []
    @State private var weightError: String?

    private var consumed: Nutrients { app.today?.consumed ?? .zero }
    private var exercise: Double { app.today?.exerciseKcal ?? 0 }
    private var goal: Double { app.goalKcal(for: app.today) }
    private var remaining: Double { goal - consumed.kcal }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ring
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MacroCard(title: "Protein", value: consumed.proteinG, target: app.targets.proteinG, unit: "g")
                        MacroCard(title: "Carbs", value: consumed.carbsG, target: app.targets.carbsG, unit: "g")
                        MacroCard(title: "Fat", value: consumed.fatG, target: app.targets.fatG, unit: "g")
                        MacroCard(title: "Sat fat", value: consumed.satFatG, target: app.targets.satFatG, unit: "g", warnOver: true)
                        MacroCard(title: "Sodium", value: consumed.sodiumMg, target: app.targets.sodiumMg, unit: "mg", warnOver: true)
                        exerciseTile
                    }
                    weightCard
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task { await loadWeights() }
        }
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
            VStack(alignment: .leading, spacing: 6) {
                Text("Weight, last 30 days").font(.footnote).foregroundStyle(.secondary)
                Chart(weights) { w in
                    LineMark(x: .value("Date", w.measuredAt), y: .value("kg", w.weightKg))
                        .foregroundStyle(Theme.accent)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 80)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
