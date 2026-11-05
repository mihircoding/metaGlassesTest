import NutraCore
import SwiftUI

/// Log a weigh-in. The newest entry also becomes the profile weight, which recomputes automatic targets.
struct LogWeightView: View {
    let onSaved: () async -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var text = ""
    @State private var useLb = false
    @State private var error: String?
    @State private var saving = false
    /// The weigh-in row is stored; a retry after a profile-save failure must not insert it again.
    @State private var inserted = false
    @State private var newest = false

    private static let kgPerLb = 0.45359237

    private var kg: Double? {
        guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
        return useLb ? v * Self.kgPerLb : v
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0", text: $text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Picker("Unit", selection: $useLb) {
                            Text("kg").tag(false)
                            Text("lb").tag(true)
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 90)
                    }
                }
                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(Theme.bad)
                        Button("Retry") { save() }.buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(saving || kg == nil) }
            }
            .onAppear {
                if text.isEmpty, let w = app.profile?.weightKg {
                    text = w.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let userId = Backend.shared.userId, let kg else { return }
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                let cal = Calendar.current
                if !inserted {
                    // Newest = no stored weigh-in on a later day than the one being logged.
                    let all = try await Backend.shared.weights(userId: userId, from: Date(timeIntervalSince1970: 0),
                                                               to: Date().addingTimeInterval(86_400))
                    let isNewest = all.last.map { cal.startOfDay(for: date) >= cal.startOfDay(for: $0.measuredAt) } ?? true
                    try await Backend.shared.insertWeight(WeightLogRow(userId: userId, measuredAt: date, weightKg: kg,
                                                                       source: .manual, healthkitUuid: nil))
                    inserted = true
                    newest = isNewest
                }
                if newest, var profile = app.profile {
                    profile.weightKg = kg
                    try await app.saveProfile(profile)
                }
                app.weightsVersion += 1
                await onSaved()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
