import NutraCore
import SwiftUI

/// The user's diet plans, active first.
struct DietPlansView: View {
    @State private var plans: [DietPlanRow] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                InlineError(message: error) { Task { await load() } }
            } else if plans.isEmpty && !loading {
                Text("No diet plans yet. Start one from the condition library.").foregroundStyle(.secondary)
            }
            ForEach(plans) { plan in
                HStack {
                    NavigationLink {
                        DietPlanEditorView(plan: plan)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                            Text(plan.isActive ? "Active" : ConditionCatalog.condition(id: plan.conditionId ?? "general").name)
                                .font(.footnote).foregroundStyle(plan.isActive ? Theme.accent : .secondary)
                        }
                    }
                    if !plan.isActive {
                        Button("Make active") { activate(plan) }.buttonStyle(.bordered).font(.footnote)
                    }
                }
            }
        }
        .overlay { if loading && plans.isEmpty { ProgressView() } }
        .navigationTitle("Diet plans")
        .onAppear { Task { await load() } }  // reload when returning from the editor
    }

    private func load() async {
        guard let userId = Backend.shared.userId else { return }
        loading = true
        defer { loading = false }
        do {
            let all = try await Backend.shared.dietPlans(userId: userId)
            plans = all.filter { $0.isActive } + all.filter { !$0.isActive }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func activate(_ plan: DietPlanRow) {
        guard let userId = Backend.shared.userId else { return }
        Task {
            do {
                try await Backend.shared.activatePlan(id: plan.id, userId: userId)
                await load()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
