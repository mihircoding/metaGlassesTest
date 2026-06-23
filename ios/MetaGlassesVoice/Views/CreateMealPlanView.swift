import SwiftUI

// MARK: - Create Meal Plan View

struct CreateMealPlanView: View {
    let patient: PatientRecord
    @EnvironmentObject var doctor: DoctorViewModel
    @Environment(\.dismiss) var dismiss

    @State private var planName = ""
    @State private var planDescription = ""
    @State private var doctorNotes = ""
    @State private var calorieTarget: Double
    @State private var proteinTarget: Double
    @State private var carbTarget: Double
    @State private var fatTarget: Double
    @State private var dailyMeals: [DailyMealTemplate] = []
    @State private var useConditionTemplate = true
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!

    init(patient: PatientRecord) {
        self.patient = patient
        let g = patient.condition.dietaryGuidelines
        _calorieTarget = State(initialValue: g.dailyCaloricTarget)
        _proteinTarget = State(initialValue: g.proteinTarget)
        _carbTarget    = State(initialValue: g.carbTarget)
        _fatTarget     = State(initialValue: g.fatTarget)
        _planName      = State(initialValue: "\(patient.condition.rawValue) Meal Plan")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Plan basics
                Section("Plan Details") {
                    LabeledContent("Patient") { Text(patient.name).foregroundStyle(.secondary) }
                    LabeledContent("Condition") {
                        Text(patient.condition.rawValue)
                            .foregroundStyle(.indigo)
                    }
                    TextField("Plan Name", text: $planName)
                    TextField("Description", text: $planDescription, axis: .vertical)
                        .lineLimit(2...)
                }

                // Targets
                Section("Daily Nutritional Targets") {
                    Toggle("Use condition-based defaults", isOn: $useConditionTemplate)
                        .onChange(of: useConditionTemplate) { val in
                            if val {
                                let g = patient.condition.dietaryGuidelines
                                calorieTarget = g.dailyCaloricTarget
                                proteinTarget = g.proteinTarget
                                carbTarget    = g.carbTarget
                                fatTarget     = g.fatTarget
                            }
                        }

                    NumericFormRow(label: "Calories (kcal)", value: $calorieTarget)
                        .disabled(useConditionTemplate)
                    NumericFormRow(label: "Protein (g)", value: $proteinTarget)
                        .disabled(useConditionTemplate)
                    NumericFormRow(label: "Carbs (g)", value: $carbTarget)
                        .disabled(useConditionTemplate)
                    NumericFormRow(label: "Fat (g)", value: $fatTarget)
                        .disabled(useConditionTemplate)
                }

                // Duration
                Section("Duration") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    Toggle("Set End Date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                // Meal templates
                Section("Meal Templates") {
                    if dailyMeals.isEmpty {
                        Button("Load \(patient.condition.rawValue) Template") {
                            dailyMeals = ConditionMealTemplates.template(for: patient.condition)
                        }
                        .foregroundStyle(.teal)
                    } else {
                        ForEach(dailyMeals.indices, id: \.self) { idx in
                            MealTemplateRow(meal: $dailyMeals[idx])
                        }
                        .onDelete { dailyMeals.remove(atOffsets: $0) }

                        Button("Add Meal") {
                            dailyMeals.append(DailyMealTemplate(
                                mealType: .snack,
                                suggestedFoods: [],
                                targetCalories: 200
                            ))
                        }
                        .foregroundStyle(.teal)
                    }
                }

                // Doctor notes
                Section("Notes for Patient") {
                    TextField("Enter dietary advice, reminders, or special instructions…", text: $doctorNotes, axis: .vertical)
                        .lineLimit(4...)
                }

                // Guideline summary
                Section("Condition Guidelines Reference") {
                    ConditionGuidlinesSummaryView(condition: patient.condition)
                }
            }
            .navigationTitle("New Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") { assignPlan() }
                        .fontWeight(.semibold)
                        .disabled(planName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func assignPlan() {
        guard let doc = doctor.currentDoctor else { return }

        let plan = MealPlan(
            name: planName.isEmpty ? "Custom Plan" : planName,
            description: planDescription,
            condition: patient.condition,
            doctorId: doc.id.uuidString,
            doctorName: doc.name,
            patientId: patient.id,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            isActive: true,
            dailyMeals: dailyMeals,
            doctorNotes: doctorNotes,
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            carbTarget: carbTarget,
            fatTarget: fatTarget
        )
        doctor.createMealPlan(for: patient, plan: plan)
        dismiss()
    }
}

// MARK: - Meal Template Row

private struct MealTemplateRow: View {
    @Binding var meal: DailyMealTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("", selection: $meal.mealType) {
                    ForEach(FoodEntry.MealType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(Int(meal.targetCalories)) kcal target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(meal.suggestedFoods.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(.secondary)
                    Text("\(meal.suggestedFoods[i].name) — \(meal.suggestedFoods[i].servingNote)")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(meal.suggestedFoods[i].estimatedCalories)) kcal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Numeric Form Row

private struct NumericFormRow: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)
        }
    }
}

// MARK: - Condition Guidelines Summary

private struct ConditionGuidlinesSummaryView: View {
    let condition: MedicalCondition

    var body: some View {
        let g = condition.dietaryGuidelines
        VStack(alignment: .leading, spacing: 6) {
            Text(g.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !g.recommendations.isEmpty {
                Text("Key Points:").font(.caption.weight(.semibold))
                ForEach(g.recommendations.prefix(4), id: \.self) { rec in
                    Text("• \(rec)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Condition Meal Templates

enum ConditionMealTemplates {
    static func template(for condition: MedicalCondition) -> [DailyMealTemplate] {
        switch condition {
        case .diabetes, .type1Diabetes:
            return [
                DailyMealTemplate(
                    mealType: .breakfast,
                    suggestedFoods: [
                        SuggestedFood(name: "Steel-cut oatmeal", description: "Low GI whole grain", estimatedCalories: 150, estimatedProtein: 5, estimatedCarbs: 27, estimatedFat: 3, servingNote: "1 cup cooked"),
                        SuggestedFood(name: "Boiled eggs", description: "Protein without affecting blood sugar", estimatedCalories: 140, estimatedProtein: 12, estimatedCarbs: 1, estimatedFat: 10, servingNote: "2 eggs"),
                        SuggestedFood(name: "Berries (mixed)", description: "Low GI fruit", estimatedCalories: 50, estimatedProtein: 1, estimatedCarbs: 12, estimatedFat: 0, servingNote: "1/2 cup")
                    ],
                    targetCalories: 340,
                    notes: "No added sugars. Choose low-GI carbs only."
                ),
                DailyMealTemplate(
                    mealType: .lunch,
                    suggestedFoods: [
                        SuggestedFood(name: "Grilled chicken breast", description: "Lean protein", estimatedCalories: 165, estimatedProtein: 31, estimatedCarbs: 0, estimatedFat: 4, servingNote: "120g"),
                        SuggestedFood(name: "Leafy green salad", description: "Non-starchy vegetables", estimatedCalories: 40, estimatedProtein: 3, estimatedCarbs: 7, estimatedFat: 0, servingNote: "2 cups"),
                        SuggestedFood(name: "Lentils", description: "Low GI legume protein", estimatedCalories: 115, estimatedProtein: 9, estimatedCarbs: 20, estimatedFat: 0, servingNote: "1/2 cup cooked"),
                        SuggestedFood(name: "Olive oil dressing", description: "Healthy fat — slows glucose absorption", estimatedCalories: 60, estimatedProtein: 0, estimatedCarbs: 0, estimatedFat: 7, servingNote: "1 tbsp")
                    ],
                    targetCalories: 380,
                    notes: "Aim for 45–60g carbs per meal."
                ),
                DailyMealTemplate(
                    mealType: .snack,
                    suggestedFoods: [
                        SuggestedFood(name: "Almonds", description: "Protein + healthy fat, low GI", estimatedCalories: 100, estimatedProtein: 4, estimatedCarbs: 4, estimatedFat: 9, servingNote: "Small handful (~15 almonds)"),
                        SuggestedFood(name: "Apple", description: "Moderate GI fruit with fiber", estimatedCalories: 95, estimatedProtein: 0, estimatedCarbs: 25, estimatedFat: 0, servingNote: "1 medium", alternatives: ["Pear", "Orange"])
                    ],
                    targetCalories: 195
                ),
                DailyMealTemplate(
                    mealType: .dinner,
                    suggestedFoods: [
                        SuggestedFood(name: "Baked salmon", description: "Omega-3 protein, no carbs", estimatedCalories: 200, estimatedProtein: 28, estimatedCarbs: 0, estimatedFat: 10, servingNote: "140g fillet"),
                        SuggestedFood(name: "Steamed broccoli & cauliflower", description: "Non-starchy cruciferous vegetables", estimatedCalories: 50, estimatedProtein: 4, estimatedCarbs: 10, estimatedFat: 0, servingNote: "1.5 cups"),
                        SuggestedFood(name: "Brown rice", description: "Lower GI than white rice", estimatedCalories: 110, estimatedProtein: 2, estimatedCarbs: 23, estimatedFat: 1, servingNote: "1/2 cup cooked")
                    ],
                    targetCalories: 360,
                    notes: "Evening carbs should be minimal. Focus on protein and vegetables."
                )
            ]

        case .weightTraining:
            return [
                DailyMealTemplate(
                    mealType: .breakfast,
                    suggestedFoods: [
                        SuggestedFood(name: "Whey protein shake", description: "Fast-absorbing morning protein", estimatedCalories: 130, estimatedProtein: 25, estimatedCarbs: 5, estimatedFat: 2, servingNote: "1 scoop in water"),
                        SuggestedFood(name: "Oatmeal with banana", description: "Complex carbs for sustained energy", estimatedCalories: 310, estimatedProtein: 8, estimatedCarbs: 65, estimatedFat: 5, servingNote: "1 cup oats + 1 banana"),
                        SuggestedFood(name: "Eggs (whole + whites)", description: "High quality protein", estimatedCalories: 180, estimatedProtein: 22, estimatedCarbs: 1, estimatedFat: 9, servingNote: "2 whole + 2 egg whites")
                    ],
                    targetCalories: 620,
                    notes: "Eat within 1 hour of waking. High protein + complex carbs."
                ),
                DailyMealTemplate(
                    mealType: .lunch,
                    suggestedFoods: [
                        SuggestedFood(name: "Chicken breast", description: "Lean complete protein", estimatedCalories: 220, estimatedProtein: 42, estimatedCarbs: 0, estimatedFat: 5, servingNote: "200g grilled"),
                        SuggestedFood(name: "White rice", description: "Fast carbs for energy replenishment", estimatedCalories: 220, estimatedProtein: 4, estimatedCarbs: 48, estimatedFat: 0, servingNote: "1 cup cooked"),
                        SuggestedFood(name: "Mixed vegetables", description: "Micronutrients", estimatedCalories: 60, estimatedProtein: 4, estimatedCarbs: 12, estimatedFat: 0, servingNote: "1 cup")
                    ],
                    targetCalories: 500
                ),
                DailyMealTemplate(
                    mealType: .snack,
                    suggestedFoods: [
                        SuggestedFood(name: "Greek yogurt", description: "Casein + whey protein", estimatedCalories: 130, estimatedProtein: 17, estimatedCarbs: 9, estimatedFat: 0, servingNote: "170g non-fat"),
                        SuggestedFood(name: "Mixed nuts", description: "Healthy fats + calories", estimatedCalories: 170, estimatedProtein: 5, estimatedCarbs: 6, estimatedFat: 15, servingNote: "Small handful")
                    ],
                    targetCalories: 300,
                    notes: "Pre-workout: add 1 banana or rice cakes 30–60 min before training"
                ),
                DailyMealTemplate(
                    mealType: .dinner,
                    suggestedFoods: [
                        SuggestedFood(name: "Lean beef or turkey", description: "Creatine-rich protein source", estimatedCalories: 300, estimatedProtein: 45, estimatedCarbs: 0, estimatedFat: 12, servingNote: "200g cooked"),
                        SuggestedFood(name: "Sweet potato", description: "Complex carbs with micronutrients", estimatedCalories: 130, estimatedProtein: 3, estimatedCarbs: 30, estimatedFat: 0, servingNote: "1 medium"),
                        SuggestedFood(name: "Broccoli with olive oil", description: "Micronutrients + healthy fat", estimatedCalories: 100, estimatedProtein: 4, estimatedCarbs: 10, estimatedFat: 6, servingNote: "1.5 cups")
                    ],
                    targetCalories: 530,
                    notes: "Post-workout meal within 1–2 hours of training."
                ),
                DailyMealTemplate(
                    mealType: .snack,
                    suggestedFoods: [
                        SuggestedFood(name: "Casein protein shake", description: "Slow-release overnight protein", estimatedCalories: 120, estimatedProtein: 24, estimatedCarbs: 4, estimatedFat: 1, servingNote: "1 scoop before bed", isRequired: true)
                    ],
                    targetCalories: 120,
                    notes: "Bedtime: casein protein prevents overnight muscle catabolism."
                )
            ]

        case .liverCirrhosis:
            return [
                DailyMealTemplate(
                    mealType: .breakfast,
                    suggestedFoods: [
                        SuggestedFood(name: "Scrambled eggs", description: "High quality protein, easy to digest", estimatedCalories: 140, estimatedProtein: 12, estimatedCarbs: 1, estimatedFat: 10, servingNote: "2 eggs"),
                        SuggestedFood(name: "Whole grain toast", description: "Complex carbs for energy", estimatedCalories: 80, estimatedProtein: 3, estimatedCarbs: 15, estimatedFat: 1, servingNote: "1 slice, unsalted"),
                        SuggestedFood(name: "Low-sodium cottage cheese", description: "Additional protein", estimatedCalories: 80, estimatedProtein: 14, estimatedCarbs: 3, estimatedFat: 1, servingNote: "1/2 cup")
                    ],
                    targetCalories: 300,
                    notes: "CRITICAL: Use no added salt. Keep sodium under 500mg this meal."
                ),
                DailyMealTemplate(
                    mealType: .lunch,
                    suggestedFoods: [
                        SuggestedFood(name: "Baked chicken (skinless)", description: "Lean protein — avoid organ meats", estimatedCalories: 165, estimatedProtein: 31, estimatedCarbs: 0, estimatedFat: 4, servingNote: "120g"),
                        SuggestedFood(name: "Lentil soup (homemade, low sodium)", description: "Plant protein + fiber", estimatedCalories: 150, estimatedProtein: 10, estimatedCarbs: 25, estimatedFat: 1, servingNote: "1 cup"),
                        SuggestedFood(name: "Steamed green beans", description: "Low potassium vegetable", estimatedCalories: 35, estimatedProtein: 2, estimatedCarbs: 8, estimatedFat: 0, servingNote: "1 cup")
                    ],
                    targetCalories: 350
                ),
                DailyMealTemplate(
                    mealType: .snack,
                    suggestedFoods: [
                        SuggestedFood(name: "Rice cakes (unsalted)", description: "Safe carb snack, low sodium", estimatedCalories: 70, estimatedProtein: 1, estimatedCarbs: 15, estimatedFat: 0, servingNote: "2 plain rice cakes"),
                        SuggestedFood(name: "Applesauce (unsweetened)", description: "Easy to digest, low sodium", estimatedCalories: 50, estimatedProtein: 0, estimatedCarbs: 13, estimatedFat: 0, servingNote: "1/2 cup")
                    ],
                    targetCalories: 120
                ),
                DailyMealTemplate(
                    mealType: .dinner,
                    suggestedFoods: [
                        SuggestedFood(name: "White fish (tilapia/cod)", description: "Lean protein, easy on liver", estimatedCalories: 140, estimatedProtein: 29, estimatedCarbs: 0, estimatedFat: 3, servingNote: "140g baked, no salt"),
                        SuggestedFood(name: "White rice", description: "Easy to digest energy", estimatedCalories: 110, estimatedProtein: 2, estimatedCarbs: 24, estimatedFat: 0, servingNote: "1/2 cup cooked"),
                        SuggestedFood(name: "Zucchini (steamed)", description: "Low sodium, easy to digest", estimatedCalories: 25, estimatedProtein: 2, estimatedCarbs: 5, estimatedFat: 0, servingNote: "1 cup")
                    ],
                    targetCalories: 275,
                    notes: "NO salt. Avoid shellfish entirely (infection risk with liver disease)."
                ),
                DailyMealTemplate(
                    mealType: .snack,
                    suggestedFoods: [
                        SuggestedFood(name: "Whole grain crackers + peanut butter (unsalted)", description: "Late evening snack — critical for liver cirrhosis to prevent hypoglycemia", estimatedCalories: 200, estimatedProtein: 7, estimatedCarbs: 22, estimatedFat: 9, servingNote: "4 crackers + 1 tbsp PB", isRequired: true)
                    ],
                    targetCalories: 200,
                    notes: "IMPORTANT: This late-evening snack is medically recommended. Prevents overnight hypoglycemia in cirrhosis."
                )
            ]

        default:
            let g = condition.dietaryGuidelines
            return [
                DailyMealTemplate(
                    mealType: .breakfast,
                    suggestedFoods: [
                        SuggestedFood(name: "Balanced breakfast", description: g.recommendations.first ?? "", estimatedCalories: g.dailyCaloricTarget * 0.25, estimatedProtein: g.proteinTarget * 0.25, estimatedCarbs: g.carbTarget * 0.25, estimatedFat: g.fatTarget * 0.25, servingNote: "See recommendations")
                    ],
                    targetCalories: g.dailyCaloricTarget * 0.25
                ),
                DailyMealTemplate(
                    mealType: .lunch,
                    suggestedFoods: [
                        SuggestedFood(name: "Balanced lunch", description: "", estimatedCalories: g.dailyCaloricTarget * 0.35, estimatedProtein: g.proteinTarget * 0.35, estimatedCarbs: g.carbTarget * 0.35, estimatedFat: g.fatTarget * 0.35, servingNote: "See guidelines")
                    ],
                    targetCalories: g.dailyCaloricTarget * 0.35
                ),
                DailyMealTemplate(
                    mealType: .dinner,
                    suggestedFoods: [
                        SuggestedFood(name: "Balanced dinner", description: "", estimatedCalories: g.dailyCaloricTarget * 0.3, estimatedProtein: g.proteinTarget * 0.3, estimatedCarbs: g.carbTarget * 0.3, estimatedFat: g.fatTarget * 0.3, servingNote: "See guidelines")
                    ],
                    targetCalories: g.dailyCaloricTarget * 0.3
                ),
                DailyMealTemplate(
                    mealType: .snack,
                    suggestedFoods: [
                        SuggestedFood(name: "Healthy snack", description: "", estimatedCalories: g.dailyCaloricTarget * 0.1, estimatedProtein: g.proteinTarget * 0.1, estimatedCarbs: g.carbTarget * 0.1, estimatedFat: g.fatTarget * 0.1, servingNote: "See guidelines")
                    ],
                    targetCalories: g.dailyCaloricTarget * 0.1
                )
            ]
        }
    }
}
