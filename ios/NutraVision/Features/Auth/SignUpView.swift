import SwiftUI

struct SignUpView: View {
    @Environment(AppModel.self) private var app
    @State private var role: Role = .patient
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var specialty = ""
    @State private var license = ""
    @State private var busy = false
    @State private var error: String?
    @State private var notice: String?

    private var passwordError: String? {
        password.isEmpty || password.count >= 8 ? nil : "Use at least 8 characters."
    }
    private var valid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@") && password.count >= 8
            && (role == .patient || (!specialty.isEmpty && !license.isEmpty))
    }

    var body: some View {
        Form {
            Picker("I am a", selection: $role) {
                Text("Patient").tag(Role.patient)
                Text("Doctor").tag(Role.doctor)
            }
            .pickerStyle(.segmented)
            Section {
                TextField("Full name", text: $fullName).textContentType(.name)
                TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Password (8+ characters)", text: $password).textContentType(.newPassword)
                if let passwordError { Text(passwordError).foregroundStyle(Theme.bad).font(.footnote) }
            }
            if role == .doctor {
                Section("Credentials") {
                    TextField("Specialty", text: $specialty)
                    TextField("License #", text: $license).textInputAutocapitalization(.characters).autocorrectionDisabled()
                }
            }
            if let error { Text(error).foregroundStyle(Theme.bad).font(.footnote) }
            if let notice { Text(notice).font(.footnote) }
            Button {
                Task { await signUp() }
            } label: {
                if busy { ProgressView() } else { Text("Create account") }
            }
            .disabled(busy || !valid)
        }
        .navigationTitle("Create account")
    }

    private func signUp() async {
        busy = true
        error = nil
        notice = nil
        if role == .doctor { app.pendingDoctorCredentials = .init(specialty: specialty, license: license) }
        do {
            try await Backend.shared.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password,
                                            fullName: fullName.trimmingCharacters(in: .whitespaces), role: role)
            if Backend.shared.userId == nil {
                notice = "Check your email to confirm your account, then sign in."
            }
        } catch {
            app.pendingDoctorCredentials = nil
            self.error = error.localizedDescription
        }
        busy = false
    }
}
