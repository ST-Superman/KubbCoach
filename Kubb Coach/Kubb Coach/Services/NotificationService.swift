//
//  NotificationService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import Foundation
import UserNotifications
import SwiftData
import OSLog

/// Service for managing local push notifications
/// Handles permission requests, scheduling, and cancellation of notifications
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.sathomps.kubbcoach", category: "notifications")

    private init() {}

    // MARK: - Permission Management

    /// Request notification authorization from the user
    /// - Returns: True if permission was granted, false otherwise
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification permission request result: \(granted)")

            // Store permission status in UserDefaults
            UserDefaults.standard.set(granted, forKey: "notification_permission_granted")
            UserDefaults.standard.set(true, forKey: "notification_permission_requested")

            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }

    /// Get current notification authorization status
    /// - Returns: The current authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    /// Check if notifications are authorized
    /// - Returns: True if user has granted notification permission
    func isAuthorized() async -> Bool {
        let status = await getAuthorizationStatus()
        return status == .authorized
    }

    // MARK: - Notification Type Preferences

    /// Check if a specific notification type is enabled by user
    /// - Parameter type: The notification type to check
    /// - Returns: True if enabled, false otherwise
    func isNotificationTypeEnabled(_ type: NotificationType) -> Bool {
        let key = "notification_enabled_\(type.rawValue)"
        // Default to true if not explicitly set
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    /// Set whether a specific notification type is enabled
    /// - Parameters:
    ///   - type: The notification type
    ///   - enabled: Whether it should be enabled
    func setNotificationTypeEnabled(_ type: NotificationType, enabled: Bool) {
        let key = "notification_enabled_\(type.rawValue)"
        UserDefaults.standard.set(enabled, forKey: key)
        logger.info("Notification type \(type.rawValue) set to \(enabled)")
    }

    // MARK: - Streak Warning Notifications

    /// Schedule a streak warning notification for this evening if user hasn't trained today
    /// - Parameter streakDays: Current streak length in days
    func scheduleStreakReminder(streakDays: Int) async {
        guard await isAuthorized() else { return }
        guard isNotificationTypeEnabled(.streakWarning) else { return }

        // Cancel existing streak reminders
        await cancelStreakReminders()

        // Schedule for 6 PM today
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 18  // 6 PM
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Streak at Risk! 🔥"
        content.body = "Don't break your \(streakDays)-day streak! Complete a session before midnight."
        content.sound = .default
        content.categoryIdentifier = "STREAK_WARNING"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak_warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            logger.info("Scheduled streak reminder for 6 PM")
        } catch {
            logger.error("Failed to schedule streak reminder: \(error.localizedDescription)")
        }
    }

    /// Cancel all streak warning notifications
    func cancelStreakReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let streakIdentifiers = pending
            .filter { $0.identifier.hasPrefix("streak_warning_") }
            .map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: streakIdentifiers)
        logger.info("Cancelled \(streakIdentifiers.count) streak reminders")
    }

    // MARK: - Daily Challenge Notifications

    /// Schedule daily challenge notification for tomorrow morning
    /// - Parameter challengeDescription: Description of the challenge
    func scheduleDailyChallenge(description challengeDescription: String) async {
        guard await isAuthorized() else { return }
        guard isNotificationTypeEnabled(.dailyChallenge) else { return }

        // Schedule for 9 AM tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9  // 9 AM
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Today's Challenge 🎯"
        content.body = challengeDescription
        content.sound = .default
        content.categoryIdentifier = "DAILY_CHALLENGE"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "daily_challenge_tomorrow",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            logger.info("Scheduled daily challenge for 9 AM tomorrow")
        } catch {
            logger.error("Failed to schedule daily challenge: \(error.localizedDescription)")
        }
    }

    /// Schedule daily challenge reminder for tomorrow (fetches current challenge)
    /// This is called automatically after session completion
    func scheduleDailyChallengeReminder() async {
        guard await isAuthorized() else { return }
        guard isNotificationTypeEnabled(.dailyChallenge) else { return }

        // Schedule for 9 AM tomorrow with generic message
        // (We don't know tomorrow's challenge yet, so use a generic message)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9  // 9 AM
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Today's Challenge 🎯"
        content.body = "A new daily challenge is waiting for you!"
        content.sound = .default
        content.categoryIdentifier = "DAILY_CHALLENGE"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "daily_challenge_tomorrow",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            logger.info("Scheduled daily challenge reminder for 9 AM tomorrow")
        } catch {
            logger.error("Failed to schedule daily challenge reminder: \(error.localizedDescription)")
        }
    }

    /// Cancel all daily challenge notifications
    func cancelDailyChallengeReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let challengeIdentifiers = pending
            .filter { $0.identifier.hasPrefix("daily_challenge_") }
            .map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: challengeIdentifiers)
        logger.info("Cancelled \(challengeIdentifiers.count) daily challenge reminders")
    }

    // MARK: - Comeback Notifications

    /// Schedule comeback notification after inactivity
    /// - Parameter daysSinceLastSession: Number of days since last training session
    func scheduleComebackReminder(daysSinceLastSession: Int) async {
        guard await isAuthorized() else { return }
        guard isNotificationTypeEnabled(.comebackPrompt) else { return }

        // Only schedule on specific days: 3, 7, 14
        guard [3, 7, 14].contains(daysSinceLastSession) else { return }

        // Check if we've already sent a comeback notification recently
        let lastComebackKey = "last_comeback_notification_date"
        if let lastDate = UserDefaults.standard.object(forKey: lastComebackKey) as? Date {
            let daysSinceLastNotification = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if daysSinceLastNotification < 3 {
                logger.info("Skipping comeback notification - sent one \(daysSinceLastNotification) days ago")
                return
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "We Miss You! 💪"
        content.body = "Your last session was \(daysSinceLastSession) days ago. Ready to get back at it?"
        content.sound = .default
        content.categoryIdentifier = "COMEBACK_PROMPT"

        // Schedule for 1 hour from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(
            identifier: "comeback_\(daysSinceLastSession)_days",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            UserDefaults.standard.set(Date(), forKey: lastComebackKey)
            logger.info("Scheduled comeback reminder for \(daysSinceLastSession) days inactivity")
        } catch {
            logger.error("Failed to schedule comeback reminder: \(error.localizedDescription)")
        }
    }

    /// Cancel all comeback notifications
    func cancelComebackReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let comebackIdentifiers = pending
            .filter { $0.identifier.hasPrefix("comeback_") }
            .map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: comebackIdentifiers)

        // Reset the last comeback notification date
        UserDefaults.standard.removeObject(forKey: "last_comeback_notification_date")

        logger.info("Cancelled \(comebackIdentifiers.count) comeback reminders")
    }

    // MARK: - Pre-Competition Notifications

    /// Schedule pre-competition countdown notifications
    /// - Parameter competitionDate: The date of the competition
    func schedulePreCompetitionReminders(competitionDate: Date) async {
        guard await isAuthorized() else { return }
        guard isNotificationTypeEnabled(.preCompetition) else { return }

        // Cancel existing pre-competition notifications
        await cancelPreCompetitionReminders()

        let now = Date()
        let daysUntilCompetition = Calendar.current.dateComponents([.day], from: now, to: competitionDate).day ?? 0

        // Schedule notifications at 7 days, 3 days, and 1 day out
        let milestones = [7, 3, 1]

        for daysOut in milestones {
            guard daysOut <= daysUntilCompetition else { continue }

            // Calculate notification date (daysOut before competition at 9 AM)
            guard let notificationDate = Calendar.current.date(byAdding: .day, value: -daysOut, to: competitionDate) else { continue }
            var components = Calendar.current.dateComponents([.year, .month, .day], from: notificationDate)
            components.hour = 9
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "Tournament Approaching! 🏆"

            if daysOut == 1 {
                content.body = "Your competition is tomorrow - time to sharpen your skills!"
            } else {
                content.body = "Tournament in \(daysOut) days - time to sharpen your skills!"
            }

            content.sound = .default
            content.categoryIdentifier = "PRE_COMPETITION"

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "pre_competition_\(daysOut)_days",
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
                logger.info("Scheduled pre-competition reminder for \(daysOut) days out")
            } catch {
                logger.error("Failed to schedule pre-competition reminder: \(error.localizedDescription)")
            }
        }
    }

    /// Cancel all pre-competition notifications
    func cancelPreCompetitionReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let competitionIdentifiers = pending
            .filter { $0.identifier.hasPrefix("pre_competition_") }
            .map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: competitionIdentifiers)
        logger.info("Cancelled \(competitionIdentifiers.count) pre-competition reminders")
    }

    // MARK: - General Management

    /// Cancel all notifications
    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        logger.info("Cancelled all notifications")
    }

    /// Get count of pending notifications
    /// - Returns: Number of pending notifications
    func getPendingNotificationCount() async -> Int {
        let pending = await notificationCenter.pendingNotificationRequests()
        return pending.count
    }
}

// MARK: - Supporting Types

/// Notification type enumeration for user preferences
enum NotificationType: String, CaseIterable {
    case streakWarning = "streak_warning"
    case dailyChallenge = "daily_challenge"
    case comebackPrompt = "comeback_prompt"
    case preCompetition = "pre_competition"

    var displayName: String {
        switch self {
        case .streakWarning: return "Streak Warnings"
        case .dailyChallenge: return "Daily Challenges"
        case .comebackPrompt: return "Comeback Prompts"
        case .preCompetition: return "Competition Reminders"
        }
    }
}
