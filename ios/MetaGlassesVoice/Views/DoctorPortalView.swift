import SwiftUI

// MARK: - Doctor Portal Entry Point

struct DoctorPortalView: View {
    @EnvironmentObject var doctor: DoctorViewModel

    var body: some View {
        if doctor.isLoggedIn {
            DoctorDashboardView()
        } else {
            DoctorLoginView()
        }
    }
}

// MARK: - Doctor Login View

private struct DoctorLoginView: View {
    @EnvironmentObject var doctor: DoctorViewModel
    @State private var showPassword = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "stethoscope.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.teal)
                    Text("Doctor Portal")
                        .font(.largeTitle.weight(.bold))
                    Text("Log in to view patients and assign meal plans")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    TextField("Email address", text: $doctor.loginEmail)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $doctor.loginPassword)
                            } else {
                                SecureField("Password", text: $doctor.loginPassword)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = doctor.loginError {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }

                    Button {
                        doctor.login()
                    } label: {
                        if doctor.isLoggingIn {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(doctor.isLoggingIn)
                }
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Text("Demo credentials:").font(.caption).foregroundStyle(.secondary)
                    Text("doctor@nutrition.app  /  doctor123")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Doctor Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Doctor Dashboard View

struct DoctorDashboardView: View {
    @EnvironmentObject var doctor: DoctorViewModel
    @State private var selectedPatient: PatientRecord?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Doctor info header
                Section {
                    if let doc = doctor.currentDoctor {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                .font(.largeTitle)
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading) {
                                Text(doc.name).font(.headline)
                                Text(doc.specialization).font(.caption).foregroundStyle(.secondary)
                                Text(doc.email).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Patient list
                Section("Patients (\(doctor.patientsForCurrentDoctor().count))") {
                    let myPatients = doctor.patientsForCurrentDoctor()
                    if myPatients.isEmpty {
                        Text("No patients assigned").foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(myPatients) { patient in
                            NavigationLink(destination: PatientDetailView(patient: patient)) {
                                PatientRow(patient: patient)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Doctor Dashboard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") { doctor.logout(); dismiss() }
                        .foregroundStyle(.red)
                }
            }
            .onAppear { doctor.loadPatients() }
        }
    }
}

// MARK: - Patient Row

private struct PatientRow: View {
    let patient: PatientRecord
    @EnvironmentObject var doctor: DoctorViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle().fill(Color.indigo)
                Text(String(patient.name.prefix(1)))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(patient.name).font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Image(systemName: patient.condition.icon)
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                    Text(patient.condition.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let avg = doctor.averageDailyCalories(patient)
                Text("\(Int(avg))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(avg > 0 ? .orange : .secondary)
                Text("avg kcal").font(.caption2).foregroundStyle(.secondary)

                let warnings = doctor.complianceWarnings(for: patient)
                if !warnings.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Patient Detail View

struct PatientDetailView: View {
    let patient: PatientRecord
    @EnvironmentObject var doctor: DoctorViewModel
    @State private var showCreatePlan = false
    @State private var notesText: String
    @State private var isSavingNotes = false

    init(patient: PatientRecord) {
        self.patient = patient
        self._notesText = State(initialValue: patient.notes)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Patient header
                PatientHeaderCard(patient: patient)
                    .padding(.horizontal)

                // Compliance warnings
                let warnings = doctor.complianceWarnings(for: patient)
                if !warnings.isEmpty {
                    ComplianceWarningsCard(warnings: warnings)
                        .padding(.horizontal)
                }

                // 7-day food log summary
                WeeklyFoodLogCard(patient: patient)
                    .padding(.horizontal)

                // Active meal plan
                let plans = doctor.mealPlansForPatient(patient)
                if let activePlan = plans.first(where: { $0.isActive }) {
                    ActiveMealPlanCard(plan: activePlan)
                        .padding(.horizontal)
                }

                // All meal plans
                if !plans.isEmpty {
                    MealPlanHistoryCard(plans: plans)
                        .padding(.horizontal)
                }

                // Assign new plan button
                Button {
                    showCreatePlan = true
                } label: {
                    Label("Assign New Meal Plan", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .padding(.horizontal)

                // Doctor notes
                DoctorNotesCard(patientId: patient.id, notes: $notesText) {
                    doctor.updatePatientNotes(patient, notes: notesText)
                }
                .padding(.horizontal)

                // Dietary guidelines
                MedicalDietGuideCard(condition: patient.condition)
                    .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .navigationTitle(patient.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreatePlan) {
            CreateMealPlanView(patient: patient)
        }
    }
}

// MARK: - Patient Header Card

private struct PatientHeaderCard: View {
    let patient: PatientRecord

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.indigo)
                Text(String(patient.name.prefix(2)))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(patient.name).font(.headline)
                Text(patient.email).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: patient.condition.icon).foregroundStyle(.indigo)
                    Text(patient.condition.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.indigo)
                }
                Text("Added \(DateFormatter.shortDate.string(from: patient.dateAdded))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Compliance Warnings Card

private struct ComplianceWarningsCard: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Compliance Alerts", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)

            ForEach(warnings, id: \.self) { w in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .padding(.top, 5)
                        .foregroundStyle(.red)
                    Text(w).font(.caption)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Weekly Food Log Card

private struct WeeklyFoodLogCard: View {
    let patient: PatientRecord
    @EnvironmentObject var doctor: DoctorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Food Log").font(.headline).padding(.top)

            let summaries = doctor.patientDailySummaries(patient, days: 7)
            if summaries.isEmpty {
                Text("No food logged").foregroundStyle(.secondary).font(.subheadline)
                    .padding(.bottom)
            } else {
                ForEach(summaries, id: \.0) { (date, summary) in
                    PatientDayRow(date: date, summary: summary, limit: patient.condition.dietaryGuidelines.dailyCaloricTarget)
                }
                .padding(.bottom)
            }
        }
        .padding(.horizontal)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PatientDayRow: View {
    let date: Date; let summary: DailySummary; let limit: Double
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE d"; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Text(Self.dayFmt.string(from: date))
                .font(.caption.weight(.semibold))
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(summary.totalCalories > limit * 1.1 ? Color.red : Color.orange)
                        .frame(width: min(geo.size.width * (summary.totalCalories / max(limit * 1.2, 1)), geo.size.width))
                }
            }
            .frame(height: 14)

            Text("\(Int(summary.totalCalories))")
                .font(.caption.weight(.semibold))
                .frame(width: 45, alignment: .trailing)
            Text("kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Active Meal Plan Card

private struct ActiveMealPlanCard: View {
    let plan: MealPlan
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Active Meal Plan", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                Spacer()
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            Text(plan.name).font(.headline)
            Text("Target: \(Int(plan.calorieTarget)) kcal • P: \(Int(plan.proteinTarget))g • C: \(Int(plan.carbTarget))g • F: \(Int(plan.fatTarget))g")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Started: \(DateFormatter.shortDate.string(from: plan.startDate))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if isExpanded {
                Divider()
                if !plan.doctorNotes.isEmpty {
                    Text(plan.doctorNotes).font(.caption).foregroundStyle(.secondary).italic()
                }
                ForEach(plan.dailyMeals) { meal in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.mealType.rawValue).font(.caption.weight(.semibold))
                        ForEach(meal.suggestedFoods) { food in
                            HStack {
                                Text("• \(food.name) (\(food.servingNote))")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(food.estimatedCalories)) kcal")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.teal.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.teal.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Meal Plan History Card

private struct MealPlanHistoryCard: View {
    let plans: [MealPlan]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meal Plan History").font(.headline).padding(.top)

            ForEach(plans) { plan in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name).font(.subheadline)
                        Text(DateFormatter.shortDate.string(from: plan.startDate))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(plan.isActive ? "Active" : "Past")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(plan.isActive ? .teal : .secondary)
                }
                Divider()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Doctor Notes Card

private struct DoctorNotesCard: View {
    let patientId: String
    @Binding var notes: String
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Doctor Notes", systemImage: "note.text")
                .font(.headline)
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .padding(4)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button("Save Notes", action: onSave)
                .buttonStyle(.bordered)
                .tint(.teal)
                .font(.caption.weight(.semibold))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Medical Diet Guide Card

private struct MedicalDietGuideCard: View {
    let condition: MedicalCondition
    @State private var isExpanded = false

    var body: some View {
        let g = condition.dietaryGuidelines

        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Dietary Guidelines: \(condition.rawValue)", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(g.summary).font(.caption).foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    GuidelineChip(label: "Calories", value: "\(Int(g.dailyCaloricTarget))")
                    GuidelineChip(label: "Protein", value: "\(Int(g.proteinTarget))g")
                    GuidelineChip(label: "Carbs", value: "\(Int(g.carbTarget))g")
                    GuidelineChip(label: "Fat", value: "\(Int(g.fatTarget))g")
                }

                Text("Key Recommendations").font(.caption.weight(.semibold)).padding(.top, 4)
                ForEach(g.recommendations, id: \.self) { rec in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                        Text(rec).font(.caption)
                    }
                }

                if !g.avoid.isEmpty {
                    Text("Foods to Avoid").font(.caption.weight(.semibold)).padding(.top, 4)
                    ForEach(g.avoid, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                            Text(item).font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.indigo.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.indigo.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct GuidelineChip: View {
    let label: String; let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.weight(.bold)).foregroundStyle(.indigo)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.indigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
