import Foundation
import UserNotifications

/// Local-notification-only streak reminder.
///
/// NOTE ON SCOPE: this covers the one notification feature that's fully
/// achievable without a server — "remind me later today if I haven't kept
/// my streak alive." Real-time push for kudos/comments (someone liked your
/// post *right now*) needs a server component (Firebase Cloud Functions
/// triggering FCM) that has to be deployed separately from this app target;
/// it isn't something a client-only Swift file can do.
enum NotificationManager {
    private static let streakReminderIdentifier = "streakReminder"

    /// Asks for notification permission once. Safe to call every launch —
    /// it's a no-op if the person already answered the system prompt.
    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }

            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { _, _ in }
        }
    }

    /// Schedules a one-time reminder for later *today* at the given time,
    /// but only if the person hasn't completed anything yet today and that
    /// time hasn't already passed. If they've already completed something
    /// today, any pending reminder is cancelled instead — no point nagging
    /// someone who already kept their streak alive.
    ///
    /// Call this whenever you have fresh data on their last completion —
    /// e.g. right after the app loads their profile, and again right after
    /// they complete an activity.
    static func scheduleStreakReminderForToday(
        hour: Int = 19,
        minute: Int = 0,
        alreadyCompletedToday: Bool
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakReminderIdentifier])

        guard !alreadyCompletedToday else { return }

        let calendar = Calendar.current
        let now = Date()

        guard let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now),
              fireDate > now else {
            // That time has already passed today — nothing to schedule
            // until the app is opened again tomorrow.
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Keep your streak going! 🔥"
        content.body = "You haven't completed a sidequest today — don't lose your streak."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireDate.timeIntervalSince(now),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: streakReminderIdentifier,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    static func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [streakReminderIdentifier]
        )
    }
}
