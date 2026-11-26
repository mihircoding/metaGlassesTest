import SwiftUI

/// "Forgot password?": emails a link that opens the app to choose a new password.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State var email: String
    @State private var busy = false
    @State private var sent = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label("Check your email", systemImage: "envelope.badge").font(.headline)
                        Text("If an account uses \(email), it will get a link to choose a new password. Open the link on this iPhone.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    } footer: {
                        Text("We'll email you a link to choose a new password.")
                    }
                    if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
                    Button {
                        Task { await send() }
                    } label: {
                        if busy { ProgressView() } else { Text("Send reset link") }
                    }
                    .disabled(busy || !email.contains("@"))
                }
            }
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(sent ? "Done" : "Cancel") { dismiss() } }
            }
        }
    }

    private func send() async {
        busy = true
        error = nil
        do {
            try await Backend.shared.sendPasswordReset(email: email.trimmingCharacters(in: .whitespaces))
            sent = true
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}

/// Shown after a reset link signed the user in: the new password, typed twice.
struct NewPasswordView: View {
    @Environment(AppModel.self) private var app
    @State private var password = ""
    @State private var confirm = ""
    @State private var busy = false
    @State private var error: String?

    private var valid: Bool { password.count >= 8 && password == confirm }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New password (8+ characters)", text: $password).textContentType(.newPassword)
                    SecureField("Confirm new password", text: $confirm).textContentType(.newPassword)
                } footer: {
                    if !confirm.isEmpty && password != confirm { Text("The passwords don't match.") }
                }
                if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
                Button {
                    Task { await save() }
                } label: {
                    if busy { ProgressView() } else { Text("Save password") }
                }
                .disabled(busy || !valid)
            }
            .navigationTitle("Choose a new password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Already signed in by the link; skipping keeps the old password.
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { app.choosingNewPassword = false } }
            }
        }
        .interactiveDismissDisabled(busy)
    }

    private func save() async {
        busy = true
        error = nil
        do {
            try await Backend.shared.setPassword(password)
            app.choosingNewPassword = false
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
