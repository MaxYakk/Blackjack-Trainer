import Foundation
import UserNotifications

/// Schedules a single, non-repeating local reminder for the next 7pm, with
/// text computed at scheduling time. It is skipped for today when the daily
/// goal is already met, and rebuilt whenever the app backgrounds/foregrounds,
/// so it never announces a streak that has since broken.
enum ReminderScheduler {
    private static let identifier = "daily_training_reminder"
    static let enabledKey = "dailyReminderEnabled"

    /// Ask for permission and schedule; reports back whether the user allowed it.
    @MainActor
    static func enable(stats: Stats, completion: @escaping @MainActor (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
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

    /// Next 7pm strictly in the future; today's slot is skipped when the goal
    /// is already met (or 7pm has passed).
    static func nextFireDate(now: Date, goalMet: Bool, calendar: Calendar = .current) -> Date? {
        guard let today = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) else { return nil }
        if today > now && !goalMet { return today }
        return calendar.date(byAdding: .day, value: 1, to: today)
    }

    /// Re-schedule the next reminder with fresh copy. Safe to call often;
    /// it replaces the pending request in place.
    @MainActor
    static func refresh(stats: Stats) {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }

        let now = Date()
        let goalMet = stats.todayDecisions >= stats.data.dailyGoal
        guard let fire = nextFireDate(now: now, goalMet: goalMet) else { return }
        // Tomorrow's copy: today's progress no longer counts, so the streak
        // is only "on the line" if it is still alive when that day starts.
        let isToday = Calendar.current.isDate(fire, inSameDayAs: now)

        let content = UNMutableNotificationContent()
        content.title = "Blackjack Trainer"
        content.body = body(for: stats, firesToday: isToday)
        content.sound = .default

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    /// The most motivating true thing we can say: a streak to protect beats a
    /// leak to fix beats a generic nudge.
    @MainActor
    private static func body(for stats: Stats, firesToday: Bool) -> String {
        let streak = stats.dailyStreak
        let goal = stats.data.dailyGoal

        let goalMet = stats.todayDecisions >= goal
        // Firing today: streak is at risk only if the goal is unmet. Firing
        // tomorrow: the streak survives only if today's goal was met.
        let streakAtRisk = firesToday ? !goalMet : goalMet
        if streak > 0 && streakAtRisk {
            return "Your \(streak)-day streak is on the line — \(goal) quick decisions keeps it alive."
        }
        if let worst = stats.weakestSpots.first {
            let pct = Int(worst.stat.accuracy * 100)
            return "\(SpotID.displayName(worst.key)) is at \(pct)% — a 2-minute Smart quiz can fix it."
        }
        return "A few hands a day is how basic strategy sticks. Deal yourself in."
    }
}
