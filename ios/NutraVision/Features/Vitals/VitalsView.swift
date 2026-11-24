import NutraCore
import SwiftUI

/// The patient's blood pressure and blood sugar over the last 90 days: charts, then every reading.
/// Doctors they share with see the same readings.
struct VitalsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(GlucoseUnit.storageKey) private var unit = GlucoseUnit.mgDl
    /// Oldest first.
    @State private var vitals: [VitalLogRow] = []
    @State private var loaded = false
    @State private var error: String?
    @State private var logging: VitalKind?

    private var bloodPressure: [VitalLogRow] { vitals.filter { $0.kind == .bloodPressure } }
    private var glucose: [VitalLogRow] { vitals.filter { $0.kind == .glucose } }

    var body: some View {
        List {
            if let error {
                Section { InlineError(message: error) { Task { await load() } } }
            }
            if loaded && vitals.isEmpty && error == nil {
                ContentUnavailableView {
                    Label("No readings yet", systemImage: "heart.text.square")
                } description: {
                    Text("Log your blood pressure or blood sugar to see your trends, and to share them with your care team.")
                } actions: {
                    Button("Log blood pressure") { logging = .bloodPressure }.buttonStyle(.borderedProminent)
                    Button("Log blood sugar") { logging = .glucose }.buttonStyle(.bordered)
                }
            }
            if !bloodPressure.isEmpty {
                Section {
                    BloodPressureChart(readings: bloodPressure)
                    ForEach(bloodPressure.reversed()) { row($0) }
                } header: {
                    Text("Blood pressure")
                } footer: {
                    Text("Dashed lines: 130/80, the goal for most adults on treatment. Your doctor may set a different one.")
                }
            }
            if !glucose.isEmpty {
                Section {
                    GlucoseChart(readings: glucose, unit: unit)
                    ForEach(glucose.reversed()) { row($0) }
                } header: {
                    Text("Blood sugar")
                } footer: {
                    Text("Dashed lines: \(unit.format(70)) and \(unit.format(180)). Targets for most adults with diabetes are \(unit.format(80))–\(unit.format(130)) before meals and under \(unit.format(180)) after.")
                }
            }
            if !vitals.isEmpty {
                Section {
                    Text("NutraVision is not medical advice. Follow the plan your doctor gave you.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Vitals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Blood pressure", systemImage: "heart") { logging = .bloodPressure }
                    Button("Blood sugar", systemImage: "drop") { logging = .glucose }
                    Picker("Blood sugar unit", selection: $unit) {
                        ForEach(GlucoseUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log a reading")
            }
        }
        .sheet(item: $logging) { kind in LogVitalView(kind: kind) }
        .task(id: app.vitalsVersion) { await load() }
        .refreshable { await load() }
    }

    private func row(_ vital: VitalLogRow) -> some View {
        VitalRowView(vital: vital, unit: unit)
            .swipeActions {
                Button(role: .destructive) { Task { await delete(vital) } } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private func load() async {
        guard let userId = Backend.shared.userId else { return }
        let now = Date()
        do {
            vitals = try await Backend.shared.vitals(userId: userId, from: now.addingTimeInterval(-90 * 86_400),
                                                     to: now.addingTimeInterval(86_400))
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func delete(_ vital: VitalLogRow) async {
        do {
            try await Backend.shared.deleteVital(id: vital.id)
            vitals.removeAll { $0.id == vital.id }
            app.vitalsVersion += 1
        } catch {
            self.error = error.localizedDescription
        }
    }
}
