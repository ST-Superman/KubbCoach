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
    let prestigeTitle: String?
    let prestigeLevel: Int

    var xpProgress: Double {
        let range = xpForNextLevel - xpForCurrentLevel
        guard range > 0 else { return 1.0 }
        let progress = Double(currentXP - xpForCurrentLevel) / Double(range)
        return min(max(progress, 0.0), 1.0)
    }

    var isMaxLevel: Bool {
        levelNumber >= PlayerLevelService.levelThresholds.last?.level ?? 51
    }

    var displayName: String {
        let baseName = "\(name) (\(subtitle))"
        if let title = prestigeTitle {
            return "(\(title)) \(baseName)"
        }
        return baseName
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

    // MARK: - Mode-Specific XP Calculation

    /// Calculate XP for 8 Meters (Standard) mode
    /// Formula: 0.2 XP per throw + 0.2 XP per hit
    private static func computeXP_EightMeters(_ session: TrainingSession) -> Double {
        let throwXP = Double(session.totalThrows) * 0.2
        let hitXP = Double(session.totalHits) * 0.2
        return throwXP + hitXP
    }

    /// Calculate XP for 4 Meters Blasting mode
    /// Formula: 0.3 XP per round, +0.3 XP bonus if under par
    private static func computeXP_Blasting(_ session: TrainingSession) -> Double {
        var xp = 0.0
        let rounds = session.rounds

        xp += Double(rounds.count) * 0.3  // Base XP per round

        let underParRounds = rounds.filter { $0.score < 0 }.count
        xp += Double(underParRounds) * 0.3  // Bonus for under par

        return xp
    }

    /// Calculate XP for Inkasting (Drilling) mode
    /// Formula: 0.05 XP per kubb, doubled if zero outliers
    private static func computeXP_Inkasting(_ session: TrainingSession) -> Double {
        var xp = 0.0

        for round in session.rounds {
            #if os(iOS)
            guard let analysis = round.inkastingAnalysis else { continue }

            let baseXPPerKubb = 0.05
            let kubbCount = Double(analysis.totalKubbCount)

            if analysis.outlierCount == 0 {
                // Double XP for perfect rounds (zero outliers)
                xp += kubbCount * baseXPPerKubb * 2.0
            } else {
                // Normal XP
                xp += kubbCount * baseXPPerKubb
            }
            #endif
        }

        return xp
    }

    /// Calculate total XP from a TrainingSession based on its mode
    private static func computeXP(from session: TrainingSession) -> Double {
        guard session.completedAt != nil else { return 0.0 }

        switch session.phase {
        case .eightMeters:
            return computeXP_EightMeters(session)
        case .fourMetersBlasting:
            return computeXP_Blasting(session)
        case .inkastingDrilling:
            return computeXP_Inkasting(session)
        case .none:
            return 0.0
        }
    }

    // MARK: - Cloud Session XP Calculation

    /// Calculate XP for 8 Meters (Standard) cloud session
    private static func computeXP_EightMeters_Cloud(_ session: CloudSession) -> Double {
        let throwXP = Double(session.totalThrows) * 0.2
        let hitXP = Double(session.totalHits) * 0.2
        return throwXP + hitXP
    }

    /// Calculate XP for 4 Meters Blasting cloud session
    private static func computeXP_Blasting_Cloud(_ session: CloudSession) -> Double {
        var xp = 0.0
        let rounds = session.rounds

        xp += Double(rounds.count) * 0.3  // Base XP per round

        let underParRounds = rounds.filter { $0.score < 0 }.count
        xp += Double(underParRounds) * 0.3  // Bonus for under par

        return xp
    }

    /// Calculate total XP from a CloudSession based on its mode
    /// Note: Inkasting is not available on watch, so only 8m and Blasting are supported
    private static func computeXP(from cloudSession: CloudSession) -> Double {
        guard cloudSession.completedAt != nil else { return 0.0 }

        switch cloudSession.phase {
        case .eightMeters:
            return computeXP_EightMeters_Cloud(cloudSession)
        case .fourMetersBlasting:
            return computeXP_Blasting_Cloud(cloudSession)
        case .inkastingDrilling:
            return 0.0  // Inkasting not available on watch
        }
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

    static func computeLevel(from sessions: [TrainingSession], prestige: PlayerPrestige? = nil) -> PlayerLevel {
        let completedSessions = sessions.filter { $0.isComplete }

        var totalXP = 0.0

        for session in completedSessions {
            totalXP += computeXP(from: session)
        }

        let xp = Int(totalXP.rounded())
        let currentLevel = levelFor(xp: xp)
        let nextXP = nextLevelXP(after: currentLevel.level)

        return PlayerLevel(
            levelNumber: currentLevel.level,
            name: currentLevel.name,
            subtitle: currentLevel.subtitle,
            currentXP: xp,
            xpForCurrentLevel: currentLevel.xpRequired,
            xpForNextLevel: nextXP,
            totalSessions: completedSessions.count,
            prestigeTitle: prestige?.fullTitle,
            prestigeLevel: prestige?.totalPrestiges ?? 0
        )
    }

    static func computeLevel(from sessions: [SessionDisplayItem], prestige: PlayerPrestige? = nil) -> PlayerLevel {
        var totalXP = 0.0
        var completedCount = 0

        for item in sessions {
            guard item.completedAt != nil else { continue }

            switch item {
            case .local(let session):
                totalXP += computeXP(from: session)
                completedCount += 1
            case .cloud(let cloudSession):
                totalXP += computeXP(from: cloudSession)
                completedCount += 1
            }
        }

        let xp = Int(totalXP.rounded())
        let currentLevel = levelFor(xp: xp)
        let nextXP = nextLevelXP(after: currentLevel.level)

        return PlayerLevel(
            levelNumber: currentLevel.level,
            name: currentLevel.name,
            subtitle: currentLevel.subtitle,
            currentXP: xp,
            xpForCurrentLevel: currentLevel.xpRequired,
            xpForNextLevel: nextXP,
            totalSessions: completedCount,
            prestigeTitle: prestige?.fullTitle,
            prestigeLevel: prestige?.totalPrestiges ?? 0
        )
    }

    static func computeLevel(using modelContext: ModelContext, prestige: PlayerPrestige? = nil) -> PlayerLevel {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return computeLevel(from: sessions, prestige: prestige)
    }
}
