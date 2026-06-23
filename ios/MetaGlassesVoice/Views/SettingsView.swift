import SwiftUI

// MARK: - Settings / Profile View

struct SettingsView: View {
    @EnvironmentObject var nutrition: NutritionViewModel
    @EnvironmentObject var doctor: DoctorViewModel
    @State private var showDoctorPortal = false
    @State private var showConditionPicker = false
    @State private var showClearDataAlert = false
    @State private var editingProfile = false

    var body: some View {
        NavigationStack {
            Form {
                // Profile section
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.orange).frame(width: 60, height: 60)
                            Text(String(nutrition.profile.name.prefix(1)))
                                .font(.title.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nutrition.profile.name)
                                .font(.headline)
                            Text(nutrition.profile.email.isEmpty ? "No email set" : nutrition.profile.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit") { editingProfile = true }
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }

                // Calorie goal
                Section("Daily Goals") {
                    HStack {
                        Label("Calorie Limit", systemImage: "flame.fill")
                        Spacer()
                        TextField("2000", value: $nutrition.profile.dailyCaloricLimit, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 70)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Protein Goal", systemImage: "p.circle.fill")
                        Spacer()
                        TextField("50", value: $nutrition.profile.proteinGoal, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("g").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Carb Goal", systemImage: "c.circle.fill")
                        Spacer()
                        TextField("250", value: $nutrition.profile.carbGoal, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("g").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Fat Goal", systemImage: "f.circle.fill")
                        Spacer()
                        TextField("65", value: $nutrition.profile.fatGoal, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("g").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Fiber Goal", systemImage: "leaf.fill")
                        Spacer()
                        TextField("25", value: $nutrition.profile.fiberGoal, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("g").foregroundStyle(.secondary)
                    }
                }

                // Medical condition
                Section("Medical Condition") {
                    Button {
                        showConditionPicker = true
                    } label: {
                        HStack {
                            Label("Condition", systemImage: "cross.case.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(nutrition.profile.medicalCondition.rawValue)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
                        }
                    }

                    if nutrition.profile.medicalCondition != .none {
                        Button("Apply Recommended Goals for \(nutrition.profile.medicalCondition.rawValue)") {
                            nutrition.profile.applyConditionDefaults()
                            nutrition.saveProfile()
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                // AI Settings
                Section("AI Food Scanning") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("OpenAI API Key", systemImage: "key.fill")
                        SecureField("sk-…", text: $nutrition.profile.openAIKey)
                            .font(.caption.monospaced())
                        Text("Used locally for glasses camera AI food analysis. Never shared.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Body stats
                Section("Body Stats (for TDEE estimate)") {
                    Picker("Activity Level", selection: $nutrition.profile.activityLevel) {
                        ForEach(UserProfile.ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)

                    if let tdee = nutrition.profile.estimatedTDEE {
                        HStack {
                            Text("Estimated TDEE").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(tdee)) kcal/day").font(.caption.weight(.semibold))
                        }
                    }
                }

                // Doctor Portal
                Section("Doctor Panel") {
                    if doctor.isLoggedIn {
                        HStack {
                            Image(systemName: "stethoscope").foregroundStyle(.teal)
                            Text("Logged in as \(doctor.currentDoctor?.name ?? "Doctor")")
                            Spacer()
                            Button("Open Portal") { showDoctorPortal = true }
                                .font(.caption.weight(.semibold))
                                .tint(.teal)
                        }
                        Button("Log Out as Doctor") { doctor.logout() }
                            .foregroundStyle(.red)
                    } else {
                        Button {
                            showDoctorPortal = true
                        } label: {
                            Label("Doctor Login", systemImage: "stethoscope")
                        }
                    }
                }

                // Danger zone
                Section("Data") {
                    Button("Clear All Food Log Data") {
                        showClearDataAlert = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { nutrition.saveProfile() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showDoctorPortal) {
                DoctorPortalView()
            }
            .sheet(isPresented: $showConditionPicker) {
                ConditionPickerSheet(selected: nutrition.profile.medicalCondition) { condition in
                    nutrition.updateCondition(condition)
                    showConditionPicker = false
                }
            }
            .sheet(isPresented: $editingProfile) {
                EditProfileSheet()
            }
            .alert("Clear All Data?", isPresented: $showClearDataAlert) {
                Button("Clear", role: .destructive) {
                    NutritionDataStore.shared.clearAllData()
                    nutrition.refreshToday()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all food log entries. This cannot be undone.")
            }
        }
    }
}

// MARK: - Condition Picker Sheet

private struct ConditionPickerSheet: View {
    let selected: MedicalCondition
    let onSelect: (MedicalCondition) -> Void

    var body: some View {
        NavigationStack {
            List(MedicalCondition.allCases) { condition in
                Button {
                    onSelect(condition)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: condition.icon)
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.indigo)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(condition.rawValue)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if condition != .none {
                                Text("Cal: \(Int(condition.dietaryGuidelines.dailyCaloricTarget)) • Pro: \(Int(condition.dietaryGuidelines.proteinTarget))g • Carb: \(Int(condition.dietaryGuidelines.carbTarget))g")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if condition == selected {
                            Image(systemName: "checkmark").foregroundStyle(.orange)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Condition")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileSheet: View {
    @EnvironmentObject var nutrition: NutritionViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    LabeledContent("Name") {
                        TextField("Your name", text: $nutrition.profile.name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Email") {
                        TextField("email@example.com", text: $nutrition.profile.email)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                }
                Section("Body Measurements") {
                    Picker("Biological Sex", selection: $nutrition.profile.sex) {
                        ForEach(UserProfile.BiologicalSex.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("70", value: $nutrition.profile.weightKg, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                    }
                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        TextField("170", value: $nutrition.profile.heightCm, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                    }
                    DatePicker("Date of Birth",
                               selection: Binding(
                                get: { nutrition.profile.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -30, to: Date())! },
                                set: { nutrition.profile.dateOfBirth = $0 }
                               ),
                               displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { nutrition.saveProfile(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
