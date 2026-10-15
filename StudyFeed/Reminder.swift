import Foundation
import UserNotifications

/// Optional evening nudge when the streak is at risk. Entirely local: no push server.
/// Today's reminder only exists while today isn't done; tomorrow's always does, and is
/// replaced the next time the app learns the day's status.
enum Reminder {
    static let enabledKey = "streakReminderEnabled"
    private static let hour = 20

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Asks for permission when turning it on. Returns whether reminders can fire.
    static func enable() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        UserDefaults.standard.set(granted, forKey: enabledKey)
        return granted
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static let ids = ["streak-today", "streak-tomorrow"]

    static func update(with stats: Stats) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard isEnabled else { return }

        let cal = Calendar.current
        let now = Date()
        if !stats.todayDone, let at = cal.date(bySettingHour: hour, minute: 0, second: 0, of: now), at > now {
            schedule("streak-today", at: at, body: stats.streak > 0
                ? "Your \(stats.streak) day streak ends at midnight. One card keeps it alive."
                : "One card today starts a new streak.")
        }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
           let at = cal.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow) {
            schedule("streak-tomorrow", at: at, body: "Keep your streak going. One card is enough.")
        }
    }

    private static func schedule(_ id: String, at date: Date, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Study"
        content.body = body
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
