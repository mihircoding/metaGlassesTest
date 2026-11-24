import NutraCore
import SwiftUI

/// Today's drinks with one-tap amounts, against the patient's fluid limit when they have one
/// (common with kidney disease, heart failure and cirrhosis).
struct FluidCard: View {
    @Environment(AppModel.self) private var app
    @State private var drinks: [FluidLogRow] = []
    @State private var busy = false
    @State private var error: String?

    private static let amounts = [150, 250, 500]

    private var total: Double { drinks.reduce(0) { $0 + $1.ml } }
    private var limit: Double? { app.profile?.fluidLimitMl }
    private var over: Bool { limit.map { total > $0 } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Fluids", systemImage: "drop.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.blue)
                Spacer()
                Text(totalText).font(.subheadline.monospacedDigit()).foregroundStyle(over ? Theme.bad : .secondary)
            }
            if let limit {
                ProgressView(value: min(total, limit), total: limit)
                    .tint(over ? Theme.bad : .blue)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 8) {
                ForEach(Self.amounts, id: \.self) { ml in
                    Button("+\(ml) ml") { Task { await add(Double(ml)) } }
                        .buttonStyle(.bordered).controlSize(.small).tint(.blue)
                        .accessibilityLabel("Add \(ml) milliliters")
                }
                Spacer()
                if let last = drinks.last {
                    Button { Task { await undo(last) } } label: { Image(systemName: "arrow.uturn.backward") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Undo last drink, \(Int(last.ml)) milliliters")
                }
            }
            .disabled(busy)
            if over, let limit {
                Text("Over your daily limit of \(Int(limit)) ml.").font(.caption).foregroundStyle(Theme.bad)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(Theme.bad)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .task(id: DayKey.key(for: app.today?.date ?? Date())) { await load() }  // and again after midnight
    }

    private var totalText: String {
        let t = Int(total.rounded())
        if let limit { return "\(t) / \(Int(limit)) ml" }
        return "\(t) ml today"
    }

    private func load() async {
        guard let userId = Backend.shared.userId else { return }
        let day = Backend.dayInterval(Date())
        do {
            drinks = try await Backend.shared.fluids(userId: userId, from: day.start, to: day.end)
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }

    private func add(_ ml: Double) async {
        guard let userId = Backend.shared.userId else { return }
        busy = true
        defer { busy = false }
        let row = FluidLogRow(userId: userId, loggedAt: Date(), ml: ml)
        do {
            try await Backend.shared.insertFluid(row)
            drinks.append(row)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func undo(_ row: FluidLogRow) async {
        busy = true
        defer { busy = false }
        do {
            try await Backend.shared.deleteFluid(id: row.id)
            drinks.removeAll { $0.id == row.id }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
