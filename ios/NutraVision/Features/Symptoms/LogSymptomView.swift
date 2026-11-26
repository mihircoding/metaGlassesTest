import NutraCore
import SwiftUI

/// Log one symptom diary entry. Red-flag symptoms and severe pain say what to do next.
struct LogSymptomView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var selected: Set<Symptom> = []
    @State private var severity = 4.0
    @State private var bristol: Int?
    @State private var note = ""
    @State private var saving = false
    @State private var error: String?

    private var level: Int { Int(severity.rounded()) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $date, in: ...Date())
                }
                Section("What did you feel?") {
                    ForEach(Symptom.allCases, id: \.self) { symptom in
                        Button {
                            if selected.contains(symptom) { selected.remove(symptom) } else { selected.insert(symptom) }
                        } label: {
                            HStack {
                                Text(symptom.title).foregroundStyle(Color.primary)
                                Spacer()
                                if selected.contains(symptom) {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.accent).fontWeight(.semibold)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(selected.contains(symptom) ? .isSelected : [])
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("How bad, overall")
                            Spacer()
                            CategoryChip(title: "\(level)/10 · \(SymptomSeverity.title(level))",
                                         color: SymptomDiary.severityColor(level))
                        }
                        Slider(value: $severity, in: 1...10, step: 1) { Text("Severity") }
                            .tint(SymptomDiary.severityColor(level))
                            .accessibilityValue("\(level) of 10, \(SymptomSeverity.title(level))")
                    }
                    Picker("Stool type", selection: $bristol) {
                        Text("Not recorded").tag(Int?.none)
                        ForEach(Array(BristolScale.range), id: \.self) { Text(BristolScale.title($0)).tag(Int?.some($0)) }
                    }
                } footer: {
                    Text("Stool type uses the Bristol scale: 1 is hardest, 7 is watery, and 3–4 is typical.")
                }

                if let advice = SymptomDiary.advice(symptoms: selected, severity: level) {
                    Section {
                        Label(advice, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .symbolRenderingMode(.multicolor)
                    }
                }

                Section("Note") {
                    TextField("Optional, e.g. ate out, stressful day", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let error {
                    Section { Text(error).font(.footnote).foregroundStyle(Theme.bad) }
                }
            }
            .navigationTitle("Log symptoms")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(saving || selected.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let userId = Backend.shared.userId, !selected.isEmpty else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = SymptomLogRow(userId: userId, loggedAt: date,
                                symptoms: Symptom.allCases.filter(selected.contains),  // a stable order
                                severity: level, bristol: bristol,
                                note: trimmedNote.isEmpty ? nil : String(trimmedNote.prefix(500)))
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                try await Backend.shared.insertSymptom(row)
                app.symptomsVersion += 1
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
