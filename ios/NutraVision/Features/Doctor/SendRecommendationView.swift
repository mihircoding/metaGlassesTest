import NutraCore
import SwiftUI

/// Doctor: send a patient new targets, a diet plan or a note. The patient accepts or declines.
struct SendRecommendationView: View {
    let patient: ProfileRow

    @Environment(\.dismiss) private var dismiss
    @State private var kind = RecommendationKind.targets
    @State private var targets: Targets
    @State private var plan: DietPlanDraft
    @State private var message = ""
    @State private var sending = false
    @State private var error: String?

    init(patient: ProfileRow) {
        self.patient = patient
        let primary = ConditionCatalog.condition(id: patient.conditions.first ?? "general")
        _targets = State(initialValue: patient.targets)
        _plan = State(initialValue: DietPlanDraft(name: "\(primary.name) plan", conditionId: primary.id, notes: "",
                                                  targets: patient.targets, meals: primary.samplePlan))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text("Targets").tag(RecommendationKind.targets)
                        Text("Diet plan").tag(RecommendationKind.dietPlan)
                        Text("Note").tag(RecommendationKind.note)
                    }
                    .pickerStyle(.segmented)
                }
                switch kind {
                case .targets: targetsSection
                case .dietPlan: planSections
                case .note: EmptyView()
                }
                Section(kind == .note ? "Note" : "Message (optional)") {
                    TextField("Message to the patient", text: $message, axis: .vertical).lineLimit(2...6)
                }
                if let error {
                    Section { InlineError(message: error) { send() } }
                }
            }
            .navigationTitle("Recommend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }.disabled(sending || !canSend)
                }
            }
        }
    }

    private var canSend: Bool {
        switch kind {
        case .note: return !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .dietPlan: return !plan.name.trimmingCharacters(in: .whitespaces).isEmpty
        case .targets: return true
        }
    }

    private var targetsSection: some View {
        Section("New daily targets") {
            field("Calories (kcal)", $targets.kcal)
            field("Protein (g)", $targets.proteinG)
            field("Carbs (g)", $targets.carbsG)
            field("Fat (g)", $targets.fatG)
            field("Saturated fat (g)", $targets.satFatG)
            field("Sodium (mg)", $targets.sodiumMg)
            field("Fiber (g)", $targets.fiberG)
        }
    }

    private func field(_ title: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

    @ViewBuilder
    private var planSections: some View {
        Section("Plan") {
            NavigationLink {
                DietPlanEditorView(plan: planRow) { edited in
                    plan = DietPlanDraft(name: edited.name, conditionId: plan.conditionId, notes: plan.notes,
                                         targets: edited.targets, meals: edited.meals)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                    Text("Starts from the \(ConditionCatalog.condition(id: plan.conditionId).name) sample plan. Tap to edit.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The draft as a plan row for the shared editor; the editor hands the edits back instead of saving.
    private var planRow: DietPlanRow {
        DietPlanRow(userId: patient.id, authorId: Backend.shared.userId ?? patient.id, conditionId: plan.conditionId,
                    name: plan.name, notes: plan.notes, targets: plan.targets, meals: plan.meals, isActive: false)
    }

    private func send() {
        guard let doctorId = Backend.shared.userId else {
            error = "You are signed out. Sign in again to send."
            return
        }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        var payload = RecommendationPayload()
        switch kind {
        case .targets: payload.targets = targets
        case .dietPlan: payload.dietPlan = plan
        case .note: break
        }
        let rec = RecommendationRow(doctorId: doctorId, patientId: patient.id, kind: kind, payload: payload,
                                    message: text.isEmpty ? nil : text)
        sending = true
        error = nil
        Task {
            defer { sending = false }
            do {
                try await Backend.shared.sendRecommendation(rec)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
