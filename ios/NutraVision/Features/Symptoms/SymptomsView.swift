import NutraCore
import SwiftUI

/// The patient's symptom diary for the last 30 days: a two-week chart, foods often followed by
/// symptoms, then every entry. Doctors they share with see the same entries.
struct SymptomsView: View {
    @Environment(AppModel.self) private var app
    /// Oldest first.
    @State private var rows: [SymptomLogRow] = []
    @State private var triggers = SymptomTriggers.Result(candidates: [], baseline: 0)
    @State private var loaded = false
    @State private var error: String?
    @State private var logging = false

    var body: some View {
        List {
            if let error {
                Section { InlineError(message: error) { Task { await load() } } }
            }
            if loaded && rows.isEmpty && error == nil {
                ContentUnavailableView {
                    Label("No symptoms logged", systemImage: "list.bullet.clipboard")
                } description: {
                    Text("Note how you feel, when, and how bad it is. Over a few weeks, NutraVision looks for foods that were often followed by symptoms, and your care team sees the same diary.")
                } actions: {
                    Button("Log symptoms") { logging = true }.buttonStyle(.borderedProminent)
                }
            }
            if !rows.isEmpty {
                Section("Last 14 days") { SymptomChart(rows: rows) }
            }
            if !triggers.candidates.isEmpty {
                Section {
                    TriggerRows(result: triggers)
                } header: {
                    Text("Often followed by symptoms")
                } footer: {
                    Text("A pattern in your diary, not a diagnosis. Talk to your doctor or dietitian before cutting foods out; they can help you test it safely.")
                }
            }
            if !rows.isEmpty {
                Section("Entries") {
                    ForEach(rows.reversed()) { row in
                        SymptomRowView(row: row)
                            .swipeActions {
                                Button(role: .destructive) { Task { await delete(row) } } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Symptoms")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { logging = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Log symptoms")
            }
        }
        .sheet(isPresented: $logging) { LogSymptomView() }
        .task(id: app.symptomsVersion) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let userId = Backend.shared.userId else { return }
        let now = Date()
        let from = now.addingTimeInterval(-30 * 86_400)
        do {
            rows = try await Backend.shared.symptoms(userId: userId, from: from, to: now.addingTimeInterval(86_400))
            error = nil
            // Best effort: without the diary's food, the list just has no pattern section.
            if !rows.isEmpty, let logs = try? await Backend.shared.foodLogs(userId: userId, from: from, to: now) {
                triggers = SymptomTriggers.analyze(meals: logs.map { (name: $0.name, time: $0.loggedAt) },
                                                   symptoms: rows.map(\.entry), asOf: now)
            }
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func delete(_ row: SymptomLogRow) async {
        do {
            try await Backend.shared.deleteSymptom(id: row.id)
            rows.removeAll { $0.id == row.id }
            app.symptomsVersion += 1
        } catch {
            self.error = error.localizedDescription
        }
    }
}
