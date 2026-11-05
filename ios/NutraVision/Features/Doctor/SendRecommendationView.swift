import NutraCore
import SwiftUI

/// Doctor: send a patient new targets, a diet plan or a note. The patient accepts or declines.
struct SendRecommendationView: View {
    let patient: ProfileRow

    @Environment(\.dismiss) private var dismiss
    @State private var kind = RecommendationKind.targets
    @State private var targets: Targets
    // ponytail: minimal plan edit (rename, remove items); Task 23's plan editor replaces this.
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
            TextField("Plan name", text: $plan.name)
            Text("Starts from the \(ConditionCatalog.condition(id: plan.conditionId).name) sample plan. Swipe to remove foods.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        ForEach(plan.meals.indices, id: \.self) { index in
            Section(plan.meals[index].meal.title) {
                ForEach(plan.meals[index].items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.servingDesc).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(item.nutrients.kcal.rounded())) kcal").foregroundStyle(.secondary)
                    }
                }
                .onDelete { plan.meals[index].items.remove(atOffsets: $0) }
            }
        }
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
