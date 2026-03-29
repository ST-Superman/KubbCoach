//
//  DeepLinkRouter.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/25/26.
//

import Foundation

/// Notification category identifiers with type safety
enum NotificationCategory: String, CaseIterable {
    case streakWarning = "STREAK_WARNING"
    case dailyChallenge = "DAILY_CHALLENGE"
    case comebackPrompt = "COMEBACK_PROMPT"
    case preCompetition = "PRE_COMPETITION"

    /// The deep link URL for this notification category
    var deepLink: String {
        switch self {
        case .streakWarning, .comebackPrompt:
            return "kubbcoach://home/start-session"
        case .dailyChallenge:
            return "kubbcoach://journey/daily-challenge"
        case .preCompetition:
            return "kubbcoach://home/training-selection"
        }
    }

    /// Human-readable description for logging
    var displayName: String {
        switch self {
        case .streakWarning:
            return "Streak Warning"
        case .dailyChallenge:
            return "Daily Challenge"
        case .comebackPrompt:
            return "Comeback Prompt"
        case .preCompetition:
            return "Pre-Competition"
        }
    }
}

/// Deep link routing and validation
struct DeepLinkRouter {

    /// Notification name for deep link events
    static let notificationName = Notification.Name("HandleDeepLink")

    /// User info key for deep link URL
    static let urlKey = "url"

    /// Valid deep link hosts (for URL validation)
    private static let validHosts = Set([
        "home",
        "journey",
        "settings",
        "history",
        "statistics"
    ])

    /// Valid deep link paths (for URL validation)
    private static let validPaths = Set([
        "/start-session",
        "/training-selection",
        "/daily-challenge",
        ""  // empty path is valid for host-only URLs
    ])

    /// Get deep link URL for a notification category
    /// - Parameter category: The notification category
    /// - Returns: Deep link URL string
    static func deepLink(for category: NotificationCategory) -> String {
        return category.deepLink
    }

    /// Get deep link URL for a notification category identifier string
    /// - Parameter categoryIdentifier: The category identifier string
    /// - Returns: Deep link URL string, or default home URL if category unknown
    static func deepLink(forCategoryIdentifier categoryIdentifier: String) -> String {
        if let category = NotificationCategory(rawValue: categoryIdentifier) {
            return category.deepLink
        }
        return "kubbcoach://home"
    }

    /// Validate a deep link URL
    /// - Parameter url: The URL to validate
    /// - Returns: True if valid, false otherwise
    static func isValid(url: URL) -> Bool {
        // Must use kubbcoach scheme
        guard url.scheme == "kubbcoach" else {
            return false
        }

        // Must have a valid host
        guard let host = url.host,
              validHosts.contains(host) else {
            return false
        }

        // Path must be valid (or empty)
        let path = url.path
        guard validPaths.contains(path) else {
            return false
        }

        return true
    }

    /// Validate a deep link URL string
    /// - Parameter urlString: The URL string to validate
    /// - Returns: True if valid, false otherwise
    static func isValid(urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        return isValid(url: url)
    }
}

/// Extension to provide typed notification posting
extension Notification.Name {
    /// Notification posted when a deep link should be handled
    static let handleDeepLink = DeepLinkRouter.notificationName
}
