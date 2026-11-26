import SwiftUI

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var forgot = false

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Password", text: $password).textContentType(.password)
            }
            if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
            Button {
                Task { await signIn() }
            } label: {
                if busy { ProgressView() } else { Text("Sign in") }
            }
            .disabled(busy || email.isEmpty || password.isEmpty)
            Button("Forgot password?") { forgot = true }.font(.footnote)
        }
        .navigationTitle("Sign in")
        .sheet(isPresented: $forgot) { ForgotPasswordView(email: email) }
    }

    // AppModel follows the auth state, so success needs no navigation here.
    private func signIn() async {
        busy = true
        error = nil
        do {
            try await Backend.shared.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}
