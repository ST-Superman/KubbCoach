//
//  AppDelegate.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import UIKit
import UserNotifications
import OSLog
import SwiftData

/// AppDelegate for handling notification responses and app lifecycle events
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: "com.sathomps.kubbcoach", category: "appdelegate")

    /// Model container provided by the app (set during app initialization)
    var modelContainer: ModelContainer?

    /// Injected session manager for testing (defaults to nil, uses app container)
    var sessionManager: TrainingSessionManager?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        logger.info("AppDelegate initialized - notification delegate set")

        // Check for comeback notifications on app launch
        Task { @MainActor in
            await checkForComebackNotifications()
        }

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification is delivered while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logger.info("Notification received in foreground: \(notification.request.identifier)")

        // Show banner, sound, and badge even when app is open
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when user taps on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let category = response.notification.request.content.categoryIdentifier

        logger.info("Notification tapped - ID: \(identifier), Category: \(category)")

        // Handle notification response based on category
        Task { @MainActor in
            await handleNotificationResponse(category: category, identifier: identifier)
        }

        completionHandler()
    }

    // MARK: - Notification Response Handling

    /// Handle notification tap by deep linking to appropriate screen
    /// - Parameters:
    ///   - category: The notification category identifier
    ///   - identifier: The notification identifier
    @MainActor
    private func handleNotificationResponse(category: String, identifier: String) async {
        // Get deep link URL using router
        let deepLink = DeepLinkRouter.deepLink(forCategoryIdentifier: category)

        // Log the category and resulting deep link
        if let notificationCategory = NotificationCategory(rawValue: category) {
            logger.info("Deep linking to \(deepLink) for \(notificationCategory.displayName)")
        } else {
            logger.warning("Unknown notification category: \(category), using default home link")
        }

        // Post notification with deep link URL for SwiftUI to handle
        NotificationCenter.default.post(
            name: .handleDeepLink,
            object: nil,
            userInfo: [DeepLinkRouter.urlKey: deepLink]
        )
    }

    // MARK: - Comeback Notification Logic

    /// Check if user should receive comeback notification based on inactivity
    @MainActor
    private func checkForComebackNotifications() async {
        // Only check if notifications are authorized
        guard await NotificationService.shared.isAuthorized() else {
            logger.debug("Skipping comeback check - notifications not authorized")
            return
        }

        guard NotificationService.shared.isNotificationTypeEnabled(.comebackPrompt) else {
            logger.debug("Skipping comeback check - comeback prompts disabled by user")
            return
        }

        // Get session manager from app container or use injected one (for testing)
        guard let modelContext = getModelContext() else {
            logger.error("Failed to access model context for comeback notification check")
            return
        }

        let manager = sessionManager ?? TrainingSessionManager(modelContext: modelContext)

        do {
            // Query most recent session
            guard let lastSession = try manager.getMostRecentSession() else {
                // No sessions yet, don't schedule comeback notification
                logger.info("No previous sessions found, skipping comeback notification")
                return
            }

            // Calculate days since last activity
            let daysSinceLastSession = Calendar.current.dateComponents(
                [.day],
                from: lastSession.createdAt,
                to: Date()
            ).day ?? 0

            logger.info("Last session was \(daysSinceLastSession) days ago")

            // Schedule comeback notification if user has been inactive for 3+ days
            if daysSinceLastSession >= 3 {
                await NotificationService.shared.scheduleComebackReminder(daysSinceLastSession: daysSinceLastSession)
                logger.info("Scheduled comeback notification (inactive for \(daysSinceLastSession) days)")
            } else {
                logger.info("User active recently (\(daysSinceLastSession) days ago), no comeback needed")
            }
        } catch {
            logger.error("Failed to check for comeback notifications: \(error.localizedDescription)")
        }
    }

    /// Get ModelContext from app container
    @MainActor
    private func getModelContext() -> ModelContext? {
        guard let container = modelContainer else {
            logger.debug("Model container not yet available")
            return nil
        }
        return ModelContext(container)
    }
}

// MARK: - Deep Link Support

/// Extension to provide deep link URL scheme support
extension AppDelegate {
    /// Registers custom URL scheme handler for deep links
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        logger.info("Opening URL: \(url.absoluteString)")

        // Validate deep link URL
        guard DeepLinkRouter.isValid(url: url) else {
            logger.warning("Rejected invalid deep link: \(url.absoluteString)")
            return false
        }

        logger.info("Accepted valid deep link: \(url.absoluteString)")

        // Post notification for SwiftUI to handle navigation
        NotificationCenter.default.post(
            name: .handleDeepLink,
            object: nil,
            userInfo: [DeepLinkRouter.urlKey: url.absoluteString]
        )

        return true
    }
}
