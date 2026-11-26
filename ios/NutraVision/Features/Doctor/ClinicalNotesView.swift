import SwiftUI

/// The doctor's own notes about a patient: newest first, private to that doctor, and hidden again if
/// the patient stops sharing. Notes can be deleted but not edited, so the record stays honest.
struct ClinicalNotesView: View {
    let patient: ProfileRow

    @State private var notes: [ClinicalNoteRow] = []
    @State private var draft = ""
    @State private var saving = false
    @State private var loaded = false
    @State private var error: String?
    @State private var deleting: ClinicalNoteRow?
    @FocusState private var editing: Bool

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        List {
            Section {
                TextField("Visit summary, follow-up, what to watch…", text: $draft, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($editing)
                    .accessibilityLabel("New note")
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() } else { Text("Save note") }
                }
                .disabled(saving || trimmed.isEmpty || trimmed.count > 4000)
            } header: {
                Text("New note")
            } footer: {
                Text("Only you can see your notes. The patient and other doctors can't.")
            }
            if let error {
                Section { InlineError(message: error) { Task { await load() } } }
            }
            Section("Notes") {
                if loaded && notes.isEmpty { Text("No notes yet").foregroundStyle(.secondary) }
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                        Text(note.body).textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                    .swipeActions {
                        Button("Delete", role: .destructive) { deleting = note }
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("Delete this note?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { note in
            Button("Delete note", role: .destructive) { Task { await delete(note) } }
        } message: { _ in
            Text("This can't be undone.")
        }
    }

    private func load() async {
        do {
            notes = try await Backend.shared.clinicalNotes(patientId: patient.id)
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
        loaded = true
    }

    private func save() async {
        guard let doctorId = Backend.shared.userId, !trimmed.isEmpty else { return }
        saving = true
        defer { saving = false }
        let note = ClinicalNoteRow(doctorId: doctorId, patientId: patient.id, body: trimmed)
        do {
            try await Backend.shared.insertClinicalNote(note)
            notes.insert(note, at: 0)
            draft = ""
            editing = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ note: ClinicalNoteRow) async {
        do {
            try await Backend.shared.deleteClinicalNote(id: note.id)
            notes.removeAll { $0.id == note.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
