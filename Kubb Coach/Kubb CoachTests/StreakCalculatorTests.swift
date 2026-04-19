//
//  StreakCalculatorTests.swift
//  Kubb CoachTests
//
//  Created by Claude Code on 3/15/26.
//

import Testing
import Foundation
@testable import Kubb_Coach

/// Tests for StreakCalculator - Daily streak calculation logic
@Suite("StreakCalculator Tests")
struct StreakCalculatorTests {

    // MARK: - Current Streak Tests

    @Test("Current streak with today's session")
    func testCurrentStreakWithTodaySession() {
        let today = Date()
        let sessions = createMockSessions(dates: [today])

        let streak = StreakCalculator.currentStreak(from: sessions)

        #expect(streak == 1)
    }

    @Test("Current streak with yesterday's session")
    func testCurrentStreakWithYesterdaySession() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let sessions = createMockSessions(dates: [yesterday])

        let streak = StreakCalculator.currentStreak(from: sessions)

        #expect(streak == 1)
    }

    @Test("Current streak broken (2 days ago)")
    func testCurrentStreakBroken() {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        let sessions = createMockSessions(dates: [twoDaysAgo])

        let streak = StreakCalculator.currentStreak(from: sessions)

        #expect(streak == 0, "Streak should be broken if last session was 2+ days ago")
    }

    @Test("Current streak with consecutive days")
    func testCurrentStreakConsecutiveDays() {
        let calendar = Calendar.current
        let today = Date()
        let dates = (0...6).map { calendar.date(byAdding: .day, value: -$0, to: today)! }
        let sessions = createMockSessions(dates: dates)

        let streak = StreakCalculator.currentStreak(from: sessions)

        #expect(streak == 7, "7 consecutive days should give streak of 7")
    }

    @Test("Current streak with gap in middle")
    func testCurrentStreakWithGap() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today)!

        let sessions = createMockSessions(dates: [today, yesterday, fiveDaysAgo])

        let streak = StreakCalculator.currentStreak(from: sessions)

        #expect(streak == 2, "Only count consecutive days from today")
    }

    @Test("Current streak with multiple sessions same day")
    func testCurrentStreakMultipleSessionsSameDay() {
        let today = Date()
        let sessions = createMockSessions(dates: [today, today, today])

        let streak = StreakCalculator.currentStreak(from: sessions)

        #expect(streak == 1, "Multiple sessions on same day count as one day")
    }

    @Test("Current streak with empty session list")
    func testCurrentStreakEmpty() {
        let sessions: [SessionDisplayItem] = []

        let streak = StreakCalculator.currentStreak(from: sessions)

        #expect(streak == 0)
    }

    // MARK: - Longest Streak Tests

    @Test("Longest streak with single session")
    func testLongestStreakSingleSession() {
        let today = Date()
        let sessions = createMockSessions(dates: [today])

        let streak = StreakCalculator.longestStreak(from: sessions)

        #expect(streak == 1)
    }

    @Test("Longest streak with consecutive days")
    func testLongestStreakConsecutive() {
        let calendar = Calendar.current
        let baseDate = Date()
        let dates = (0..<10).map { calendar.date(byAdding: .day, value: -$0, to: baseDate)! }
        let sessions = createMockSessions(dates: dates)

        let streak = StreakCalculator.longestStreak(from: sessions)

        #expect(streak == 10)
    }

    @Test("Longest streak with gap")
    func testLongestStreakWithGap() {
        let calendar = Calendar.current
        let baseDate = Date()

        // 5 consecutive days, then gap, then 3 consecutive days
        var dates: [Date] = []
        dates += (0..<5).map { calendar.date(byAdding: .day, value: -$0, to: baseDate)! }
        let gapEnd = calendar.date(byAdding: .day, value: -7, to: baseDate)!
        dates += (0..<3).map { calendar.date(byAdding: .day, value: -$0, to: gapEnd)! }

        let sessions = createMockSessions(dates: dates)

        let streak = StreakCalculator.longestStreak(from: sessions)

        #expect(streak == 5, "Should return longest consecutive streak")
    }

    @Test("Longest streak with multiple gaps")
    func testLongestStreakMultipleGaps() {
        let calendar = Calendar.current
        let baseDate = Date()

        // 3 days, gap, 7 days (longest), gap, 2 days
        var dates: [Date] = []

        // First streak: 3 days
        dates += (0..<3).map { calendar.date(byAdding: .day, value: -$0, to: baseDate)! }

        // Longest streak: 7 days (starting 5 days ago)
        let secondStart = calendar.date(byAdding: .day, value: -5, to: baseDate)!
        dates += (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: secondStart)! }

        // Last streak: 2 days (starting 15 days ago)
        let thirdStart = calendar.date(byAdding: .day, value: -15, to: baseDate)!
        dates += (0..<2).map { calendar.date(byAdding: .day, value: -$0, to: thirdStart)! }

        let sessions = createMockSessions(dates: dates)

        let streak = StreakCalculator.longestStreak(from: sessions)

        #expect(streak == 7, "Should find the longest streak among all streaks")
    }

    @Test("Longest streak with empty session list")
    func testLongestStreakEmpty() {
        let sessions: [SessionDisplayItem] = []

        let streak = StreakCalculator.longestStreak(from: sessions)

        #expect(streak == 0)
    }

    // MARK: - Freeze Earning Tests

    @Test("Should earn freeze at 10 day streak")
    func testShouldEarnFreezeAt10() {
        #expect(StreakCalculator.shouldEarnFreeze(currentStreak: 10) == true)
    }

    @Test("Should earn freeze at 20 day streak")
    func testShouldEarnFreezeAt20() {
        #expect(StreakCalculator.shouldEarnFreeze(currentStreak: 20) == true)
    }

    @Test("Should earn freeze at 30 day streak")
    func testShouldEarnFreezeAt30() {
        #expect(StreakCalculator.shouldEarnFreeze(currentStreak: 30) == true)
    }

    @Test("Should not earn freeze at non-multiple of 10")
    func testShouldNotEarnFreezeNonMultiple() {
        #expect(StreakCalculator.shouldEarnFreeze(currentStreak: 9) == false)
        #expect(StreakCalculator.shouldEarnFreeze(currentStreak: 11) == false)
        #expect(StreakCalculator.shouldEarnFreeze(currentStreak: 15) == false)
        #expect(StreakCalculator.shouldEarnFreeze(currentStreak: 25) == false)
    }

    @Test("Should not earn freeze at 0 streak")
    func testShouldNotEarnFreezeAtZero() {
        #expect(StreakCalculator.shouldEarnFreeze(currentStreak: 0) == false)
    }

    // MARK: - Freeze Consumption Tests

    @Test("Should consume freeze when yesterday missed but 2 days ago had session")
    func testShouldConsumeFreezeYesterdayMissed() {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        let sessions = createMockSessions(dates: [twoDaysAgo])

        let shouldConsume = StreakCalculator.shouldConsumeFreeze(sessions: sessions)

        #expect(shouldConsume == true, "Should consume freeze to save streak")
    }

    @Test("Should not consume freeze if today has session")
    func testShouldNotConsumeFreezeIfTodayHasSession() {
        let calendar = Calendar.current
        let today = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        let sessions = createMockSessions(dates: [today, twoDaysAgo])

        let shouldConsume = StreakCalculator.shouldConsumeFreeze(sessions: sessions)

        #expect(shouldConsume == false, "No freeze needed if trained today")
    }

    @Test("Should not consume freeze if yesterday has session")
    func testShouldNotConsumeFreezeIfYesterdayHasSession() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        let sessions = createMockSessions(dates: [yesterday, twoDaysAgo])

        let shouldConsume = StreakCalculator.shouldConsumeFreeze(sessions: sessions)

        #expect(shouldConsume == false, "No freeze needed if trained yesterday")
    }

    @Test("Should not consume freeze if streak already broken (3+ days)")
    func testShouldNotConsumeFreezeIfStreakBroken() {
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let sessions = createMockSessions(dates: [threeDaysAgo])

        let shouldConsume = StreakCalculator.shouldConsumeFreeze(sessions: sessions)

        #expect(shouldConsume == false, "Can't save a streak that's already broken")
    }

    @Test("Should not consume freeze with empty sessions")
    func testShouldNotConsumeFreezeEmpty() {
        let sessions: [SessionDisplayItem] = []

        let shouldConsume = StreakCalculator.shouldConsumeFreeze(sessions: sessions)

        #expect(shouldConsume == false)
    }

    // MARK: - Edge Cases

    @Test("Streak calculation handles timezone correctly")
    func testStreakHandlesTimezone() {
        let calendar = Calendar.current
        let today = Date()

        // Create session at 11:59 PM yesterday and 12:01 AM today
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lateYesterday = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: yesterday)!
        let earlyToday = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: today)!

        let sessions = createMockSessions(dates: [lateYesterday, earlyToday])

        let streak = StreakCalculator.currentStreak(from: sessions)

        #expect(streak == 2, "Sessions on different calendar days should count separately")
    }

    @Test("Longest streak handles unordered dates")
    func testLongestStreakUnorderedDates() {
        let calendar = Calendar.current
        let baseDate = Date()

        // Create dates in random order
        let dates = [
            calendar.date(byAdding: .day, value: -2, to: baseDate)!,
            calendar.date(byAdding: .day, value: 0, to: baseDate)!,
            calendar.date(byAdding: .day, value: -1, to: baseDate)!,
        ]

        let sessions = createMockSessions(dates: dates)

        let streak = StreakCalculator.longestStreak(from: sessions)

        #expect(streak == 3, "Should handle unordered dates correctly")
    }

    // MARK: - Merged Session Streak Tests (Game + PC + Training)

    @Test("Competitive game on today counts toward streak")
    func testCompetitiveGameCountsTowardStreak() {
        let game = GameSession(mode: .competitive)
        game.createdAt = Date()
        game.completedAt = Date()

        let streak = StreakCalculator.currentStreak(from: [], gameSessions: [game], pcSessions: [])

        #expect(streak == 1, "A completed competitive game should count as a training day")
    }

    @Test("Phantom game on yesterday counts toward streak")
    func testPhantomGameCountsTowardStreak() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        let game = GameSession(mode: .phantom)
        game.createdAt = yesterday
        game.completedAt = yesterday

        let streak = StreakCalculator.currentStreak(from: [], gameSessions: [game], pcSessions: [])

        #expect(streak == 1, "A completed phantom game should count as a training day")
    }

    @Test("Abandoned game does not count toward streak")
    func testAbandonedGameDoesNotCountTowardStreak() {
        let game = GameSession(mode: .competitive)
        game.createdAt = Date()
        game.completedAt = Date()
        game.endReason = GameEndReason.abandoned.rawValue

        let streak = StreakCalculator.currentStreak(from: [], gameSessions: [game], pcSessions: [])

        #expect(streak == 0, "An abandoned game should not count as a training day")
    }

    @Test("Incomplete game (no completedAt) does not count toward streak")
    func testIncompleteGameDoesNotCountTowardStreak() {
        let game = GameSession(mode: .competitive)
        game.createdAt = Date()
        // completedAt remains nil

        let streak = StreakCalculator.currentStreak(from: [], gameSessions: [game], pcSessions: [])

        #expect(streak == 0, "An incomplete game should not count as a training day")
    }

    @Test("Pressure Cooker session counts toward streak")
    func testPressureCookerSessionCountsTowardStreak() {
        let pcSession = PressureCookerSession(gameType: .threeForThree)
        pcSession.createdAt = Date()
        pcSession.completedAt = Date()

        let streak = StreakCalculator.currentStreak(from: [], gameSessions: [], pcSessions: [pcSession])

        #expect(streak == 1, "A completed PC session should count as a training day")
    }

    @Test("Game on yesterday extends streak from training 2 days ago")
    func testGameOnYesterdayExtendsStreak() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!

        let game = GameSession(mode: .competitive)
        game.createdAt = yesterday
        game.completedAt = yesterday

        let trainingSessions = createMockSessions(dates: [twoDaysAgo])

        let streak = StreakCalculator.currentStreak(from: trainingSessions, gameSessions: [game], pcSessions: [])

        #expect(streak == 2, "Game yesterday + training 2 days ago = streak of 2")
    }

    @Test("Mixed sources across consecutive days extend streak")
    func testMixedSourcesExtendStreak() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        // Today: training session
        let trainingSessions = createMockSessions(dates: [today, threeDaysAgo])

        // Yesterday: game
        let game = GameSession(mode: .competitive)
        game.createdAt = yesterday
        game.completedAt = yesterday

        // 2 days ago: PC session
        let pcSession = PressureCookerSession(gameType: .threeForThree)
        pcSession.createdAt = twoDaysAgo
        pcSession.completedAt = twoDaysAgo

        let streak = StreakCalculator.currentStreak(from: trainingSessions, gameSessions: [game], pcSessions: [pcSession])

        #expect(streak == 4, "4 consecutive days across training, game, and PC should give streak of 4")
    }

    @Test("Longest streak includes game sessions")
    func testLongestStreakIncludesGameSessions() {
        let calendar = Calendar.current
        let baseDate = Date()

        let trainingSessions = createMockSessions(dates: [
            calendar.date(byAdding: .day, value: -10, to: baseDate)!,
            calendar.date(byAdding: .day, value: -11, to: baseDate)!,
            calendar.date(byAdding: .day, value: -12, to: baseDate)!,
        ])

        // 5-day run ending today using mixed sources
        let today = baseDate
        let yesterday = calendar.date(byAdding: .day, value: -1, to: baseDate)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: baseDate)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: baseDate)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: baseDate)!

        let recentTraining = createMockSessions(dates: [today, threeDaysAgo, fourDaysAgo])
        let allTraining = trainingSessions + recentTraining

        let game = GameSession(mode: .phantom)
        game.createdAt = yesterday
        game.completedAt = yesterday

        let pcSession = PressureCookerSession(gameType: .threeForThree)
        pcSession.createdAt = twoDaysAgo
        pcSession.completedAt = twoDaysAgo

        let longest = StreakCalculator.longestStreak(from: allTraining, gameSessions: [game], pcSessions: [pcSession])

        #expect(longest == 5, "5-day run using mixed sources should be the longest streak")
    }

    // MARK: - Helper Functions

    private func createMockSessions(dates: [Date]) -> [SessionDisplayItem] {
        return dates.map { date in
            let session = TrainingSession(
                mode: .eightMeter,
                phase: .eightMeters,
                sessionType: .standard,
                configuredRounds: 1,
                startingBaseline: .north
            )
            session.createdAt = date
            session.completedAt = date
            return SessionDisplayItem.local(session)
        }
    }
}
