//
//  AppDelegateTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/25/26.
//

import Testing
import UserNotifications
import SwiftData
@testable import Kubb_Coach

/// Tests for AppDelegate notification and deep link handling
@Suite("AppDelegate Tests")
struct AppDelegateTests {

    // MARK: - Deep Link Router Tests

    @Test("Deep link routing for notification categories")
    func testNotificationCategoryDeepLinks() {
        // Test each notification category maps to correct deep link
        #expect(NotificationCategory.streakWarning.deepLink == "kubbcoach://home/start-session")
        #expect(NotificationCategory.dailyChallenge.deepLink == "kubbcoach://journey/daily-challenge")
        #expect(NotificationCategory.comebackPrompt.deepLink == "kubbcoach://home/start-session")
        #expect(NotificationCategory.preCompetition.deepLink == "kubbcoach://home/training-selection")
    }

    @Test("Deep link validation accepts valid URLs")
    func testValidDeepLinkURLs() {
        // Valid URLs should pass validation
        let validURLs = [
            "kubbcoach://home",
            "kubbcoach://home/start-session",
            "kubbcoach://home/training-selection",
            "kubbcoach://journey/daily-challenge",
            "kubbcoach://settings",
            "kubbcoach://history",
            "kubbcoach://statistics"
        ]

        for urlString in validURLs {
            #expect(DeepLinkRouter.isValid(urlString: urlString), "Expected \(urlString) to be valid")
        }
    }

    @Test("Deep link validation rejects invalid URLs")
    func testInvalidDeepLinkURLs() {
        // Invalid URLs should fail validation
        let invalidURLs = [
            "https://example.com",  // Wrong scheme
            "kubbcoach://invalid-host",  // Invalid host
            "kubbcoach://home/invalid-path",  // Invalid path
            "http://kubbcoach.com",  // HTTP scheme
            "kubbcoach://",  // No host
            "not-a-url",  // Not a URL
            ""  // Empty string
        ]

        for urlString in invalidURLs {
            #expect(!DeepLinkRouter.isValid(urlString: urlString), "Expected \(urlString) to be invalid")
        }
    }

    @Test("Deep link router returns correct URL for category identifier")
    func testDeepLinkForCategoryIdentifier() {
        // Test known categories
        #expect(DeepLinkRouter.deepLink(forCategoryIdentifier: "STREAK_WARNING") == "kubbcoach://home/start-session")
        #expect(DeepLinkRouter.deepLink(forCategoryIdentifier: "DAILY_CHALLENGE") == "kubbcoach://journey/daily-challenge")
        #expect(DeepLinkRouter.deepLink(forCategoryIdentifier: "COMEBACK_PROMPT") == "kubbcoach://home/start-session")
        #expect(DeepLinkRouter.deepLink(forCategoryIdentifier: "PRE_COMPETITION") == "kubbcoach://home/training-selection")

        // Test unknown category returns default
        #expect(DeepLinkRouter.deepLink(forCategoryIdentifier: "UNKNOWN") == "kubbcoach://home")
        #expect(DeepLinkRouter.deepLink(forCategoryIdentifier: "") == "kubbcoach://home")
    }

    @Test("Notification category enum properties")
    func testNotificationCategoryProperties() {
        // Test display names
        #expect(NotificationCategory.streakWarning.displayName == "Streak Warning")
        #expect(NotificationCategory.dailyChallenge.displayName == "Daily Challenge")
        #expect(NotificationCategory.comebackPrompt.displayName == "Comeback Prompt")
        #expect(NotificationCategory.preCompetition.displayName == "Pre-Competition")

        // Test raw values
        #expect(NotificationCategory.streakWarning.rawValue == "STREAK_WARNING")
        #expect(NotificationCategory.dailyChallenge.rawValue == "DAILY_CHALLENGE")
        #expect(NotificationCategory.comebackPrompt.rawValue == "COMEBACK_PROMPT")
        #expect(NotificationCategory.preCompetition.rawValue == "PRE_COMPETITION")

        // Test enum can be created from raw value
        #expect(NotificationCategory(rawValue: "STREAK_WARNING") == .streakWarning)
        #expect(NotificationCategory(rawValue: "UNKNOWN") == nil)
    }

    @Test("All notification categories are represented")
    func testNotificationCategoryCompleteness() {
        // Ensure all cases are covered
        let allCategories = NotificationCategory.allCases
        #expect(allCategories.count == 4)
        #expect(allCategories.contains(.streakWarning))
        #expect(allCategories.contains(.dailyChallenge))
        #expect(allCategories.contains(.comebackPrompt))
        #expect(allCategories.contains(.preCompetition))
    }

    // MARK: - TrainingSessionManager Query Tests

    @Test("getMostRecentSession returns nil when no sessions exist")
    @MainActor
    func testGetMostRecentSessionEmpty() async throws {
        // Create in-memory model container for testing
        let schema = Schema([TrainingSession.self, TrainingRound.self, ThrowRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let manager = TrainingSessionManager(modelContext: context)

        // Should return nil when no sessions exist
        let result = try manager.getMostRecentSession()
        #expect(result == nil)
    }

    @Test("getMostRecentSession returns most recent session")
    @MainActor
    func testGetMostRecentSessionWithData() async throws {
        // Create in-memory model container for testing
        let schema = Schema([TrainingSession.self, TrainingRound.self, ThrowRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // Create test sessions at different times
        let oldDate = Date().addingTimeInterval(-86400 * 7) // 7 days ago
        let recentDate = Date().addingTimeInterval(-86400 * 2) // 2 days ago

        let oldSession = TrainingSession(phase: .eightMeters, sessionType: .accuracy, configuredRounds: 3, startingBaseline: .north)
        oldSession.createdAt = oldDate
        context.insert(oldSession)

        let recentSession = TrainingSession(phase: .fourMetersBlasting, sessionType: .blasting, configuredRounds: 9, startingBaseline: .north)
        recentSession.createdAt = recentDate
        context.insert(recentSession)

        try context.save()

        let manager = TrainingSessionManager(modelContext: context)

        // Should return the most recent session
        let result = try manager.getMostRecentSession()
        #expect(result != nil)
        #expect(result?.id == recentSession.id)
        #expect(result?.phase == .fourMetersBlasting)
    }

    // MARK: - Integration Tests

    @Test("Deep link notification name is consistent")
    func testDeepLinkNotificationName() {
        // Ensure notification name matches
        #expect(Notification.Name.handleDeepLink == DeepLinkRouter.notificationName)
        #expect(DeepLinkRouter.notificationName.rawValue == "HandleDeepLink")
    }

    @Test("Deep link router URL key is consistent")
    func testDeepLinkURLKey() {
        // Ensure URL key is correct
        #expect(DeepLinkRouter.urlKey == "url")
    }

    @Test("Valid hosts are comprehensive")
    func testValidHostsCoverage() {
        // Test all expected valid hosts
        let expectedValidHosts = ["home", "journey", "settings", "history", "statistics"]

        for host in expectedValidHosts {
            let url = URL(string: "kubbcoach://\(host)")!
            #expect(DeepLinkRouter.isValid(url: url), "Expected \(host) to be a valid host")
        }
    }

    @Test("Valid paths are comprehensive")
    func testValidPathsCoverage() {
        // Test all expected valid paths
        let expectedValidPaths = [
            "",  // Empty path (host-only URL)
            "/start-session",
            "/training-selection",
            "/daily-challenge"
        ]

        for path in expectedValidPaths {
            let url = URL(string: "kubbcoach://home\(path)")!
            #expect(DeepLinkRouter.isValid(url: url), "Expected path '\(path)' to be valid")
        }
    }

    @Test("URL validation is case-sensitive for scheme")
    func testURLSchemeCase() {
        // Scheme should be case-sensitive (kubbcoach, not KubbCoach)
        #expect(DeepLinkRouter.isValid(urlString: "kubbcoach://home"))
        #expect(!DeepLinkRouter.isValid(urlString: "KUBBCOACH://home"))
        #expect(!DeepLinkRouter.isValid(urlString: "KubbCoach://home"))
    }

    @Test("URL validation handles malformed URLs gracefully")
    func testMalformedURLHandling() {
        // Should not crash on malformed URLs
        let malformedURLs = [
            "kubbcoach:/",  // Missing second slash
            "kubbcoach:///home",  // Extra slash
            "kubbcoach://home//path",  // Double slash in path
            "://home",  // Missing scheme
            "kubbcoach://",  // No host
            "kubbcoach://home?query=value"  // Query parameters (not validated, but should work)
        ]

        for urlString in malformedURLs {
            // Should not crash, just return valid/invalid
            _ = DeepLinkRouter.isValid(urlString: urlString)
        }
    }
}

/// Mock notification service for testing (if needed in future)
@MainActor
class MockNotificationService {
    var scheduledNotifications: [String] = []
    var isAuthorizedValue: Bool = true

    func isAuthorized() async -> Bool {
        return isAuthorizedValue
    }

    func scheduleComebackReminder(daysSinceLastSession: Int) async {
        scheduledNotifications.append("comeback_\(daysSinceLastSession)")
    }
}
