import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var nutrition: NutritionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date selector
                    DateHeader(date: $nutrition.selectedDate)

                    // Calorie ring card
                    CalorieRingCard()

                    // Macro bars
                    MacroBarsCard()

                    // Active meal plan banner
                    if let plan = nutrition.activeMealPlan {
                        MealPlanBanner(plan: plan)
                    }

                    // Medical condition guidelines
                    if nutrition.profile.medicalCondition != .none {
                        ConditionGuidelineTile(condition: nutrition.profile.medicalCondition)
                    }

                    // Today's meals preview
                    TodayMealsCard()

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        nutrition.selectedDate = Date()
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                }
            }
        }
        .onAppear { nutrition.refreshToday() }
    }
}

// MARK: - Date Header

private struct DateHeader: View {
    @Binding var date: Date
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .full; return f
    }()

    var body: some View {
        HStack {
            Button { date = Calendar.current.date(byAdding: .day, value: -1, to: date)! }
            label: { Image(systemName: "chevron.left").font(.title3) }

            Spacer()
            Text(Self.fmt.string(from: date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Calendar.current.isDateInToday(date) ? .primary : .secondary)
            Spacer()

            Button { date = Calendar.current.date(byAdding: .day, value: 1, to: date)! }
            label: { Image(systemName: "chevron.right").font(.title3) }
            .disabled(Calendar.current.isDateInToday(date))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Calorie Ring Card

private struct CalorieRingCard: View {
    @EnvironmentObject var nutrition: NutritionViewModel

    var body: some View {
        let summary = nutrition.todaySummary
        let limit   = nutrition.profile.dailyCaloricLimit
        let progress = limit > 0 ? min(summary.totalCalories / limit, 1.0) : 0

        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(summary.totalCalories.calorieString)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("of \(Int(limit)) goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progress > 1 ? Color.red : Color.orange,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.bold))
                }
                .frame(width: 70, height: 70)
            }
            .padding()

            Divider().padding(.horizontal)

            HStack(spacing: 0) {
                StatPill(label: "Remaining", value: nutrition.caloriesRemaining.calorieString, unit: "kcal", color: .green)
                Divider().frame(height: 40)
                StatPill(label: "Goal", value: Int(limit).description, unit: "kcal", color: .orange)
                Divider().frame(height: 40)
                StatPill(label: "Entries", value: "\(nutrition.todaySummary.entries.count)", unit: "foods", color: .blue)
            }
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct StatPill: View {
    let label: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Macro Bars Card

private struct MacroBarsCard: View {
    @EnvironmentObject var nutrition: NutritionViewModel

    var body: some View {
        let summary = nutrition.todaySummary
        let profile = nutrition.profile

        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            VStack(spacing: 10) {
                MacroBar(label: "Protein", current: summary.totalProtein, goal: profile.proteinGoal, color: .blue, unit: "g")
                MacroBar(label: "Carbs",   current: summary.totalCarbs,   goal: profile.carbGoal,    color: .orange, unit: "g")
                MacroBar(label: "Fat",     current: summary.totalFat,     goal: profile.fatGoal,     color: .yellow, unit: "g")
                MacroBar(label: "Fiber",   current: summary.totalFiber,   goal: profile.fiberGoal,   color: .green, unit: "g")
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MacroBar: View {
    let label: String; let current: Double; let goal: Double; let color: Color; let unit: String
    var progress: Double { goal > 0 ? min(current / goal, 1.0) : 0 }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(current.macroString)\(unit)").font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Text("/ \(Int(goal))\(unit)").font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Meal Plan Banner

private struct MealPlanBanner: View {
    let plan: MealPlan

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.teal)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Active Meal Plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(plan.name)
                    .font(.subheadline.weight(.semibold))
                Text("By \(plan.doctorName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Condition Guideline Tile

private struct ConditionGuidelineTile: View {
    let condition: MedicalCondition
    @State private var isExpanded = false

    var body: some View {
        let guidelines = condition.dietaryGuidelines

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: condition.icon)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.indigo)
                        .clipShape(Circle())
                    VStack(alignment: .leading) {
                        Text("Diet Guidelines")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(guidelines.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal)
                VStack(alignment: .leading, spacing: 8) {
                    Text(guidelines.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    if !guidelines.recommendations.isEmpty {
                        Text("Key Recommendations")
                            .font(.caption.weight(.semibold))
                        ForEach(guidelines.recommendations.prefix(4), id: \.self) { rec in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                                Text(rec).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !guidelines.avoid.isEmpty {
                        Text("Avoid").font(.caption.weight(.semibold)).padding(.top, 4)
                        ForEach(guidelines.avoid.prefix(3), id: \.self) { item in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                                Text(item).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Today Meals Card

private struct TodayMealsCard: View {
    @EnvironmentObject var nutrition: NutritionViewModel

    var body: some View {
        let byMeal = nutrition.todaySummary.entriesByMeal

        VStack(alignment: .leading, spacing: 0) {
            Text("Today's Meals")
                .font(.headline)
                .padding()

            if nutrition.todaySummary.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No food logged yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Text("Tap the Scan tab to add food")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            } else {
                ForEach(FoodEntry.MealType.allCases, id: \.self) { mealType in
                    if let entries = byMeal[mealType], !entries.isEmpty {
                        MealSectionRow(mealType: mealType, entries: entries)
                        Divider().padding(.leading, 50)
                    }
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MealSectionRow: View {
    let mealType: FoodEntry.MealType
    let entries: [FoodEntry]

    var totalCal: Double { entries.reduce(0) { $0 + $1.scaledCalories } }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mealType.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.orange)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(mealType.rawValue).font(.subheadline.weight(.semibold))
                Text(entries.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(Int(totalCal)) kcal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
