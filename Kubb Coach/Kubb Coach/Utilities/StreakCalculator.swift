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

    /// Merges training session display items with completed game and Pressure Cooker sessions
    /// into a single list of dates used for streak calculations.
    /// Completed (non-abandoned) game sessions and completed PC sessions count as training activity.
    static func mergeDates(
        from sessions: [SessionDisplayItem],
        gameSessions: [GameSession],
        pcSessions: [PressureCookerSession] = []
    ) -> [Date] {
        let trainingDates = sessions.map { $0.createdAt }
        let completedGames = gameSessions.filter {
            $0.completedAt != nil && $0.endReason != GameEndReason.abandoned.rawValue
        }
        let gameDates = completedGames.map { $0.createdAt }
        let pcDates = pcSessions.filter { $0.completedAt != nil }.map { $0.createdAt }
        return trainingDates + gameDates + pcDates
    }

    /// Calculates current streak counting training, game, and Pressure Cooker sessions.
    static func currentStreak(
        from sessions: [SessionDisplayItem],
        gameSessions: [GameSession] = [],
        pcSessions: [PressureCookerSession] = []
    ) -> Int {
        let allDates = mergeDates(from: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        return currentStreak(fromDates: allDates)
    }

    /// Calculates longest streak counting training, game, and Pressure Cooker sessions.
    static func longestStreak(
        from sessions: [SessionDisplayItem],
        gameSessions: [GameSession] = [],
        pcSessions: [PressureCookerSession] = []
    ) -> Int {
        let allDates = mergeDates(from: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
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
    /// Returns true if yesterday was missed (no session today or yesterday, but had a session 2 days ago).
    /// Counts training, game, and Pressure Cooker sessions.
    static func shouldConsumeFreeze(
        sessions: [SessionDisplayItem],
        gameSessions: [GameSession] = [],
        pcSessions: [PressureCookerSession] = []
    ) -> Bool {
        let allDates = mergeDates(from: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        guard !allDates.isEmpty else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let uniqueDays = Set(allDates.map { calendar.startOfDay(for: $0) })

        // If there's a session today or yesterday, no need to consume freeze
        if uniqueDays.contains(today) || uniqueDays.contains(yesterday) {
            return false
        }

        // If there's a session 2 days ago, we should consume freeze to save the streak
        return uniqueDays.contains(twoDaysAgo)
    }

    /// Determines if a streak reminder notification should be scheduled.
    /// Returns true if user has no activity today and has an active streak (activity yesterday) to protect.
    /// Counts training, game, and Pressure Cooker sessions.
    static func shouldScheduleStreakReminder(
        sessions: [SessionDisplayItem],
        gameSessions: [GameSession] = [],
        pcSessions: [PressureCookerSession] = []
    ) -> Bool {
        let allDates = mergeDates(from: sessions, gameSessions: gameSessions, pcSessions: pcSessions)
        guard !allDates.isEmpty else { return false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let uniqueDays = Set(allDates.map { calendar.startOfDay(for: $0) })

        // If user already had activity today, no reminder needed
        if uniqueDays.contains(today) {
            return false
        }

        // Reminder fires only if yesterday had activity (streak to protect)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        return uniqueDays.contains(yesterday)
    }
}
