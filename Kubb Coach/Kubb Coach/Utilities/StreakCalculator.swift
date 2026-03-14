//
//  StreakCalculator.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation
import SwiftData

struct StreakCalculator {
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
}
