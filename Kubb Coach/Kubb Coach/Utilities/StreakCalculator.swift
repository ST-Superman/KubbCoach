//
//  StreakCalculator.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation
import SwiftData

struct StreakCalculator {

    // MARK: - Game Session Helpers

    /// Merges training session display items with completed game sessions into
    /// a single list of dates used for streak calculations.
    /// Completed (non-abandoned) game sessions count as training activity.
    static func mergeDates(
        from sessions: [SessionDisplayItem],
        gameSessions: [GameSession]
    ) -> [Date] {
        let trainingDates = sessions.map { $0.createdAt }
        let completedGames = gameSessions.filter {
            $0.completedAt != nil && $0.endReason != GameEndReason.abandoned.rawValue
        }
        let gameDates = completedGames.map { $0.createdAt }
        return trainingDates + gameDates
    }

    /// Calculates current streak counting both training sessions and game sessions.
    static func currentStreak(from sessions: [SessionDisplayItem], gameSessions: [GameSession]) -> Int {
        let allDates = mergeDates(from: sessions, gameSessions: gameSessions)
        return currentStreak(fromDates: allDates)
    }

    /// Calculates longest streak counting both training sessions and game sessions.
    static func longestStreak(from sessions: [SessionDisplayItem], gameSessions: [GameSession]) -> Int {
        let allDates = mergeDates(from: sessions, gameSessions: gameSessions)
        return longestStreak(fromDates: allDates)
    }

    // MARK: - Date-based streak primitives (shared internal logic)

    private static func currentStreak(fromDates dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }
        let calendar = Calendar.current
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !uniqueDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var currentDay: Date
        if uniqueDays.contains(today) {
            currentDay = today
        } else if uniqueDays.contains(yesterday) {
            currentDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        while uniqueDays.contains(currentDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = prev
        }
        return streak
    }

    private static func longestStreak(fromDates dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }
        let calendar = Calendar.current
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        let sortedDays = uniqueDays.sorted()
        guard let first = sortedDays.first else { return 0 }

        var maxStreak = 1
        var currentStreakCount = 1
        var previousDay = first

        for day in sortedDays.dropFirst() {
            if let next = calendar.date(byAdding: .day, value: 1, to: previousDay), day == next {
                currentStreakCount += 1
                maxStreak = max(maxStreak, currentStreakCount)
            } else {
                currentStreakCount = 1
            }
            previousDay = day
        }
        return maxStreak
    }

    // MARK: -

    /// Determines if the user should earn a freeze (every 10 days of streak)
    static func shouldEarnFreeze(currentStreak: Int) -> Bool {
        return currentStreak > 0 && currentStreak % 10 == 0
    }

    /// Determines if a freeze should be consumed to prevent streak loss
    /// Returns true if yesterday was missed (no session today or yesterday, but had a session 2 days ago)
    static func shouldConsumeFreeze(sessions: [SessionDisplayItem]) -> Bool {
        guard !sessions.isEmpty else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.createdAt) })

        // If there's a session today or yesterday, no need to consume freeze
        if uniqueDays.contains(today) || uniqueDays.contains(yesterday) {
            return false
        }

        // If there's a session 2 days ago, we should consume freeze to save the streak
        return uniqueDays.contains(twoDaysAgo)
    }

    /// Calculates current training streak (today or yesterday counts as active)
    static func currentStreak(from sessions: [SessionDisplayItem]) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.createdAt) })

        guard !uniqueDays.isEmpty else { return 0 }

        // Check if today or yesterday has a session (streak is alive)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var currentDay: Date
        if uniqueDays.contains(today) {
            currentDay = today
        } else if uniqueDays.contains(yesterday) {
            currentDay = yesterday
        } else {
            return 0 // Streak broken
        }

        // Count consecutive days backwards
        var streak = 0
        while uniqueDays.contains(currentDay) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            currentDay = previousDay
        }

        return streak
    }

    /// Calculates longest streak ever achieved
    static func longestStreak(from sessions: [SessionDisplayItem]) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDays = uniqueDays.sorted()

        guard let firstDay = sortedDays.first else { return 0 }

        var maxStreak = 1
        var currentStreakCount = 1
        var previousDay = firstDay

        for day in sortedDays.dropFirst() {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDay),
               day == nextDay {
                // Consecutive day
                currentStreakCount += 1
                maxStreak = max(maxStreak, currentStreakCount)
            } else {
                // Gap in streak
                currentStreakCount = 1
            }
            previousDay = day
        }

        return maxStreak
    }

    /// Determines if a streak reminder notification should be scheduled
    /// Returns true if user has not trained today and has an active streak to protect
    static func shouldScheduleStreakReminder(sessions: [SessionDisplayItem]) -> Bool {
        guard !sessions.isEmpty else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.createdAt) })

        // If user already trained today, no reminder needed
        if uniqueDays.contains(today) {
            return false
        }

        // Check if user has an active streak (trained yesterday)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let hasActiveStreak = uniqueDays.contains(yesterday)

        // Schedule reminder if there's an active streak to protect
        return hasActiveStreak
    }
}
