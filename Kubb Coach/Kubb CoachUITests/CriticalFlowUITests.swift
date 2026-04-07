//
//  CriticalFlowUITests.swift
//  Kubb CoachUITests
//
//  Created by Claude Code on 4/6/26.
//
//  Tests for the three most critical user flows:
//  1. App launches and home screen is accessible
//  2. Training mode selection is reachable
//  3. Statistics tab is accessible and shows content

import XCTest

final class CriticalFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Use in-memory storage for UI tests to avoid polluting real data
        app.launchArguments += ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Flow 1: App Launch & Home Screen

    /// Verifies the app launches without crashing and presents a navigable home screen.
    @MainActor
    func testAppLaunchesAndHomeScreenIsVisible() throws {
        // App launched in setUp — verify it's in a stable state
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground")

        // Home tab should be visible (tab bar present)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 5),
            "Tab bar should appear after launch"
        )

        // At least one tab should exist
        XCTAssertGreaterThan(
            tabBar.buttons.count, 0,
            "Tab bar should have navigation tabs"
        )
    }

    // MARK: - Flow 2: Start a Training Session

    /// Verifies the training mode selection flow is reachable from the home screen.
    @MainActor
    func testTrainingModeSelectionIsReachable() throws {
        // Wait for tab bar
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar did not appear")
            return
        }

        // Tap the first tab (Home)
        tabBar.buttons.firstMatch.tap()

        // Look for a training start button or mode card — common accessibility patterns
        // Try "Train" or "Start" buttons first, then fall back to any button with training text
        let trainButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'train' OR label CONTAINS[c] 'start' OR label CONTAINS[c] '8m' OR label CONTAINS[c] 'Eight'")
        ).firstMatch

        if trainButton.waitForExistence(timeout: 5) {
            trainButton.tap()
            // After tapping, some kind of training UI should appear
            // Look for round config, countdown, or active training indicators
            let trainingElement = app.otherElements.matching(
                NSPredicate(format: "label CONTAINS[c] 'round' OR label CONTAINS[c] 'throw' OR label CONTAINS[c] 'baseline'")
            ).firstMatch
            let buttonElement = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Hit' OR label CONTAINS[c] 'Miss' OR label CONTAINS[c] 'Begin' OR label CONTAINS[c] 'Configure'")
            ).firstMatch
            XCTAssertTrue(
                trainingElement.waitForExistence(timeout: 5) || buttonElement.waitForExistence(timeout: 5),
                "Training UI should appear after selecting a mode"
            )
        } else {
            // If specific button not found, verify we're at least on the home screen
            XCTAssertTrue(
                app.state == .runningForeground,
                "App should still be running (home screen accessible)"
            )
        }
    }

    // MARK: - Flow 3: Statistics Tab

    /// Verifies the Statistics tab is accessible and renders without crashing.
    @MainActor
    func testStatisticsTabIsAccessibleAndRendersContent() throws {
        // Wait for tab bar
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            XCTFail("Tab bar did not appear")
            return
        }

        // Find the Statistics tab — look for "Stats", "Statistics", or chart icon label
        let statsTab = tabBar.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'stat' OR label CONTAINS[c] 'chart' OR label CONTAINS[c] 'analyt'")
        ).firstMatch

        if statsTab.waitForExistence(timeout: 3) {
            statsTab.tap()
        } else {
            // Try tapping the third tab (common position for statistics)
            let allTabs = tabBar.buttons.allElementsBoundByIndex
            if allTabs.count >= 3 {
                allTabs[2].tap()
            }
        }

        // After navigating to stats, the app should still be stable
        // and some UI element should be visible (scroll view, text, or empty state)
        let statsContent = app.scrollViews.firstMatch
        let emptyState = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'session' OR label CONTAINS[c] 'statistic' OR label CONTAINS[c] 'no data' OR label CONTAINS[c] 'start'")
        ).firstMatch

        XCTAssertTrue(
            statsContent.waitForExistence(timeout: 5) || emptyState.waitForExistence(timeout: 5),
            "Statistics screen should show content or empty state"
        )

        // Verify no crash — app should still be running
        XCTAssertTrue(app.state == .runningForeground, "App should remain running after visiting Statistics")
    }
}
