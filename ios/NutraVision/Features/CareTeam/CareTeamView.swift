import NutraCore
import Observation
import SwiftUI

/// The patient's links, recommendations and the doctors' names; shared by the Care Team screen, the Dashboard
/// banner and the More badge.
@Observable
@MainActor
final class CareTeamModel {
    var links: [CareLinkRow] = []
    var recommendations: [RecommendationRow] = []
    var doctors: [UUID: ProfileRow] = [:]
    var error: String?

    var pendingLinks: [CareLinkRow] { links.filter { $0.status == .pending } }
    var acceptedLinks: [CareLinkRow] { links.filter { $0.status == .accepted } }
    var pendingRecommendations: [RecommendationRow] { recommendations.filter { $0.status == .pending } }
    var pendingCount: Int { pendingLinks.count + pendingRecommendations.count }

    func doctorName(_ id: UUID) -> String {
        guard let name = doctors[id]?.fullName, !name.isEmpty else { return "Your doctor" }
        return name.hasPrefix("Dr") ? name : "Dr \(name)"
    }

    /// "Dr X wants to follow your food log" / "New recommendation from Dr X"; link requests first.
    var bannerText: String? {
        if let link = pendingLinks.first { return "\(doctorName(link.doctorId)) wants to follow your food log" }
        if let rec = pendingRecommendations.first { return "New recommendation from \(doctorName(rec.doctorId))" }
        return nil
    }

    func load() async {
        do {
            let links = try await Backend.shared.careLinks()
            let recs = try await Backend.shared.recommendations()
            let ids = Array(Set(links.map(\.doctorId) + recs.map(\.doctorId)))
            let profiles = try await Backend.shared.profiles(ids: ids)
            self.links = links
            recommendations = recs
            doctors = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }

    /// Runs a write, then reloads. A failure stays in `error` for the Retry button.
    func perform(_ action: () async throws -> Void) async {
        do {
            try await action()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CareTeamView: View {
    @State private var model = CareTeamModel()
    @State private var revoking: CareLinkRow?

    var body: some View {
        List {
            if let error = model.error {
                Section {
                    Text(error).font(.footnote).foregroundStyle(Theme.bad)
                    Button("Retry") { Task { await model.load() } }
                }
            }
            Section("Pending requests") {
                if model.pendingLinks.isEmpty { Text("No pending requests").foregroundStyle(.secondary) }
                ForEach(model.pendingLinks) { link in
                    VStack(alignment: .leading, spacing: 6) {
                        doctorHeader(link.doctorId)
                        HStack {
                            Button("Accept") { respond(link, accept: true) }
                                .buttonStyle(.borderedProminent).tint(Theme.accent)
                            Button("Decline") { respond(link, accept: false) }.buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section("My doctors") {
                if model.acceptedLinks.isEmpty { Text("No doctors yet").foregroundStyle(.secondary) }
                ForEach(model.acceptedLinks) { link in
                    HStack {
                        doctorHeader(link.doctorId)
                        Spacer()
                        Button("Revoke", role: .destructive) { revoking = link }.buttonStyle(.bordered)
                    }
                }
            }
            Section("Recommendations") {
                if model.recommendations.isEmpty { Text("No recommendations yet").foregroundStyle(.secondary) }
                ForEach(sortedRecommendations) { rec in
                    NavigationLink {
                        RecommendationDetailView(recommendation: rec, doctorName: model.doctorName(rec.doctorId)) {
                            await model.load()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(RecommendationDetailView.title(for: rec)).font(.headline)
                            Text("\(model.doctorName(rec.doctorId)) · \(rec.status.rawValue.capitalized)")
                                .font(.footnote).foregroundStyle(rec.status == .pending ? Theme.accent : Color.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Care Team")
        .task { await model.load() }
        .refreshable { await model.load() }
        .confirmationDialog("Revoke access?", isPresented: revokingBinding, titleVisibility: .visible,
                            presenting: revoking) { link in
            Button("Revoke", role: .destructive) {
                Task { await model.perform { try await Backend.shared.revokeCareLink(id: link.id) } }
            }
        } message: { link in
            Text("\(model.doctorName(link.doctorId)) will no longer see your food log.")
        }
    }

    private var revokingBinding: Binding<Bool> {
        Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } })
    }

    /// Pending first; the server's newest-first order is kept within each group.
    private var sortedRecommendations: [RecommendationRow] {
        model.recommendations.filter { $0.status == .pending } + model.recommendations.filter { $0.status != .pending }
    }

    private func doctorHeader(_ id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.doctorName(id)).font(.headline)
            if let specialty = model.doctors[id]?.specialty, !specialty.isEmpty {
                Text(specialty).font(.subheadline).foregroundStyle(.secondary)
            }
            if let license = model.doctors[id]?.licenseNumber, !license.isEmpty {
                Text("License # \(license)").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func respond(_ link: CareLinkRow, accept: Bool) {
        Task { await model.perform { try await Backend.shared.respondCareLink(id: link.id, accept: accept) } }
    }
}
