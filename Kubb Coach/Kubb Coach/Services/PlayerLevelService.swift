//
//  PlayerLevelService.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/28/26.
//

import Foundation
import SwiftData

struct PlayerLevel {
    let levelNumber: Int
    let name: String
    let subtitle: String
    let currentXP: Int
    let xpForCurrentLevel: Int
    let xpForNextLevel: Int
    let totalSessions: Int

    var xpProgress: Double {
        let range = xpForNextLevel - xpForCurrentLevel
        guard range > 0 else { return 1.0 }
        let progress = Double(currentXP - xpForCurrentLevel) / Double(range)
        return min(max(progress, 0.0), 1.0)
    }

    var isMaxLevel: Bool {
        levelNumber >= PlayerLevelService.levelThresholds.last?.level ?? 51
    }
}

struct PlayerLevelService {

    struct LevelThreshold {
        let level: Int
        let name: String
        let subtitle: String
        let xpRequired: Int
    }

    static let levelThresholds: [LevelThreshold] = {
        var thresholds: [LevelThreshold] = []

        for level in 1...60 {
            let (name, subtitle): (String, String)
            switch level {
            case 1...5:
                name = "Nybörjare"
                subtitle = "Beginner"
            case 6...15:
                name = "Spelare"
                subtitle = "Player"
            case 16...30:
                name = "Kastare"
                subtitle = "Thrower"
            case 31...50:
                name = "Viking"
                subtitle = "Viking"
            default:
                name = "Kung"
                subtitle = "King"
            }

            let xp: Int
            switch level {
            case 1: xp = 0
            case 2...5: xp = (level - 1) * 50
            case 6...15: xp = 200 + (level - 5) * 100
            case 16...30: xp = 1200 + (level - 15) * 200
            case 31...50: xp = 4200 + (level - 30) * 350
            default: xp = 11200 + (level - 50) * 500
            }

            thresholds.append(LevelThreshold(level: level, name: name, subtitle: subtitle, xpRequired: xp))
        }

        return thresholds
    }()

    static func computeXP(totalThrows: Int, totalHits: Int) -> Int {
        return totalThrows + (totalHits * 2)
    }

    static func levelFor(xp: Int) -> LevelThreshold {
        var result = levelThresholds[0]
        for threshold in levelThresholds {
            if xp >= threshold.xpRequired {
                result = threshold
            } else {
                break
            }
        }
        return result
    }

    static func nextLevelXP(after level: Int) -> Int {
        if let next = levelThresholds.first(where: { $0.level == level + 1 }) {
            return next.xpRequired
        }
        return levelThresholds.last?.xpRequired ?? 0
    }

    static func computeLevel(from sessions: [TrainingSession]) -> PlayerLevel {
        let completedSessions = sessions.filter { $0.isComplete }

        var totalThrows = 0
        var totalHits = 0

        for session in completedSessions {
            totalThrows += session.totalThrows
            totalHits += session.totalHits
        }

        let xp = computeXP(totalThrows: totalThrows, totalHits: totalHits)
        let currentLevel = levelFor(xp: xp)
        let nextXP = nextLevelXP(after: currentLevel.level)

        return PlayerLevel(
            levelNumber: currentLevel.level,
            name: currentLevel.name,
            subtitle: currentLevel.subtitle,
            currentXP: xp,
            xpForCurrentLevel: currentLevel.xpRequired,
            xpForNextLevel: nextXP,
            totalSessions: completedSessions.count
        )
    }

    static func computeLevel(from sessions: [SessionDisplayItem]) -> PlayerLevel {
        var totalThrows = 0
        var totalHits = 0
        var completedCount = 0

        for session in sessions {
            if session.completedAt != nil {
                totalThrows += session.totalThrows
                totalHits += session.totalHits
                completedCount += 1
            }
        }

        let xp = computeXP(totalThrows: totalThrows, totalHits: totalHits)
        let currentLevel = levelFor(xp: xp)
        let nextXP = nextLevelXP(after: currentLevel.level)

        return PlayerLevel(
            levelNumber: currentLevel.level,
            name: currentLevel.name,
            subtitle: currentLevel.subtitle,
            currentXP: xp,
            xpForCurrentLevel: currentLevel.xpRequired,
            xpForNextLevel: nextXP,
            totalSessions: completedCount
        )
    }

    static func computeLevel(using modelContext: ModelContext) -> PlayerLevel {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return computeLevel(from: sessions)
    }
}
