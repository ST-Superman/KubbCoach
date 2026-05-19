//
//  EmailReportService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/9/26.
//

import Foundation
import SwiftData
import MessageUI
import UIKit

/// Service for generating and sending email training reports
@MainActor
class EmailReportService {

    // MARK: - Report Generation

    /// Generates an HTML email report based on current training data
    static func generateReport(
        sessions: [SessionDisplayItem],
        gameSessions: [GameSession] = [],
        pressureCookerSessions: [PressureCookerSession] = [],
        playerLevel: PlayerLevel,
        streak: Int,
        competitionSettings: CompetitionSettings?,
        inkastingSettings: InkastingSettings,
        modelContext: ModelContext,
        frequency: ReportFrequency = .weekly,
        playerDisplayName: String? = nil
    ) -> EmailReport {
        let reportPeriod = periodLabel(for: frequency)

        // Split sessions into current period, previous period, and "all prior" (for PB detection).
        let now = Date()
        let buckets = splitSessions(sessions, frequency: frequency, now: now)
        let gameBuckets = bucket(gameSessions, by: \.createdAt, frequency: frequency, now: now)
        let pcBuckets = bucket(pressureCookerSessions, by: \.createdAt, frequency: frequency, now: now)
        let currentGameSummary = summarizeGames(gameBuckets.current)
        let previousGameSummary = summarizeGames(gameBuckets.previous)
        let currentPCSummary = summarizePressureCooker(pcBuckets.current)
        let previousPCSummary = summarizePressureCooker(pcBuckets.previous)
        let currentStats = calculateStatistics(from: buckets.current, games: currentGameSummary, pressureCooker: currentPCSummary, inkastingSettings: inkastingSettings, modelContext: modelContext)
        let previousStats = calculateStatistics(from: buckets.previous, games: previousGameSummary, pressureCooker: previousPCSummary, inkastingSettings: inkastingSettings, modelContext: modelContext)
        let priorStats = calculateStatistics(from: buckets.allPrior, games: .empty, pressureCooker: .empty, inkastingSettings: inkastingSettings, modelContext: modelContext)
        let deltas = computeDeltas(current: currentStats, previous: previousStats)
        let win = selectWin(
            stats: currentStats,
            deltas: deltas,
            priorStats: priorStats,
            streak: streak,
            inkastingSettings: inkastingSettings
        )

        let salutationName: String
        if let provided = playerDisplayName?.trimmingCharacters(in: .whitespaces),
           !provided.isEmpty {
            salutationName = provided.split(separator: " ").first.map(String.init) ?? provided
        } else {
            salutationName = "\(playerLevel.name) (\(playerLevel.subtitle))"
        }

        let htmlBody = buildHTMLReport(
            salutationName: salutationName,
            playerLevel: playerLevel,
            streak: streak,
            periodLabel: reportPeriod,
            stats: currentStats,
            previousStats: previousStats,
            deltas: deltas,
            win: win,
            inkastingSettings: inkastingSettings
        )

        return EmailReport(
            subject: "Your Kubb Training Report - \(reportPeriod)",
            htmlBody: htmlBody,
            generatedAt: Date()
        )
    }

    // MARK: - Period Splitting

    private struct SessionBuckets {
        let current: [SessionDisplayItem]
        let previous: [SessionDisplayItem]
        let allPrior: [SessionDisplayItem] // Everything older than the current period.
    }

    private static func splitSessions(
        _ sessions: [SessionDisplayItem],
        frequency: ReportFrequency,
        now: Date
    ) -> SessionBuckets {
        let interval = TimeInterval(frequency.dayInterval * 24 * 60 * 60)
        let currentStart = now.addingTimeInterval(-interval)
        let previousStart = currentStart.addingTimeInterval(-interval)

        var current: [SessionDisplayItem] = []
        var previous: [SessionDisplayItem] = []
        var allPrior: [SessionDisplayItem] = []

        for session in sessions {
            let date = session.createdAt
            if date >= currentStart {
                current.append(session)
            } else {
                allPrior.append(session)
                if date >= previousStart {
                    previous.append(session)
                }
            }
        }
        return SessionBuckets(current: current, previous: previous, allPrior: allPrior)
    }

    /// Bucket arbitrary items into current vs. previous period by their date.
    private static func bucket<T>(
        _ items: [T],
        by date: (T) -> Date,
        frequency: ReportFrequency,
        now: Date
    ) -> (current: [T], previous: [T]) {
        let interval = TimeInterval(frequency.dayInterval * 24 * 60 * 60)
        let currentStart = now.addingTimeInterval(-interval)
        let previousStart = currentStart.addingTimeInterval(-interval)
        var current: [T] = []
        var previous: [T] = []
        for item in items {
            let d = date(item)
            if d >= currentStart {
                current.append(item)
            } else if d >= previousStart {
                previous.append(item)
            }
        }
        return (current, previous)
    }

    private static func periodLabel(for frequency: ReportFrequency) -> String {
        switch frequency {
        case .weekly: return "This Week"
        case .biweekly: return "Last Two Weeks"
        case .monthly: return "This Month"
        }
    }

    private static func periodRangeLabel(for frequency: ReportFrequency, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let interval = TimeInterval(frequency.dayInterval * 24 * 60 * 60)
        let start = now.addingTimeInterval(-interval)
        return "\(formatter.string(from: start)) – \(formatter.string(from: now))"
    }

    // MARK: - Game / Pressure Cooker Summaries

    /// Aggregated metrics for one game-mode group within a period.
    struct GameSubtypeSummary {
        let count: Int
        let fieldEfficiency: Double?    // kubbs per baton
        let eightMeterHitRate: Double?  // 0–1
        let wins: Int                   // only meaningful for competitive
        let losses: Int                 // only meaningful for competitive

        static let empty = GameSubtypeSummary(count: 0, fieldEfficiency: nil, eightMeterHitRate: nil, wins: 0, losses: 0)
    }

    struct GameSummary {
        let phantom: GameSubtypeSummary
        let competitive: GameSubtypeSummary

        var totalCount: Int { phantom.count + competitive.count }
        static let empty = GameSummary(phantom: .empty, competitive: .empty)
    }

    /// Aggregated metrics for one Pressure Cooker game type within a period.
    struct PressureCookerSubtypeSummary {
        let count: Int
        let averageScore: Double?

        static let empty = PressureCookerSubtypeSummary(count: 0, averageScore: nil)
    }

    struct PressureCookerSummary {
        let threeFortyThree: PressureCookerSubtypeSummary
        let inTheRed: PressureCookerSubtypeSummary

        var totalCount: Int { threeFortyThree.count + inTheRed.count }
        static let empty = PressureCookerSummary(threeFortyThree: .empty, inTheRed: .empty)
    }

    private static func summarizeGames(_ sessions: [GameSession]) -> GameSummary {
        let phantoms = sessions.filter { $0.gameMode == .phantom }
        let comps = sessions.filter { $0.gameMode == .competitive }
        return GameSummary(
            phantom: aggregateGameSubtype(phantoms),
            competitive: aggregateGameSubtype(comps)
        )
    }

    private static func aggregateGameSubtype(_ sessions: [GameSession]) -> GameSubtypeSummary {
        guard !sessions.isEmpty else { return .empty }
        var totalFieldCleared = 0
        var totalBatonsOnField = 0
        var totalEightHits = 0
        var totalEightAttempts = 0
        var wins = 0
        var losses = 0
        for session in sessions {
            let analysis = GamePerformanceAnalyzer.analyze(session: session)
            totalFieldCleared += analysis.fieldKubbsCleared
            totalBatonsOnField += analysis.batonsUsedOnField
            totalEightHits += analysis.eightMeterHits
            totalEightAttempts += analysis.eightMeterAttempts
            // W/L only counts when there's a recorded winner and the user has a side (competitive).
            if session.gameMode == .competitive, let userWon = session.userWon {
                if userWon { wins += 1 } else { losses += 1 }
            }
        }
        let fieldEff: Double? = totalBatonsOnField > 0
            ? Double(totalFieldCleared) / Double(totalBatonsOnField)
            : nil
        let eightRate: Double? = totalEightAttempts > 0
            ? Double(totalEightHits) / Double(totalEightAttempts)
            : nil
        return GameSubtypeSummary(
            count: sessions.count,
            fieldEfficiency: fieldEff,
            eightMeterHitRate: eightRate,
            wins: wins,
            losses: losses
        )
    }

    private static func summarizePressureCooker(_ sessions: [PressureCookerSession]) -> PressureCookerSummary {
        let threeFortyThree = sessions.filter { $0.gameType == PressureCookerGameType.threeForThree.rawValue }
        let inTheRed = sessions.filter { $0.gameType == PressureCookerGameType.inTheRed.rawValue }
        return PressureCookerSummary(
            threeFortyThree: aggregatePressureCookerSubtype(threeFortyThree),
            inTheRed: aggregatePressureCookerSubtype(inTheRed)
        )
    }

    private static func aggregatePressureCookerSubtype(_ sessions: [PressureCookerSession]) -> PressureCookerSubtypeSummary {
        guard !sessions.isEmpty else { return .empty }
        let scores = sessions.map { Double($0.totalScore) }
        let avg = scores.reduce(0, +) / Double(scores.count)
        return PressureCookerSubtypeSummary(count: sessions.count, averageScore: avg)
    }

    // MARK: - Statistics Calculation

    private static func calculateStatistics(
        from sessions: [SessionDisplayItem],
        games: GameSummary = .empty,
        pressureCooker: PressureCookerSummary = .empty,
        inkastingSettings: InkastingSettings,
        modelContext: ModelContext
    ) -> ReportStatistics {
        let eightMeterSessions = sessions.filter { $0.phase == .eightMeters }
        let blastingSessions = sessions.filter { $0.phase == .fourMetersBlasting }
        let inkastingSessions = sessions.filter { $0.phase == .inkastingDrilling }

        let best8MAccuracy = eightMeterSessions.map { $0.accuracy }.max() ?? 0.0
        let avg8MAccuracy = eightMeterSessions.isEmpty ? 0.0 : eightMeterSessions.map { $0.accuracy }.reduce(0, +) / Double(eightMeterSessions.count)

        let blastingScores = blastingSessions.compactMap { $0.sessionScore }
        let bestBlastingScore = blastingScores.min() ?? 0
        let avgBlastingScore = blastingScores.isEmpty ? 0 : blastingScores.reduce(0, +) / blastingScores.count

        var bestInkastingArea: Double?
        var avgInkastingArea: Double?

        if !inkastingSessions.isEmpty {
            var totalArea = 0.0
            var analysisCount = 0
            var bestArea: Double?

            for session in inkastingSessions.prefix(20) {
                if let localSession = session.localSession {
                    let analyses = localSession.fetchInkastingAnalyses(context: modelContext)
                    for analysis in analyses {
                        let area = analysis.clusterAreaSquareMeters
                        totalArea += area
                        analysisCount += 1
                        if bestArea == nil || area < bestArea! {
                            bestArea = area
                        }
                    }
                }
            }

            if analysisCount > 0 {
                avgInkastingArea = totalArea / Double(analysisCount)
                bestInkastingArea = bestArea
            }
        }

        return ReportStatistics(
            totalSessions: sessions.count + games.totalCount + pressureCooker.totalCount,
            eightMeterCount: eightMeterSessions.count,
            blastingCount: blastingSessions.count,
            inkastingCount: inkastingSessions.count,
            games: games,
            pressureCooker: pressureCooker,
            best8MAccuracy: best8MAccuracy,
            avg8MAccuracy: avg8MAccuracy,
            bestBlastingScore: bestBlastingScore,
            avgBlastingScore: avgBlastingScore,
            bestInkastingArea: bestInkastingArea,
            avgInkastingArea: avgInkastingArea
        )
    }

    // MARK: - Deltas

    private static func computeDeltas(current: ReportStatistics, previous: ReportStatistics) -> ReportDeltas {
        let sessionsDelta: Int? = previous.totalSessions == 0 && current.totalSessions == 0
            ? nil
            : current.totalSessions - previous.totalSessions

        let eightDelta: Double? = (current.eightMeterCount > 0 && previous.eightMeterCount > 0)
            ? (current.avg8MAccuracy - previous.avg8MAccuracy)
            : nil

        let blastingDelta: Int? = (current.blastingCount > 0 && previous.blastingCount > 0)
            ? (current.avgBlastingScore - previous.avgBlastingScore)
            : nil

        let inkastingDelta: Double? = {
            guard let currentAvg = current.avgInkastingArea, let previousAvg = previous.avgInkastingArea else { return nil }
            return currentAvg - previousAvg
        }()

        let phantomField = optionalDelta(current.games.phantom.fieldEfficiency, previous.games.phantom.fieldEfficiency)
        let phantomEight = optionalDelta(current.games.phantom.eightMeterHitRate, previous.games.phantom.eightMeterHitRate)
        let competitiveField = optionalDelta(current.games.competitive.fieldEfficiency, previous.games.competitive.fieldEfficiency)
        let competitiveEight = optionalDelta(current.games.competitive.eightMeterHitRate, previous.games.competitive.eightMeterHitRate)
        let threeForThree = optionalDelta(current.pressureCooker.threeFortyThree.averageScore, previous.pressureCooker.threeFortyThree.averageScore)
        let inTheRed = optionalDelta(current.pressureCooker.inTheRed.averageScore, previous.pressureCooker.inTheRed.averageScore)

        return ReportDeltas(
            sessions: sessionsDelta,
            eightMAccuracy: eightDelta,
            blastingScore: blastingDelta,
            inkastingArea: inkastingDelta,
            phantomFieldEfficiency: phantomField,
            phantomEightMeterHitRate: phantomEight,
            competitiveFieldEfficiency: competitiveField,
            competitiveEightMeterHitRate: competitiveEight,
            threeFortyThreeAvgScore: threeForThree,
            inTheRedAvgScore: inTheRed
        )
    }

    private static func optionalDelta(_ current: Double?, _ previous: Double?) -> Double? {
        guard let current, let previous else { return nil }
        return current - previous
    }

    // MARK: - Win Selection

    private static func selectWin(
        stats: ReportStatistics,
        deltas: ReportDeltas,
        priorStats: ReportStatistics,
        streak: Int,
        inkastingSettings: InkastingSettings
    ) -> ReportWin? {
        guard stats.totalSessions > 0 else { return nil }

        // Tier 1: rank all improvement candidates across every session type by normalized magnitude.
        // Each candidate's magnitude = (improvement amount) / (qualification threshold for that metric).
        // Anything with magnitude ≥ 1.0 qualifies; we pick the strongest.
        var candidates: [(magnitude: Double, build: () -> ReportWin)] = []

        // 8m training accuracy (+pt, threshold +2.0)
        if let delta = deltas.eightMAccuracy, delta >= 2.0, stats.eightMeterCount > 0 {
            candidates.append((delta / 2.0, {
                ReportWin(
                    type: .eightMeterImproved,
                    headlineValue: String(format: "+%.1f", delta),
                    headlineUnit: "pt",
                    headlineSubtitleHTML: "Your 8-meter accuracy climbed this week. You averaged <strong style=\"color:#ffffff;font-weight:600;\">\(formatPercent(stats.avg8MAccuracy))</strong> across \(stats.eightMeterCount) \(pluralize("session", stats.eightMeterCount)) and peaked at <strong style=\"color:#ffffff;font-weight:600;\">\(formatPercent(stats.best8MAccuracy))</strong>.",
                    partingLine: "Keep the line tight. The 8-meter game is yours this week."
                )
            }))
        }

        // Blasting (-points, threshold ≤-2)
        if let delta = deltas.blastingScore, delta <= -2, stats.blastingCount > 0 {
            candidates.append((Double(-delta) / 2.0, {
                ReportWin(
                    type: .blastingImproved,
                    headlineValue: "\(formatSignedInt(delta))",
                    headlineUnit: "",
                    headlineSubtitleHTML: "Blasting found its target. Your average dropped to <strong style=\"color:#ffffff;font-weight:600;\">\(formatSignedInt(stats.avgBlastingScore))</strong> across \(stats.blastingCount) \(pluralize("session", stats.blastingCount)), with a best of <strong style=\"color:#ffffff;font-weight:600;\">\(formatSignedInt(stats.bestBlastingScore))</strong>.",
                    partingLine: "Decisive batons. Carry it into next week."
                )
            }))
        }

        // Inkasting (-m², threshold ≤-0.1)
        if let delta = deltas.inkastingArea, delta <= -0.1,
           let avg = stats.avgInkastingArea, let best = stats.bestInkastingArea {
            candidates.append((-delta / 0.1, {
                ReportWin(
                    type: .inkastingImproved,
                    headlineValue: String(format: "%@%.2f", delta < 0 ? "−" : "+", abs(delta)),
                    headlineUnit: "m²",
                    headlineSubtitleHTML: "The cluster tightened. Your average area was <strong style=\"color:#ffffff;font-weight:600;\">\(inkastingSettings.formatArea(avg))</strong> across \(stats.inkastingCount) \(pluralize("session", stats.inkastingCount)), with a best of <strong style=\"color:#ffffff;font-weight:600;\">\(inkastingSettings.formatArea(best))</strong>.",
                    partingLine: "That cluster is starting to talk back. Keep listening."
                )
            }))
        }

        // Phantom games — field efficiency (+k/b, threshold +0.3)
        if let delta = deltas.phantomFieldEfficiency, delta >= 0.3,
           let avg = stats.games.phantom.fieldEfficiency, stats.games.phantom.count > 0 {
            candidates.append((delta / 0.3, {
                ReportWin(
                    type: .phantomFieldImproved,
                    headlineValue: String(format: "+%.1f", delta),
                    headlineUnit: "k/b",
                    headlineSubtitleHTML: "Cleaner field clears in your phantom games. You averaged <strong style=\"color:#ffffff;font-weight:600;\">\(formatEfficiency(avg))</strong> across \(stats.games.phantom.count) \(pluralize("game", stats.games.phantom.count)).",
                    partingLine: "Sharper field work. Carry it forward."
                )
            }))
        }

        // Phantom games — 8m hit rate (+rate, threshold +0.05)
        if let delta = deltas.phantomEightMeterHitRate, delta >= 0.05,
           let rate = stats.games.phantom.eightMeterHitRate, stats.games.phantom.count > 0 {
            candidates.append((delta / 0.05, {
                ReportWin(
                    type: .phantomEightImproved,
                    headlineValue: String(format: "+%.0f", delta * 100),
                    headlineUnit: "pt",
                    headlineSubtitleHTML: "Your in-game 8-meter line sharpened. You hit <strong style=\"color:#ffffff;font-weight:600;\">\(formatPercent(rate * 100))</strong> across \(stats.games.phantom.count) phantom \(pluralize("game", stats.games.phantom.count)).",
                    partingLine: "Keep that line steady. Same rhythm next week."
                )
            }))
        }

        // Competitive — field efficiency
        if let delta = deltas.competitiveFieldEfficiency, delta >= 0.3,
           let avg = stats.games.competitive.fieldEfficiency, stats.games.competitive.count > 0 {
            candidates.append((delta / 0.3, {
                ReportWin(
                    type: .competitiveFieldImproved,
                    headlineValue: String(format: "+%.1f", delta),
                    headlineUnit: "k/b",
                    headlineSubtitleHTML: "Cleaner clears under pressure. <strong style=\"color:#ffffff;font-weight:600;\">\(formatEfficiency(avg))</strong> across \(stats.games.competitive.count) competitive \(pluralize("game", stats.games.competitive.count)).",
                    partingLine: "That's match-level work. Carry it into the next one."
                )
            }))
        }

        // Competitive — 8m hit rate
        if let delta = deltas.competitiveEightMeterHitRate, delta >= 0.05,
           let rate = stats.games.competitive.eightMeterHitRate, stats.games.competitive.count > 0 {
            candidates.append((delta / 0.05, {
                ReportWin(
                    type: .competitiveEightImproved,
                    headlineValue: String(format: "+%.0f", delta * 100),
                    headlineUnit: "pt",
                    headlineSubtitleHTML: "Your 8-meter line held up against opponents. <strong style=\"color:#ffffff;font-weight:600;\">\(formatPercent(rate * 100))</strong> across \(stats.games.competitive.count) competitive \(pluralize("game", stats.games.competitive.count)).",
                    partingLine: "That line lands when it counts. Keep it sharp."
                )
            }))
        }

        // Competitive sweep — 3+ wins with 0 losses (standalone achievement, no prior comparison needed).
        let comp = stats.games.competitive
        if comp.wins >= 3, comp.losses == 0 {
            // Magnitude scales with win count; a 3-0 sweep gets 1.5, 4-0 gets 2.0, etc.
            let magnitude = 1.0 + (Double(comp.wins - 3) * 0.5) + 0.5
            candidates.append((magnitude, {
                ReportWin(
                    type: .competitiveSweep,
                    headlineValue: "\(comp.wins)–\(comp.losses)",
                    headlineUnit: "",
                    headlineSubtitleHTML: "Untouched in competitive play this week. <strong style=\"color:#ffffff;font-weight:600;\">\(comp.wins) \(pluralize("win", comp.wins))</strong>, no losses.",
                    partingLine: "Don't get comfortable. The next opponent is already studying you."
                )
            }))
        }

        // 3-4-3 — avg score (+points, threshold +5)
        if let delta = deltas.threeFortyThreeAvgScore, delta >= 5,
           let avg = stats.pressureCooker.threeFortyThree.averageScore,
           stats.pressureCooker.threeFortyThree.count > 0 {
            candidates.append((delta / 5.0, {
                ReportWin(
                    type: .threeFortyThreeImproved,
                    headlineValue: String(format: "+%.0f", delta),
                    headlineUnit: "",
                    headlineSubtitleHTML: "Your 3-4-3 game climbed. Averaging <strong style=\"color:#ffffff;font-weight:600;\">\(formatRoundedScore(avg))</strong> across \(stats.pressureCooker.threeFortyThree.count) \(pluralize("game", stats.pressureCooker.threeFortyThree.count)).",
                    partingLine: "The frames are starting to talk back. Keep listening."
                )
            }))
        }

        // In the Red — avg score (+, threshold +0.5)
        if let delta = deltas.inTheRedAvgScore, delta >= 0.5,
           let avg = stats.pressureCooker.inTheRed.averageScore,
           stats.pressureCooker.inTheRed.count > 0 {
            candidates.append((delta / 0.5, {
                ReportWin(
                    type: .inTheRedImproved,
                    headlineValue: formatSignedDouble(delta),
                    headlineUnit: "",
                    headlineSubtitleHTML: "In the Red is lifting. Averaging <strong style=\"color:#ffffff;font-weight:600;\">\(formatSignedDouble(avg))</strong> across \(stats.pressureCooker.inTheRed.count) \(pluralize("session", stats.pressureCooker.inTheRed.count)).",
                    partingLine: "Pressure rewards repetition. Keep dialing it in."
                )
            }))
        }

        // Tier 1 verdict — strongest improvement across all session types.
        if let top = candidates.max(by: { $0.magnitude < $1.magnitude }) {
            return top.build()
        }

        // Tier 2: Personal best this period (vs all prior).
        if let pb = detectPersonalBest(stats: stats, priorStats: priorStats, inkastingSettings: inkastingSettings) {
            return pb
        }

        // Tier 3: Streak milestone (≥ 7 and divisible by 7)
        if streak >= 7, streak % 7 == 0 {
            return ReportWin(
                type: .streakMilestone,
                headlineValue: "\(streak)",
                headlineUnit: "days",
                headlineSubtitleHTML: "\(streak) days, unbroken. The habit is doing the work.",
                partingLine: "Don't break the chain."
            )
        }

        // Tier 4: Session count fallback
        return ReportWin(
            type: .sessionCount,
            headlineValue: "\(stats.totalSessions)",
            headlineUnit: stats.totalSessions == 1 ? "session" : "sessions",
            headlineSubtitleHTML: "\(stats.totalSessions) \(pluralize("session", stats.totalSessions)) this week. Showing up is half the battle.",
            partingLine: "Same time next week."
        )
    }

    private static func detectPersonalBest(
        stats: ReportStatistics,
        priorStats: ReportStatistics,
        inkastingSettings: InkastingSettings
    ) -> ReportWin? {
        // 8m PB: current best accuracy beats prior best (and current best > 0 means at least one session).
        if stats.eightMeterCount > 0, priorStats.eightMeterCount > 0,
           stats.best8MAccuracy > priorStats.best8MAccuracy {
            return ReportWin(
                type: .personalBest,
                headlineValue: formatPercent(stats.best8MAccuracy),
                headlineUnit: "",
                headlineSubtitleHTML: "New personal best. 8 Meter hit <strong style=\"color:#ffffff;font-weight:600;\">\(formatPercent(stats.best8MAccuracy))</strong> — your best mark on record.",
                partingLine: "Records don't break themselves. Well done."
            )
        }
        // Blasting PB: lower score is better.
        if stats.blastingCount > 0, priorStats.blastingCount > 0,
           stats.bestBlastingScore < priorStats.bestBlastingScore {
            return ReportWin(
                type: .personalBest,
                headlineValue: formatSignedInt(stats.bestBlastingScore),
                headlineUnit: "",
                headlineSubtitleHTML: "New personal best. Blasting hit <strong style=\"color:#ffffff;font-weight:600;\">\(formatSignedInt(stats.bestBlastingScore))</strong> — your best mark on record.",
                partingLine: "Records don't break themselves. Well done."
            )
        }
        // Inkasting PB: smaller area is better.
        if let currentBest = stats.bestInkastingArea, let priorBest = priorStats.bestInkastingArea,
           currentBest < priorBest {
            return ReportWin(
                type: .personalBest,
                headlineValue: String(format: "%.2f", currentBest),
                headlineUnit: "m²",
                headlineSubtitleHTML: "New personal best. Inkasting hit <strong style=\"color:#ffffff;font-weight:600;\">\(inkastingSettings.formatArea(currentBest))</strong> — your best mark on record.",
                partingLine: "That cluster is starting to talk back. Keep listening."
            )
        }
        return nil
    }

    // MARK: - HTML Generation

    private static func buildHTMLReport(
        salutationName: String,
        playerLevel: PlayerLevel,
        streak: Int,
        periodLabel: String,
        stats: ReportStatistics,
        previousStats: ReportStatistics,
        deltas: ReportDeltas,
        win: ReportWin?,
        inkastingSettings: InkastingSettings
    ) -> String {
        let periodRange = periodRangeLabel(for: .weekly).uppercased()
        let openingHTML = buildOpeningParagraph(stats: stats, streak: streak, deltas: deltas, previousStats: previousStats)
        let bodyHTML = buildBodyParagraph(stats: stats, deltas: deltas, win: win, inkastingSettings: inkastingSettings)
        let ledgerHTML = buildLedgerRows(stats: stats, inkastingSettings: inkastingSettings)
        let winSection = win.map { buildWinSection($0) } ?? "<!-- no win -->"
        let partingLine = win?.partingLine ?? "Same time next week."

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Kubb Coach Weekly</title>
        </head>
        <body style="margin:0;padding:0;background:#EEECE4;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#EEECE4;padding:24px 0;">
          <tr><td align="center">

            <table width="600" cellpadding="0" cellspacing="0" border="0" style="background:#FAF8F3;width:600px;max-width:600px;">

              <!-- 1. MASTHEAD -->
              <tr><td style="padding:32px 48px 4px 48px;">
                <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
                  <td style="font-family:'JetBrains Mono',ui-monospace,Menlo,monospace;font-size:10px;letter-spacing:2px;color:#006AA7;text-transform:uppercase;font-weight:600;">
                    A note from your coach
                  </td>
                  <td align="right" style="font-family:'JetBrains Mono',ui-monospace,Menlo,monospace;font-size:10px;letter-spacing:1.4px;color:rgba(19,37,74,0.6);text-transform:uppercase;">
                    \(periodRange)
                  </td>
                </tr></table>
              </td></tr>

              <!-- 2. SALUTATION + OPENING -->
              <tr><td style="padding:26px 48px 0 48px;">
                <div style="font-family:'Fraunces',Georgia,serif;font-size:40px;line-height:1.05;letter-spacing:-1px;font-weight:500;color:#13254A;">
                  <em style="font-style:italic;font-weight:400;color:#2C3E5E;">Hej,</em> \(salutationName).
                </div>
                <div style="font-size:16px;line-height:1.65;color:#2C3E5E;margin-top:18px;">
                  \(openingHTML)
                </div>
              </td></tr>

              \(winSection)

              <!-- 4. BODY PARAGRAPH -->
              <tr><td style="padding:30px 48px 0 48px;">
                <div style="font-size:16px;line-height:1.7;color:#2C3E5E;">
                  \(bodyHTML)
                </div>
              </td></tr>

              <!-- 5. STATS LEDGER -->
              <tr><td style="padding:28px 48px 0 48px;">
                <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border-top:1px solid rgba(19,37,74,0.10);border-bottom:1px solid rgba(19,37,74,0.10);">
                  \(ledgerHTML)
                </table>
              </td></tr>

              <!-- 6. PARTING LINE + SIGNATURE -->
              <tr><td style="padding:32px 48px 8px 48px;">
                <div style="font-family:'Fraunces',Georgia,serif;font-size:22px;line-height:1.35;letter-spacing:-0.3px;font-weight:500;color:#13254A;font-style:italic;">
                  \(partingLine)
                </div>
                <div style="font-size:14px;color:#2C3E5E;margin-top:16px;line-height:1.6;">
                  See you on the field,
                </div>
                <div style="font-family:'Fraunces',Georgia,serif;font-size:22px;color:#13254A;font-weight:500;margin-top:6px;font-style:italic;">
                  Kubb Coach
                </div>
                \(buildLogoMark())
              </td></tr>

              <!-- 7. COLOPHON -->
              <tr><td style="padding:36px 48px 36px 48px;">
                <div style="border-top:1px solid rgba(19,37,74,0.10);padding-top:16px;">
                  <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
                    <td style="font-family:'JetBrains Mono',ui-monospace,Menlo,monospace;font-size:10px;color:rgba(19,37,74,0.6);letter-spacing:1.2px;text-transform:uppercase;">
                      Kubb Coach · \(formatDate(Date()))
                    </td>
                    <td align="right" style="font-family:'JetBrains Mono',ui-monospace,Menlo,monospace;font-size:10px;color:rgba(19,37,74,0.6);letter-spacing:1.2px;text-transform:uppercase;">
                      Lvl \(playerLevel.levelNumber) · \(formatXP(playerLevel.currentXP)) XP
                    </td>
                  </tr></table>
                </div>
              </td></tr>

            </table>

          </td></tr>
        </table>
        </body>
        </html>
        """
    }

    private static func buildWinSection(_ win: ReportWin) -> String {
        return """
        <tr><td style="padding:34px 48px 8px 48px;">
          <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#13254A;color:#ffffff;"><tr>
            <td style="padding:30px 32px 28px 32px;">
              <div style="font-family:'JetBrains Mono',ui-monospace,Menlo,monospace;font-size:10px;letter-spacing:2px;text-transform:uppercase;color:#FECC02;font-weight:700;">
                The win
              </div>
              <div style="font-family:'Fraunces',Georgia,serif;font-size:96px;line-height:0.85;letter-spacing:-3px;font-weight:500;color:#ffffff;margin-top:14px;white-space:nowrap;">
                \(win.headlineValue)\(win.headlineUnit.isEmpty ? "" : "<span style=\"font-size:36px;font-weight:400;color:#FECC02;margin-left:4px;\">\(win.headlineUnit)</span>")
              </div>
              <div style="font-size:14px;color:rgba(255,255,255,0.75);margin-top:14px;line-height:1.55;max-width:380px;">
                \(win.headlineSubtitleHTML)
              </div>
            </td>
          </tr></table>
        </td></tr>
        """
    }

    // MARK: - Narrative Copy

    private static func buildOpeningParagraph(
        stats: ReportStatistics,
        streak: Int,
        deltas: ReportDeltas,
        previousStats: ReportStatistics
    ) -> String {
        if stats.totalSessions == 0 {
            return "No sessions logged this period. The mat is still there waiting — pick a phase tomorrow and just throw a round."
        }

        let opener = pickOpener(stats: stats, deltas: deltas, previousStats: previousStats)
        let sessionCountFragment = "You showed up <strong style=\"color:#13254A;font-weight:600;\">\(stats.totalSessions) \(pluralize("time", stats.totalSessions))</strong>"

        var middleClauses: [String] = []
        if streak >= 3 {
            middleClauses.append(", your streak now reads <strong style=\"color:#13254A;font-weight:600;\">\(streak) \(pluralize("day", streak))</strong>")
        }
        if let improvementClause = headlineImprovementClause(deltas: deltas, stats: stats) {
            middleClauses.append(", and \(improvementClause)")
        }

        return "\(opener) \(sessionCountFragment)\(middleClauses.joined()). Take a moment."
    }

    /// Returns the strongest single improvement clause for the opening paragraph, drawn from any session type.
    /// Returns nil if nothing qualifies.
    private static func headlineImprovementClause(deltas: ReportDeltas, stats: ReportStatistics) -> String? {
        // Each entry: (magnitude above threshold, clause). Picks the strongest.
        var candidates: [(Double, String)] = []

        if let d = deltas.eightMAccuracy, d >= 2.0 {
            candidates.append((d / 2.0, "your 8-meter line found a rhythm it hadn't held before"))
        }
        if let d = deltas.blastingScore, d <= -2 {
            candidates.append((Double(-d) / 2.0, "your blasting found its line"))
        }
        if let d = deltas.inkastingArea, d <= -0.1 {
            candidates.append((-d / 0.1, "your inkasting cluster tightened"))
        }
        if let d = deltas.phantomFieldEfficiency, d >= 0.3 {
            candidates.append((d / 0.3, "your phantom field work got sharper"))
        }
        if let d = deltas.phantomEightMeterHitRate, d >= 0.05 {
            candidates.append((d / 0.05, "your in-game 8-meter line sharpened in phantom play"))
        }
        if let d = deltas.competitiveFieldEfficiency, d >= 0.3 {
            candidates.append((d / 0.3, "you cleared cleaner under match pressure"))
        }
        if let d = deltas.competitiveEightMeterHitRate, d >= 0.05 {
            candidates.append((d / 0.05, "your competitive 8-meter line held up against opponents"))
        }
        if stats.games.competitive.wins >= 3, stats.games.competitive.losses == 0 {
            candidates.append((1.5, "you went undefeated in competitive play"))
        }
        if let d = deltas.threeFortyThreeAvgScore, d >= 5 {
            candidates.append((d / 5.0, "your 3-4-3 average climbed"))
        }
        if let d = deltas.inTheRedAvgScore, d >= 0.5 {
            candidates.append((d / 0.5, "your In the Red average lifted"))
        }

        return candidates.max(by: { $0.0 < $1.0 })?.1
    }

    private static func pickOpener(
        stats: ReportStatistics,
        deltas: ReportDeltas,
        previousStats: ReportStatistics
    ) -> String {
        // Count improvements across every session type, not just training phases.
        let improvements = [
            (deltas.eightMAccuracy ?? 0) >= 2.0,
            (deltas.blastingScore ?? 0) <= -2,
            (deltas.inkastingArea ?? 0) <= -0.1,
            (deltas.phantomFieldEfficiency ?? 0) >= 0.3,
            (deltas.phantomEightMeterHitRate ?? 0) >= 0.05,
            (deltas.competitiveFieldEfficiency ?? 0) >= 0.3,
            (deltas.competitiveEightMeterHitRate ?? 0) >= 0.05,
            (deltas.threeFortyThreeAvgScore ?? 0) >= 5,
            (deltas.inTheRedAvgScore ?? 0) >= 0.5
        ].filter { $0 }.count

        if previousStats.totalSessions == 0 && stats.totalSessions > 0 {
            // Came back after a break, or first-ever report. Heuristic: if ≤ 2 sessions, "started"; else welcome back.
            return stats.totalSessions <= 2 ? "You've started something." : "Welcome back."
        }
        if improvements >= 2 {
            return "Quietly excellent week."
        }
        if stats.totalSessions <= 2 {
            return "You kept the rhythm going."
        }
        return "Solid week."
    }

    /// A single sentence describing one session subtype's contribution to the week.
    /// Higher `priority` wins when we need to trim fragments to a target count.
    private struct BodyFragment {
        let text: String
        let priority: Int  // 3 = clear improvement, 2 = active/notable, 1 = held steady
    }

    private static func buildBodyParagraph(
        stats: ReportStatistics,
        deltas: ReportDeltas,
        win: ReportWin?,
        inkastingSettings: InkastingSettings
    ) -> String {
        if stats.totalSessions == 0 {
            return "Nothing on the ledger yet. Three throws is a session. Start there."
        }

        // Gather candidate fragments for every active subtype (excluding the Win type).
        let winType = win?.type
        var fragments: [BodyFragment] = []

        // Training: 8 Meter
        if stats.eightMeterCount > 0, winType != .eightMeterImproved {
            if let d = deltas.eightMAccuracy, d >= 2.0 {
                fragments.append(BodyFragment(
                    text: "Your 8-meter accuracy climbed <strong style=\"color:#13254A;font-weight:600;\">\(String(format: "%.1fpt", d))</strong> on the week.",
                    priority: 3
                ))
            } else {
                fragments.append(BodyFragment(
                    text: "8-meter held at <strong style=\"color:#13254A;font-weight:600;\">\(formatPercent(stats.avg8MAccuracy))</strong> average.",
                    priority: 1
                ))
            }
        }

        // Training: Blasting
        if stats.blastingCount > 0, winType != .blastingImproved {
            if let d = deltas.blastingScore, d <= -2 {
                fragments.append(BodyFragment(
                    text: "Blasting trimmed <strong style=\"color:#13254A;font-weight:600;\">\(abs(d)) \(pluralize("point", abs(d)))</strong> off last week's average — fewer wasted batons, more decisive lines.",
                    priority: 3
                ))
            } else {
                fragments.append(BodyFragment(
                    text: "Blasting held its average at <strong style=\"color:#13254A;font-weight:600;\">\(formatSignedInt(stats.avgBlastingScore))</strong>.",
                    priority: 1
                ))
            }
        }

        // Training: Inkasting
        if stats.inkastingCount > 0, winType != .inkastingImproved, let best = stats.bestInkastingArea {
            if let d = deltas.inkastingArea, d <= -0.1 {
                fragments.append(BodyFragment(
                    text: "Inkasting tightened to a <strong style=\"color:#13254A;font-weight:600;\">\(inkastingSettings.formatArea(best)) core</strong>, your tightest cluster this week.",
                    priority: 3
                ))
            } else {
                fragments.append(BodyFragment(
                    text: "Inkasting stayed in its usual range.",
                    priority: 1
                ))
            }
        }

        // Games: Phantom
        if stats.games.phantom.count > 0,
           winType != .phantomFieldImproved, winType != .phantomEightImproved {
            if let d = deltas.phantomFieldEfficiency, d >= 0.3, let eff = stats.games.phantom.fieldEfficiency {
                fragments.append(BodyFragment(
                    text: "Phantom field work sharpened to <strong style=\"color:#13254A;font-weight:600;\">\(formatEfficiency(eff))</strong>.",
                    priority: 3
                ))
            } else if let eff = stats.games.phantom.fieldEfficiency {
                fragments.append(BodyFragment(
                    text: "\(stats.games.phantom.count) phantom \(pluralize("game", stats.games.phantom.count)) at <strong style=\"color:#13254A;font-weight:600;\">\(formatEfficiency(eff))</strong>.",
                    priority: 2
                ))
            } else {
                fragments.append(BodyFragment(
                    text: "\(stats.games.phantom.count) phantom \(pluralize("game", stats.games.phantom.count)) logged.",
                    priority: 1
                ))
            }
        }

        // Games: Competitive
        if stats.games.competitive.count > 0,
           winType != .competitiveFieldImproved, winType != .competitiveEightImproved, winType != .competitiveSweep {
            let record = "\(stats.games.competitive.wins)–\(stats.games.competitive.losses)"
            if let d = deltas.competitiveFieldEfficiency, d >= 0.3, let eff = stats.games.competitive.fieldEfficiency {
                fragments.append(BodyFragment(
                    text: "Competitive field work climbed to <strong style=\"color:#13254A;font-weight:600;\">\(formatEfficiency(eff))</strong> — \(record) on the week.",
                    priority: 3
                ))
            } else {
                fragments.append(BodyFragment(
                    text: "Competitive run: <strong style=\"color:#13254A;font-weight:600;\">\(record)</strong> across \(stats.games.competitive.count) \(pluralize("game", stats.games.competitive.count)).",
                    priority: 2
                ))
            }
        }

        // Pressure Cooker: 3-4-3
        if stats.pressureCooker.threeFortyThree.count > 0, winType != .threeFortyThreeImproved {
            if let d = deltas.threeFortyThreeAvgScore, d >= 5, let avg = stats.pressureCooker.threeFortyThree.averageScore {
                fragments.append(BodyFragment(
                    text: "3-4-3 average climbed to <strong style=\"color:#13254A;font-weight:600;\">\(formatRoundedScore(avg))</strong>.",
                    priority: 3
                ))
            } else if let avg = stats.pressureCooker.threeFortyThree.averageScore {
                fragments.append(BodyFragment(
                    text: "3-4-3 averaging <strong style=\"color:#13254A;font-weight:600;\">\(formatRoundedScore(avg))</strong> across \(stats.pressureCooker.threeFortyThree.count) \(pluralize("game", stats.pressureCooker.threeFortyThree.count)).",
                    priority: 2
                ))
            }
        }

        // Pressure Cooker: In the Red
        if stats.pressureCooker.inTheRed.count > 0, winType != .inTheRedImproved {
            if let d = deltas.inTheRedAvgScore, d >= 0.5, let avg = stats.pressureCooker.inTheRed.averageScore {
                fragments.append(BodyFragment(
                    text: "In the Red lifted to <strong style=\"color:#13254A;font-weight:600;\">\(formatSignedDouble(avg))</strong> on average.",
                    priority: 3
                ))
            } else if let avg = stats.pressureCooker.inTheRed.averageScore {
                fragments.append(BodyFragment(
                    text: "In the Red averaging <strong style=\"color:#13254A;font-weight:600;\">\(formatSignedDouble(avg))</strong> across \(stats.pressureCooker.inTheRed.count) \(pluralize("session", stats.pressureCooker.inTheRed.count)).",
                    priority: 2
                ))
            }
        }

        guard !fragments.isEmpty else {
            return "Nothing dramatic — just reps. That's how this game compounds."
        }

        // Keep the letter tight: pick the top 2 fragments by priority. Stable order otherwise.
        let top = fragments.enumerated().sorted { lhs, rhs in
            if lhs.element.priority != rhs.element.priority {
                return lhs.element.priority > rhs.element.priority
            }
            return lhs.offset < rhs.offset
        }
        .prefix(2)
        .sorted { $0.offset < $1.offset } // restore original ordering for natural reading

        return top.map { $0.element.text }.joined(separator: " ")
    }

    // MARK: - Ledger

    private struct LedgerRow {
        let name: String
        let color: String
        let countLabel: String      // e.g. "3 sessions", "2 games"
        let primaryRight: String    // top metric line
        let secondaryRight: String? // muted secondary line; nil for single-metric rows
    }

    private static func buildLedgerRows(stats: ReportStatistics, inkastingSettings: InkastingSettings) -> String {
        var elements: [String] = []

        let trainingRows = buildTrainingRows(stats: stats, inkastingSettings: inkastingSettings)
        let gamesRows = buildGameRows(stats: stats)
        let pcRows = buildPressureCookerRows(stats: stats)

        if !trainingRows.isEmpty {
            elements.append(contentsOf: trainingRows.map { renderLedgerRow($0, isLast: false) })
        }
        if !gamesRows.isEmpty {
            if !trainingRows.isEmpty { elements.append(renderGroupHeader("Games")) }
            elements.append(contentsOf: gamesRows.map { renderLedgerRow($0, isLast: false) })
        }
        if !pcRows.isEmpty {
            if !trainingRows.isEmpty || !gamesRows.isEmpty {
                elements.append(renderGroupHeader("Pressure Cooker"))
            }
            elements.append(contentsOf: pcRows.map { renderLedgerRow($0, isLast: false) })
        }

        // Suppress the trailing border on the final row by reissuing it without a border.
        if let lastIndex = elements.indices.last, elements[lastIndex].contains("border-bottom:1px") {
            elements[lastIndex] = elements[lastIndex].replacingOccurrences(
                of: "border-bottom:1px solid rgba(19,37,74,0.10)",
                with: "border-bottom:none"
            )
        }

        return elements.joined()
    }

    private static func buildTrainingRows(stats: ReportStatistics, inkastingSettings: InkastingSettings) -> [LedgerRow] {
        var rows: [LedgerRow] = []
        if stats.eightMeterCount > 0 {
            rows.append(LedgerRow(
                name: "8 Meter",
                color: "#006AA7",
                countLabel: "\(stats.eightMeterCount) \(pluralize("session", stats.eightMeterCount))",
                primaryRight: "Best \(formatPercent(stats.best8MAccuracy))",
                secondaryRight: "Avg \(formatPercent(stats.avg8MAccuracy))"
            ))
        }
        if stats.blastingCount > 0 {
            rows.append(LedgerRow(
                name: "Blasting",
                color: "#E08E27",
                countLabel: "\(stats.blastingCount) \(pluralize("session", stats.blastingCount))",
                primaryRight: "Best \(formatSignedInt(stats.bestBlastingScore))",
                secondaryRight: "Avg \(formatSignedInt(stats.avgBlastingScore))"
            ))
        }
        if stats.inkastingCount > 0, let best = stats.bestInkastingArea, let avg = stats.avgInkastingArea {
            rows.append(LedgerRow(
                name: "Inkasting",
                color: "#59A44D",
                countLabel: "\(stats.inkastingCount) \(pluralize("session", stats.inkastingCount))",
                primaryRight: "Best \(inkastingSettings.formatArea(best))",
                secondaryRight: "Avg \(inkastingSettings.formatArea(avg))"
            ))
        }
        return rows
    }

    private static func buildGameRows(stats: ReportStatistics) -> [LedgerRow] {
        var rows: [LedgerRow] = []
        let phantom = stats.games.phantom
        if phantom.count > 0 {
            rows.append(LedgerRow(
                name: "Phantom",
                color: "#6A6175",
                countLabel: "\(phantom.count) \(pluralize("game", phantom.count))",
                primaryRight: phantom.fieldEfficiency.map { "Field \(formatEfficiency($0))" } ?? "Field —",
                secondaryRight: phantom.eightMeterHitRate.map { "8m \(formatPercent($0 * 100))" } ?? "8m —"
            ))
        }
        let comp = stats.games.competitive
        if comp.count > 0 {
            let record = "\(comp.wins)W – \(comp.losses)L"
            let fieldPart = comp.fieldEfficiency.map { "Field \(formatEfficiency($0))" } ?? "Field —"
            let eightPart = comp.eightMeterHitRate.map { "8m \(formatPercent($0 * 100))" } ?? "8m —"
            rows.append(LedgerRow(
                name: "Competitive",
                color: "#B83C2E",
                countLabel: "\(comp.count) \(pluralize("game", comp.count))",
                primaryRight: record,
                secondaryRight: "\(fieldPart) · \(eightPart)"
            ))
        }
        return rows
    }

    private static func buildPressureCookerRows(stats: ReportStatistics) -> [LedgerRow] {
        var rows: [LedgerRow] = []
        let three = stats.pressureCooker.threeFortyThree
        if three.count > 0 {
            rows.append(LedgerRow(
                name: "3-4-3",
                color: "#C99A29",
                countLabel: "\(three.count) \(pluralize("game", three.count))",
                primaryRight: three.averageScore.map { "Avg \(formatRoundedScore($0))" } ?? "Avg —",
                secondaryRight: "/ 130 max"
            ))
        }
        let itr = stats.pressureCooker.inTheRed
        if itr.count > 0 {
            rows.append(LedgerRow(
                name: "In the Red",
                color: "#8B3A3A",
                countLabel: "\(itr.count) \(pluralize("session", itr.count))",
                primaryRight: itr.averageScore.map { "Avg \(formatSignedDouble($0))" } ?? "Avg —",
                secondaryRight: nil
            ))
        }
        return rows
    }

    private static func renderGroupHeader(_ label: String) -> String {
        return """
        <tr><td style="padding:18px 0 4px 0;">
          <div style="font-family:'JetBrains Mono',ui-monospace,Menlo,monospace;font-size:10px;letter-spacing:2px;color:rgba(19,37,74,0.55);text-transform:uppercase;font-weight:600;">
            \(label)
          </div>
        </td></tr>
        """
    }

    private static func renderLedgerRow(_ row: LedgerRow, isLast: Bool) -> String {
        let secondary = row.secondaryRight.map {
            "<div style=\"color:rgba(19,37,74,0.6);margin-top:4px;\">\($0)</div>"
        } ?? ""
        return """
        <tr><td style="padding:16px 0;border-bottom:1px solid rgba(19,37,74,0.10);">
          <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
            <td style="width:4px;padding-right:14px;">
              <div style="width:4px;height:36px;background:\(row.color);"></div>
            </td>
            <td valign="middle">
              <div style="font-family:'Fraunces',Georgia,serif;font-size:18px;color:#13254A;font-weight:500;letter-spacing:-0.2px;">\(row.name)</div>
              <div style="font-family:'JetBrains Mono',ui-monospace,Menlo,monospace;font-size:10px;color:rgba(19,37,74,0.6);letter-spacing:0.8px;text-transform:uppercase;margin-top:2px;">
                \(row.countLabel)
              </div>
            </td>
            <td align="right" valign="middle" style="font-family:'JetBrains Mono',ui-monospace,Menlo,monospace;font-size:12px;color:#13254A;letter-spacing:0.2px;">
              <div>\(row.primaryRight)</div>
              \(secondary)
            </td>
          </tr></table>
        </td></tr>
        """
    }

    // MARK: - App Logo

    /// Cached base64-encoded PNG of the app icon, scaled down for email embedding.
    private static var cachedLogoDataURL: String?

    private static func buildLogoMark() -> String {
        guard let dataURL = appLogoDataURL() else { return "" }
        return """
        <div style="margin-top:14px;">
          <img src="\(dataURL)" alt="Kubb Coach" width="56" height="56" style="display:block;width:56px;height:56px;border:0;outline:none;text-decoration:none;border-radius:12px;" />
        </div>
        """
    }

    private static func appLogoDataURL() -> String? {
        if let cached = cachedLogoDataURL { return cached }

        guard let icon = primaryAppIcon() else { return nil }
        // 56pt display, 2x for retina = 112px source.
        let size = CGSize(width: 112, height: 112)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            icon.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let pngData = resized.pngData() else { return nil }
        let dataURL = "data:image/png;base64,\(pngData.base64EncodedString())"
        cachedLogoDataURL = dataURL
        return dataURL
    }

    /// Pulls the largest pre-rasterized AppIcon variant out of the main bundle.
    private static func primaryAppIcon() -> UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else {
            return nil
        }
        return UIImage(named: name)
    }

    // MARK: - Formatters

    private static func formatXP(_ xp: Int) -> String {
        if xp >= 1000 {
            return String(format: "%.1fk", Double(xp) / 1000.0)
        }
        return "\(xp)"
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func formatPercent(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }

    /// Field-clearing efficiency: kubbs per baton. Typically 0–4 range.
    private static func formatEfficiency(_ value: Double) -> String {
        return String(format: "%.1f k/b", value)
    }

    /// Rounded integer score (3-4-3): "87".
    private static func formatRoundedScore(_ value: Double) -> String {
        return "\(Int(value.rounded()))"
    }

    /// Signed decimal for In the Red averages: "+3.2", "−0.5".
    private static func formatSignedDouble(_ value: Double) -> String {
        if value > 0 { return String(format: "+%.1f", value) }
        if value < 0 { return String(format: "−%.1f", abs(value)) }
        return "0.0"
    }

    /// Blasting scores: "+3", "−2", "0" (uses Unicode minus).
    private static func formatSignedInt(_ value: Int) -> String {
        if value < 0 { return "−\(abs(value))" }
        if value > 0 { return "+\(value)" }
        return "0"
    }

    private static func pluralize(_ word: String, _ count: Int) -> String {
        return count == 1 ? word : "\(word)s"
    }
}

// MARK: - Supporting Types

struct EmailReport {
    let subject: String
    let htmlBody: String
    let generatedAt: Date
}

struct ReportStatistics {
    let totalSessions: Int
    let eightMeterCount: Int
    let blastingCount: Int
    let inkastingCount: Int
    let games: EmailReportService.GameSummary
    let pressureCooker: EmailReportService.PressureCookerSummary
    let best8MAccuracy: Double
    let avg8MAccuracy: Double
    let bestBlastingScore: Int
    let avgBlastingScore: Int
    let bestInkastingArea: Double?
    let avgInkastingArea: Double?

    var gameCount: Int { games.totalCount }
    var pressureCookerCount: Int { pressureCooker.totalCount }
}

struct ReportDeltas {
    let sessions: Int?
    let eightMAccuracy: Double?
    let blastingScore: Int?
    let inkastingArea: Double?

    let phantomFieldEfficiency: Double?
    let phantomEightMeterHitRate: Double?
    let competitiveFieldEfficiency: Double?
    let competitiveEightMeterHitRate: Double?
    let threeFortyThreeAvgScore: Double?
    let inTheRedAvgScore: Double?
}

enum WinType {
    case eightMeterImproved
    case blastingImproved
    case inkastingImproved
    case phantomFieldImproved
    case phantomEightImproved
    case competitiveFieldImproved
    case competitiveEightImproved
    case competitiveSweep
    case threeFortyThreeImproved
    case inTheRedImproved
    case personalBest
    case streakMilestone
    case sessionCount
}

struct ReportWin {
    let type: WinType
    let headlineValue: String
    let headlineUnit: String
    let headlineSubtitleHTML: String
    let partingLine: String
}
