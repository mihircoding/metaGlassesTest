import NutraCore
import SwiftUI
import UserNotifications

/// Daily local notifications reminding the user to log a meal. Nothing leaves the device.
enum MealReminders {
    static let meals: [Meal] = [.breakfast, .lunch, .dinner]

    static func defaultMinutes(_ meal: Meal) -> Int {
        switch meal {
        case .breakfast: return 8 * 60 + 30
        case .lunch: return 12 * 60 + 30
        case .dinner: return 19 * 60
        case .snack: return 15 * 60
        }
    }

    static func enabledKey(_ meal: Meal) -> String { "reminder.\(meal.rawValue).on" }
    static func minutesKey(_ meal: Meal) -> String { "reminder.\(meal.rawValue).minutes" }
    private static func id(_ meal: Meal) -> String { "reminder.\(meal.rawValue)" }

    /// Replaces the meal's pending reminder with one at `minutes` past midnight, or removes it.
    static func schedule(_ meal: Meal, on: Bool, minutes: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id(meal)])
        guard on else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to log \(meal.title.lowercased())"
        content.body = "A quick entry keeps your day on track."
        content.sound = .default
        var when = DateComponents()
        when.hour = minutes / 60
        when.minute = minutes % 60
        let request = UNNotificationRequest(identifier: id(meal), content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        try? await center.add(request)
    }

    /// Asks once; later calls just report the current answer.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }
}

struct RemindersView: View {
    @State private var denied = false

    var body: some View {
        Form {
            Section {
                ForEach(MealReminders.meals, id: \.self) { meal in
                    ReminderRow(meal: meal, onDenied: { denied = true })
                }
            } footer: {
                Text("Reminders come every day at the time you choose, whether or not you've already logged.")
            }
            if denied {
                Section {
                    Text("Notifications are off for NutraVision. Turn them on in Settings to get reminders.")
                        .font(.footnote).foregroundStyle(Theme.bad)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
        }
        .navigationTitle("Reminders")
    }
}

private struct ReminderRow: View {
    let meal: Meal
    let onDenied: () -> Void
    @AppStorage private var on: Bool
    @AppStorage private var minutes: Int

    init(meal: Meal, onDenied: @escaping () -> Void) {
        self.meal = meal
        self.onDenied = onDenied
        _on = AppStorage(wrappedValue: false, MealReminders.enabledKey(meal))
        _minutes = AppStorage(wrappedValue: MealReminders.defaultMinutes(meal), MealReminders.minutesKey(meal))
    }

    /// The stored minutes as a time of day, for the picker.
    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }

    var body: some View {
        Toggle(meal.title, isOn: $on)
            .onChange(of: on) { _, isOn in
                Task {
                    if isOn, !(await MealReminders.requestPermission()) {
                        on = false
                        onDenied()
                        return
                    }
                    await MealReminders.schedule(meal, on: isOn, minutes: minutes)
                }
            }
        if on {
            DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                .onChange(of: minutes) { _, value in Task { await MealReminders.schedule(meal, on: true, minutes: value) } }
        }
    }
}
