import SwiftUI

/// Every weigh-in from the last year, newest first. Swipe to delete one logged by mistake.
struct WeightHistoryView: View {
    @Environment(AppModel.self) private var app
    @State private var weights: [WeightLogRow] = []
    @State private var loaded = false
    @State private var error: String?
    @State private var showLog = false

    var body: some View {
        List {
            if let error {
                Section {
                    Text(error).font(.footnote).foregroundStyle(Theme.bad)
                    Button("Retry") { Task { await load() } }.buttonStyle(.bordered)
                }
            }
            if loaded && weights.isEmpty && error == nil {
                ContentUnavailableView("No weigh-ins yet", systemImage: "scalemass",
                                       description: Text("Log your weight to see your trend here."))
            }
            Section {
                ForEach(weights) { w in
                    HStack {
                        Text(w.measuredAt, format: .dateTime.day().month().year())
                        if w.source == .healthkit { HealthHeart() }
                        Spacer()
                        Text("\(w.weightKg, format: .number.precision(.fractionLength(1))) kg")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .swipeActions {
                        Button(role: .destructive) { Task { await delete(w) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                if weights.contains(where: { $0.source == .healthkit }) || HealthSync.shared.isAuthorized {
                    Text("Deleting a weigh-in here doesn't remove it from Apple Health.")
                }
            }
        }
        .navigationTitle("Weight")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showLog = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Log weight")
            }
        }
        .sheet(isPresented: $showLog) { LogWeightView {} }  // it bumps weightsVersion, which reloads this list
        .task(id: app.weightsVersion) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId = Backend.shared.userId else { return }
        let now = Date()
        do {
            let rows = try await Backend.shared.weights(userId: userId, from: now.addingTimeInterval(-366 * 86_400),
                                                        to: now.addingTimeInterval(86_400))
            weights = rows.reversed()
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func delete(_ weight: WeightLogRow) async {
        do {
            try await Backend.shared.deleteWeight(id: weight.id)
            weights.removeAll { $0.id == weight.id }
            app.weightsVersion += 1  // the dashboard sparkline and trend charts reload
        } catch {
            self.error = error.localizedDescription
        }
    }
}
