import Foundation
import UserNotifications

/// Schedules one personalized local reminder per day (7pm). The body is
/// rebuilt from current stats every time the app backgrounds, so the nudge
/// always reflects the player's actual streak and worst leak — never a
/// generic "come back!".
enum ReminderScheduler {
    private static let identifier = "daily_training_reminder"
    static let enabledKey = "dailyReminderEnabled"

    /// Ask for permission and schedule; reports back whether the user allowed it.
    @MainActor
    static func enable(stats: Stats, completion: @escaping @MainActor (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                if granted { refresh(stats: stats) }
                completion(granted)
            }
        }
    }

    static func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Whether the OS still allows this app to notify — the in-app toggle can
    /// go stale if the user revokes permission from system Settings.
    static func checkAuthorization(completion: @escaping @MainActor (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            Task { @MainActor in completion(ok) }
        }
    }

    /// Re-schedule tomorrow's reminder with fresh personalized copy.
    /// Safe to call often; it replaces the pending request in place.
    @MainActor
    static func refresh(stats: Stats) {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Blackjack Trainer"
        content.body = body(for: stats)
        content.sound = .default

        var time = DateComponents()
        time.hour = 19
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    /// The most motivating true thing we can say: a streak to protect beats a
    /// leak to fix beats a generic nudge.
    @MainActor
    private static func body(for stats: Stats) -> String {
        let streak = stats.dailyStreak
        let goal = stats.data.dailyGoal

        if streak > 0 && stats.todayDecisions < goal {
            return "Your \(streak)-day streak is on the line — \(goal) quick decisions keeps it alive."
        }
        if let worst = stats.weakestSpots.first {
            let pct = Int(worst.stat.accuracy * 100)
            return "\(SpotID.displayName(worst.key)) is at \(pct)% — a 2-minute Smart quiz can fix it."
        }
        return "A few hands a day is how basic strategy sticks. Deal yourself in."
    }
}
