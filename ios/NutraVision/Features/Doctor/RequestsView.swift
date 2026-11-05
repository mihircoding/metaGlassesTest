import Observation
import SwiftUI

@Observable
@MainActor
final class RequestsModel {
    var links: [CareLinkRow] = []
    var names: [UUID: String] = [:]
    var error: String?

    func load() async {
        do {
            let links = try await Backend.shared.careLinks()
            let profiles = try await Backend.shared.profiles(ids: links.map(\.patientId))
            self.links = links
            names = Dictionary(profiles.map { ($0.id, $0.fullName) }, uniquingKeysWith: { first, _ in first })
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }
}

struct RequestsView: View {
    @State private var model = RequestsModel()
    @State private var email = ""
    @State private var sending = false
    /// Shown verbatim, e.g. "No patient with that email".
    @State private var sendError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Request a patient") {
                    TextField("Patient email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Send request") { send() }
                        .disabled(sending || email.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let sendError {
                        Text(sendError).font(.footnote).foregroundStyle(Theme.bad)
                    }
                }
                if let error = model.error {
                    Section { InlineError(message: error) { Task { await model.load() } } }
                }
                Section("Requests") {
                    if model.links.isEmpty { Text("No requests yet").foregroundStyle(.secondary) }
                    ForEach(model.links) { link in
                        linkRow(link)
                    }
                }
            }
            .navigationTitle("Requests")
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    private func linkRow(_ link: CareLinkRow) -> some View {
        let name = model.names[link.patientId] ?? ""
        return HStack {
            VStack(alignment: .leading) {
                Text(name.isEmpty ? (link.patientEmail ?? "Patient") : name)
                if !name.isEmpty, let mail = link.patientEmail {
                    Text(mail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            chip(link.status)
        }
        .swipeActions {
            if link.status == .pending || link.status == .accepted {
                Button("Revoke", role: .destructive) { revoke(link) }
            }
        }
    }

    private func chip(_ status: CareLinkStatus) -> some View {
        let color: Color
        switch status {
        case .accepted: color = Theme.good
        case .pending: color = Theme.moderation
        case .declined, .revoked: color = Theme.bad
        }
        return Text(status.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private func send() {
        let address = email.trimmingCharacters(in: .whitespaces)
        sending = true
        sendError = nil
        Task {
            defer { sending = false }
            do {
                try await Backend.shared.requestPatient(email: address)
                email = ""
                await model.load()
            } catch {
                sendError = error.localizedDescription
            }
        }
    }

    private func revoke(_ link: CareLinkRow) {
        Task {
            do {
                try await Backend.shared.revokeCareLink(id: link.id)
                await model.load()
            } catch {
                model.error = error.localizedDescription
            }
        }
    }
}
