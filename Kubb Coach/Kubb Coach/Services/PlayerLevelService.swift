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

    // MARK: - XP Constants

    /// XP earned per throw in 8 Meters mode
    private static let xpPerThrow: Double = 0.3

    /// XP earned per hit in 8 Meters mode
    private static let xpPerHit: Double = 0.3

    /// Base XP earned per round in 4 Meters Blasting mode
    private static let xpPerBlastingRound: Double = 0.9

    // MARK: - Pressure Cooker XP Constants (3-4-3)
    // Tiers based on total 10-round score (max 130).
    // Calibrated to be comparable with other session types (~6–13 XP).

    /// XP awarded for a low-scoring 3-4-3 game (total score < 50)
    private static let xpPC343Low: Double = 5.0

    /// XP awarded for a mid-range 3-4-3 game (total score 50–75)
    private static let xpPC343Medium: Double = 9.0

    /// XP awarded for a high-scoring 3-4-3 game (total score > 75)
    private static let xpPC343High: Double = 13.0

    // MARK: - Pressure Cooker XP Constants (In the Red)
    // 1 XP per round + 0.5 bonus per king (+1) round.
    // 5-round range: 5.0–7.5 XP  |  10-round range: 10.0–15.0 XP

    static let xpITRPerRound: Double    = 1.0
    static let xpITRKingBonus: Double   = 0.5

    /// Bonus XP earned for each under-par round in Blasting mode
    private static let xpPerUnderParBonus: Double = 0.9

    /// Base XP earned per kubb in Inkasting mode
    private static let xpPerInkastingKubb: Double = 0.3

    /// Multiplier applied to Inkasting XP when achieving zero outliers (perfect round)
    private static let inkastingPerfectMultiplier: Double = 2.0

    // MARK: - Game Tracker XP Constants

    /// Base XP for completing any non-abandoned game (~8 Meters 10-round equivalent: ~12-15 XP)
    private static let xpGameBase: Double = 8.0

    /// Maximum bonus XP for performance (ratio of positive turns × this value)
    private static let xpGameMaxPerformanceBonus: Double = 4.0

    /// Bonus XP for winning a competitive game
    private static let xpGameWinBonus: Double = 2.0

    /// Bonus XP for any turn where the king was thrown
    private static let xpGameKingBonus: Double = 1.5

    // MARK: - Shared XP Formula Methods

    /// Shared formula for 8 Meters (Standard) mode XP calculation
    /// Rewards both volume (throws) and accuracy (hits) equally
    /// Average session example: ~20 throws + ~12 hits = 6.0 + 3.6 = 9.6 XP
    private static func calculateEightMetersXP(totalThrows: Int, totalHits: Int) -> Double {
        let throwXP = Double(totalThrows) * xpPerThrow
        let hitXP = Double(totalHits) * xpPerHit
        return throwXP + hitXP
    }

    /// Shared formula for 4 Meters Blasting mode XP calculation
    /// Rewards completion (rounds played) and excellence (under-par performance)
    /// Average session example: 5 rounds + 2 under-par = 4.5 + 1.8 = 6.3 XP
    private static func calculateBlastingXP(roundCount: Int, underParRoundCount: Int) -> Double {
        let baseXP = Double(roundCount) * xpPerBlastingRound
        let bonusXP = Double(underParRoundCount) * xpPerUnderParBonus
        return baseXP + bonusXP
    }

    // MARK: - Mode-Specific XP Calculation

    /// Calculate XP for 8 Meters (Standard) mode - local session
    /// Formula: 0.3 XP per throw + 0.3 XP per hit
    /// Rationale: Rewards both volume (throws) and accuracy (hits) equally
    private static func computeXP_EightMeters(_ session: TrainingSession) -> Double {
        return calculateEightMetersXP(totalThrows: session.totalThrows, totalHits: session.totalHits)
    }

    /// Calculate XP for 4 Meters Blasting mode - local session
    /// Formula: 0.9 XP per round + 0.9 XP bonus per under-par round
    /// Rationale: Rewards completion and excellence (golf scoring)
    private static func computeXP_Blasting(_ session: TrainingSession) -> Double {
        let rounds = session.rounds
        let underParRounds = rounds.filter { $0.score < 0 }.count
        return calculateBlastingXP(roundCount: rounds.count, underParRoundCount: underParRounds)
    }

    /// Calculate XP for Inkasting (Drilling) mode - local session only
    /// Formula: 0.3 XP per kubb, doubled if zero outliers (perfect accuracy)
    /// Rationale: Rewards precision training, with bonus for perfect execution
    /// Average session example: 12 kubbs × 0.3 = 3.6 XP (perfect: 7.2 XP)
    private static func computeXP_Inkasting(_ session: TrainingSession, context: ModelContext?) -> Double {
        var xp = 0.0

        #if os(iOS)
        // Fetch analyses for this session instead of accessing round.inkastingAnalysis
        // (relationship is one-way only due to SwiftData limitation)
        guard let context = context else { return 0.0 }

        let analyses = session.fetchInkastingAnalyses(context: context)

        for analysis in analyses {
            let kubbCount = Double(analysis.totalKubbCount)

            if analysis.outlierCount == 0 {
                // Double XP for perfect rounds (zero outliers)
                xp += kubbCount * xpPerInkastingKubb * inkastingPerfectMultiplier
            } else {
                // Normal XP
                xp += kubbCount * xpPerInkastingKubb
            }
        }
        #endif

        return xp
    }

    /// Calculate total XP from a TrainingSession based on its mode
    private static func computeXP(from session: TrainingSession, context: ModelContext? = nil) -> Double {
        guard session.completedAt != nil else { return 0.0 }

        // Tutorial sessions do not grant XP
        if session.isTutorialSession {
            return 0.0
        }

        switch session.phase {
        case .eightMeters:
            return computeXP_EightMeters(session)
        case .fourMetersBlasting:
            return computeXP_Blasting(session)
        case .inkastingDrilling:
            return computeXP_Inkasting(session, context: context)
        case .gameTracker, .pressureCooker, .none:
            return 0.0
        }
    }

    // MARK: - Cloud Session XP Calculation

    /// Calculate XP for 8 Meters (Standard) cloud session (from Apple Watch)
    /// Uses same formula as local sessions via shared calculation method
    private static func computeXP_EightMeters_Cloud(_ session: CloudSession) -> Double {
        return calculateEightMetersXP(totalThrows: session.totalThrows, totalHits: session.totalHits)
    }

    /// Calculate XP for 4 Meters Blasting cloud session (from Apple Watch)
    /// Uses same formula as local sessions via shared calculation method
    private static func computeXP_Blasting_Cloud(_ session: CloudSession) -> Double {
        let rounds = session.rounds
        let underParRounds = rounds.filter { $0.score < 0 }.count
        return calculateBlastingXP(roundCount: rounds.count, underParRoundCount: underParRounds)
    }

    // MARK: - Game Tracker XP Calculation

    /// Calculate XP for a completed Game Tracker session.
    ///
    /// Formula:
    ///   xp = baseXP + performanceXP + winBonus + kingBonus
    ///   baseXP        = 8.0  (any completed, non-abandoned game)
    ///   performanceXP = (positiveTurns / totalUserTurns) × 4.0  (max bonus)
    ///   winBonus      = 2.0  (competitive mode only, if user won)
    ///   kingBonus     = 1.5  (if the king was thrown in any user turn)
    ///
    /// Typical competitive win with king, 70% positive turns ≈ 14.3 XP
    /// Typical phantom game, 65% positive, king ≈ 12.1 XP
    static func computeXP(for session: GameSession) -> Double {
        guard session.isComplete, session.endReason != GameEndReason.abandoned.rawValue else {
            return 0.0
        }

        let userTurns = session.userTurns
        guard !userTurns.isEmpty else { return 0.0 }

        let positiveTurns = userTurns.filter { $0.progress > 0 }
        let performanceRatio = Double(positiveTurns.count) / Double(userTurns.count)
        let performanceXP = performanceRatio * xpGameMaxPerformanceBonus

        let kingBonus = userTurns.contains { $0.kingThrown && !$0.wasEarlyKing } ? xpGameKingBonus : 0.0
        let winBonus = (session.gameMode == .competitive && session.userWon == true) ? xpGameWinBonus : 0.0

        return xpGameBase + performanceXP + kingBonus + winBonus
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
        case .inkastingDrilling, .gameTracker, .pressureCooker:
            return 0.0  // Not available on watch
        }
    }

    /// Find the level threshold for a given XP amount using binary search
    /// Complexity: O(log n) instead of O(n) for 60 levels
    static func levelFor(xp: Int) -> LevelThreshold {
        // Binary search for the highest level where xpRequired <= xp
        var left = 0
        var right = levelThresholds.count - 1
        var result = levelThresholds[0]

        while left <= right {
            let mid = (left + right) / 2
            let threshold = levelThresholds[mid]

            if threshold.xpRequired <= xp {
                // This level is achievable, but there might be a higher one
                result = threshold
                left = mid + 1
            } else {
                // XP is too low for this level, search lower
                right = mid - 1
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

    // MARK: - Level Computation

    /// Internal unified method for creating PlayerLevel from XP and session count
    /// Eliminates duplication between the various computeLevel overloads
    private static func createPlayerLevel(xp: Int, sessionCount: Int, prestige: PlayerPrestige?) -> PlayerLevel {
        let currentLevel = levelFor(xp: xp)
        let nextXP = nextLevelXP(after: currentLevel.level)

        return PlayerLevel(
            levelNumber: currentLevel.level,
            name: currentLevel.name,
            subtitle: currentLevel.subtitle,
            currentXP: xp,
            xpForCurrentLevel: currentLevel.xpRequired,
            xpForNextLevel: nextXP,
            totalSessions: sessionCount,
            prestigeTitle: prestige?.fullTitle,
            prestigeLevel: prestige?.totalPrestiges ?? 0
        )
    }

    /// Compute player level from local TrainingSession array
    static func computeLevel(from sessions: [TrainingSession], context: ModelContext? = nil, prestige: PlayerPrestige? = nil) -> PlayerLevel {
        let completedSessions = sessions.filter { $0.isComplete }

        var totalXP = 0.0
        for session in completedSessions {
            totalXP += computeXP(from: session, context: context)
        }

        let xp = Int(totalXP.rounded())
        return createPlayerLevel(xp: xp, sessionCount: completedSessions.count, prestige: prestige)
    }

    /// Compute player level from mixed SessionDisplayItem array (local + cloud sessions)
    static func computeLevel(from sessions: [SessionDisplayItem], context: ModelContext? = nil, prestige: PlayerPrestige? = nil) -> PlayerLevel {
        var totalXP = 0.0
        var completedCount = 0

        for item in sessions {
            guard item.completedAt != nil else { continue }

            switch item {
            case .local(let session):
                totalXP += computeXP(from: session, context: context)
                completedCount += 1
            case .cloud(let cloudSession):
                totalXP += computeXP(from: cloudSession)
                completedCount += 1
            }
        }

        let xp = Int(totalXP.rounded())
        return createPlayerLevel(xp: xp, sessionCount: completedCount, prestige: prestige)
    }

    // MARK: - Pressure Cooker XP

    /// XP for a completed 3-4-3 game, tiered by total score.
    /// Returns 0 for incomplete sessions.
    static func computeXP(for pcSession: PressureCookerSession) -> Double {
        guard pcSession.isComplete else { return 0.0 }
        switch pcSession.gameType {
        case PressureCookerGameType.inTheRed.rawValue:
            return computeXPForITR(session: pcSession)
        default:
            let total = pcSession.totalScore
            switch total {
            case ..<50:   return xpPC343Low
            case 50...75: return xpPC343Medium
            default:      return xpPC343High
            }
        }
    }

    /// XP for a completed In the Red session: 1 pt per round + 0.5 bonus per king round.
    static func computeXPForITR(session: PressureCookerSession) -> Double {
        let rounds = Double(session.frameScores.count)
        let kings  = Double(session.frameScores.filter { $0 == 1 }.count)
        return rounds * xpITRPerRound + kings * xpITRKingBonus
    }

    static func computeLevel(using modelContext: ModelContext, prestige: PlayerPrestige? = nil) -> PlayerLevel {
        let trainingDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let sessions = (try? modelContext.fetch(trainingDescriptor)) ?? []

        // Also sum XP from completed, non-abandoned Game Tracker sessions
        let gameDescriptor = FetchDescriptor<GameSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let gameSessions = (try? modelContext.fetch(gameDescriptor)) ?? []
        let gameXP = gameSessions
            .filter { $0.endReason != GameEndReason.abandoned.rawValue }
            .reduce(0.0) { $0 + $1.xpEarned }

        var level = computeLevel(from: sessions, context: modelContext, prestige: prestige)

        // Blend in game XP: reconstruct with the additional XP total
        if gameXP > 0 {
            let combinedXP = level.currentXP + Int(gameXP.rounded())
            let combinedCount = level.totalSessions + gameSessions.filter {
                $0.endReason != GameEndReason.abandoned.rawValue
            }.count
            level = createPlayerLevel(xp: combinedXP, sessionCount: combinedCount, prestige: prestige)
        }

        // Blend in Pressure Cooker XP
        let pcDescriptor = FetchDescriptor<PressureCookerSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let pcSessions = (try? modelContext.fetch(pcDescriptor)) ?? []
        let pcXP = pcSessions.reduce(0.0) { $0 + $1.xpEarned }
        if pcXP > 0 {
            let combinedXP = level.currentXP + Int(pcXP.rounded())
            let combinedCount = level.totalSessions + pcSessions.count
            level = createPlayerLevel(xp: combinedXP, sessionCount: combinedCount, prestige: prestige)
        }

        return level
    }
}
