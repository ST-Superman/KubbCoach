//
//  StreakCalculator.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation

struct StreakCalculator {
    /// Calculates current training streak (today or yesterday counts as active)
    static func currentStreak(from sessions: [SessionDisplayItem]) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDays = uniqueDays.sorted(by: >)

        guard !sortedDays.isEmpty else { return 0 }

        // Check if today or yesterday has a session (streak is alive)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var currentDay: Date
        if sortedDays.contains(today) {
            currentDay = today
        } else if sortedDays.contains(yesterday) {
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
