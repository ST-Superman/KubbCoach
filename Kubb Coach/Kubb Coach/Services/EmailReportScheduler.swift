//
//  EmailReportScheduler.swift
//  Kubb Coach
//

import Foundation
import UserNotifications
import OSLog

/// Schedules the recurring "weekly report is ready" local notification.
///
/// iOS sandboxes do not allow silent email sending, so the autonomous-email
/// feature is implemented as a notification that, when tapped, opens
/// `MFMailComposeViewController` pre-populated with the report. The user
/// confirms with one tap on Send.
///
/// One pending notification at a time, keyed by `notificationIdentifier` so
/// repeated calls to `scheduleNext(...)` idempotently replace any existing one.
@MainActor
final class EmailReportScheduler {
    static let shared = EmailReportScheduler()

    static let notificationIdentifier = "weekly-email-report"
    static let notificationCategory = "WEEKLY_EMAIL_REPORT"

    /// Hardcoded delivery time for V1. Configurable picker deferred to V1.1.
    private static let fireHour = 8
    private static let fireMinute = 0
    /// Gregorian weekday for Sunday (Cocoa weekday numbering: Sun=1 … Sat=7).
    private static let fireWeekday = 1

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.sathomps.kubbcoach", category: "email-report-scheduler")

    private init() {}

    // MARK: - Permission

    /// Ensures notification authorization is in a state that allows scheduling.
    /// Requests permission if it has never been asked. Returns true if scheduling
    /// is permitted (authorized / provisional / ephemeral), false if denied.
    func requestPermissionIfNeeded() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await NotificationService.shared.requestAuthorization()
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedules the next email-report notification based on the user's
    /// frequency setting and `lastSentAt`. Replaces any pending one.
    /// - Returns: the scheduled fire date, or nil if scheduling was skipped
    ///   (feature disabled or notifications denied).
    @discardableResult
    func scheduleNext(for settings: EmailReportSettings, now: Date = Date()) async -> Date? {
        guard settings.isEnabled else {
            await cancelScheduled()
            return nil
        }
        guard await requestPermissionIfNeeded() else {
            logger.warning("Skipping schedule — notification permission not granted")
            return nil
        }

        let fireDate = Self.nextFireDate(
            frequency: settings.frequency,
            lastSentAt: settings.lastSentAt,
            now: now
        )

        let content = UNMutableNotificationContent()
        content.title = "Your Kubb week, in review"
        content.body = "Tap to send this week's training report."
        content.sound = .default
        content.categoryIdentifier = Self.notificationCategory

        // Schedule with a specific calendar moment (year/month/day/hour/minute).
        // We do NOT use repeats: the next occurrence is re-scheduled after each
        // fire (or after the user successfully sends), which lets biweekly/monthly
        // share the same code path as weekly without needing a repeating trigger.
        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        // Replace any prior pending request with the same identifier.
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])

        do {
            try await center.add(request)
            logger.info("Scheduled email report notification for \(fireDate, privacy: .public)")
            return fireDate
        } catch {
            logger.error("Failed to schedule email report notification: \(error.localizedDescription)")
            return nil
        }
    }

    /// Removes any pending email-report notification. Idempotent.
    func cancelScheduled() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        logger.info("Cancelled email report notification (if any)")
    }

    /// Returns the next fire date of the pending email-report notification, if one is scheduled.
    func nextScheduledFireDate() async -> Date? {
        let pending = await center.pendingNotificationRequests()
        guard let request = pending.first(where: { $0.identifier == Self.notificationIdentifier }),
              let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return nil
        }
        return trigger.nextTriggerDate()
    }

    /// True iff a notification with our identifier is currently pending delivery.
    func hasPendingNotification() async -> Bool {
        let pending = await center.pendingNotificationRequests()
        return pending.contains { $0.identifier == Self.notificationIdentifier }
    }

    // MARK: - Fire-date computation (pure, testable)

    /// Computes the next Sunday at `fireHour:fireMinute` local that is on or
    /// after `max(now, lastSentAt + dayInterval)`. If `lastSentAt` is nil, the
    /// floor is just `now`.
    ///
    /// This means biweekly/monthly frequencies still land on Sunday — they may
    /// just skip one or more Sundays to honor the configured cadence.
    static func nextFireDate(
        frequency: ReportFrequency,
        lastSentAt: Date?,
        now: Date = Date()
    ) -> Date {
        let calendar = Calendar.current
        let dayInterval = frequency.dayInterval

        let earliest: Date
        if let lastSentAt {
            let cooldown = calendar.date(byAdding: .day, value: dayInterval, to: lastSentAt) ?? now
            earliest = max(now, cooldown)
        } else {
            earliest = now
        }

        var components = DateComponents()
        components.weekday = fireWeekday
        components.hour = fireHour
        components.minute = fireMinute

        // `nextDate(after:)` is strictly-after, so subtract one second to allow
        // an exact-match (Sunday 8:00:00 AM) `earliest` to qualify.
        let searchFrom = earliest.addingTimeInterval(-1)
        return calendar.nextDate(
            after: searchFrom,
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        ) ?? earliest
    }
}

// MARK: - Routing

extension Notification.Name {
    /// Posted by AppDelegate when the user taps the email-report notification.
    /// Observed by the root view to present `MFMailComposeViewController`.
    static let presentEmailReportComposer = Notification.Name("PresentEmailReportComposer")
}
