//
//  StatisticsViewModel.swift
//  Kubb Coach
//
//  Created by Claude Code on 4/6/26.
//

import Foundation
import SwiftData
import OSLog

@Observable
@MainActor
class StatisticsViewModel {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Async Calculated Statistics

    var mostConsecutiveHits: Int = 0
    var mostKubbsCleared: Int = 0
    var perfectRoundsCount: Int = 0
    var isCalculatingStats: Bool = false

    // MARK: - Cached Filtered Sessions (Performance Optimization)

    var cachedEightMeterSessions: [SessionDisplayItem] = []
    var cachedBlastingSessions: [SessionDisplayItem] = []
    var cachedInkastingSessions: [SessionDisplayItem] = []

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Player Level (Feature Gating)

    var playerLevel: PlayerLevel {
        PlayerLevelService.computeLevel(using: modelContext)
    }

    // MARK: - All Sessions (Filtered)

    func allSessionItems(from localSessions: [TrainingSession]) -> [SessionDisplayItem] {
        // Filter Watch sessions until Level 2
        let filteredSessions = localSessions.filter { session in
            guard session.deviceType == "Watch" else { return true }
            return playerLevel.levelNumber >= 2
        }

        return filteredSessions.map { .local($0) }.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Cache Update

    func updateCachedSessions(from localSessions: [TrainingSession]) {
        let all = allSessionItems(from: localSessions)
        cachedEightMeterSessions = all.filter { $0.phase == .eightMeters }
        cachedBlastingSessions = all.filter { $0.phase == .fourMetersBlasting }
        cachedInkastingSessions = all.filter { $0.phase == .inkastingDrilling }
    }

    // MARK: - Current Streak

    func currentStreak(from localSessions: [TrainingSession]) -> Int {
        StreakCalculator.currentStreak(from: allSessionItems(from: localSessions))
    }

    // MARK: - 8m Phase Metrics

    var eightMeterAccuracy: Double {
        guard !cachedEightMeterSessions.isEmpty else { return 0 }
        let total = cachedEightMeterSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(cachedEightMeterSessions.count)
    }

    var eightMeterThrows: Int {
        cachedEightMeterSessions.reduce(0) { $0 + $1.totalThrows }
    }

    var eightMeterAverageAccuracy: Double {
        eightMeterAccuracy
    }

    var eightMeterTotalThrows: Int {
        eightMeterThrows
    }

    var eightMeterTotalKingThrows: Int {
        cachedEightMeterSessions.reduce(0) { $0 + $1.kingThrowCount }
    }

    var eightMeterKingThrowHits: Int {
        cachedEightMeterSessions.reduce(0) { total, session in
            let hits: Int
            switch session {
            case .local(let localSession):
                hits = localSession.kingThrows.filter { $0.result == .hit }.count
            case .cloud(let cloudSession):
                hits = cloudSession.kingThrows.filter { $0.result == .hit }.count
            }
            return total + hits
        }
    }

    var eightMeterKingThrowAccuracy: String {
        guard eightMeterTotalKingThrows > 0 else { return "0" }
        let percentage = (Double(eightMeterKingThrowHits) / Double(eightMeterTotalKingThrows)) * 100
        return String(format: "%.0f", percentage)
    }

    // MARK: - Blasting Phase Metrics

    var blastingThrows: Int {
        cachedBlastingSessions.reduce(0) { $0 + $1.totalThrows }
    }

    var bestBlastingScore: Int? {
        guard !cachedBlastingSessions.isEmpty else { return nil }
        let scores = cachedBlastingSessions.compactMap { session -> Int? in
            switch session {
            case .local(let localSession):
                return localSession.totalSessionScore
            case .cloud(let cloudSession):
                return cloudSession.totalSessionScore
            }
        }
        return scores.min()
    }

    // MARK: - Inkasting Phase Metrics

    var totalInkastKubbs: Int {
        cachedInkastingSessions.reduce(0) { total, session in
            switch session {
            case .local(let localSession):
                let analyses = localSession.fetchInkastingAnalyses(context: modelContext)
                return total + (analyses.count * (localSession.inkastingKubbCount ?? 5))
            case .cloud:
                return total
            }
        }
    }

    var bestInkastingCluster: Double? {
        guard !cachedInkastingSessions.isEmpty else { return nil }
        let clusters = cachedInkastingSessions.compactMap { session -> Double? in
            switch session {
            case .local(let localSession):
                return localSession.bestClusterArea(context: modelContext)
            case .cloud:
                return nil
            }
        }
        return clusters.min()
    }

    // MARK: - Personal Records (8m specific)

    var bestAccuracySession: SessionDisplayItem? {
        cachedEightMeterSessions.max(by: { $0.accuracy < $1.accuracy })
    }

    var bestSessionAccuracyText: String {
        guard let bestSession = bestAccuracySession else { return "N/A" }
        return String(format: "%.1f%% (%d throws)", bestSession.accuracy, bestSession.totalThrows)
    }

    var mostKubbsSession: SessionDisplayItem? {
        var bestSession: SessionDisplayItem?
        var maxKubbs = 0

        for item in cachedEightMeterSessions {
            var kubbCount = 0
            switch item {
            case .local(let session):
                for round in session.rounds {
                    kubbCount += round.throwRecords.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count
                }
            case .cloud(let session):
                for round in session.rounds {
                    kubbCount += round.throwRecords.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count
                }
            }
            if kubbCount > maxKubbs {
                maxKubbs = kubbCount
                bestSession = item
            }
        }

        return bestSession
    }

    var longestSession: SessionDisplayItem? {
        cachedEightMeterSessions.max { (item1, item2) in
            let duration1 = item1.localSession?.duration ?? item1.cloudSession?.duration ?? 0
            let duration2 = item2.localSession?.duration ?? item2.cloudSession?.duration ?? 0
            return duration1 < duration2
        }
    }

    var longestSessionText: String {
        guard let session = longestSession,
              let duration = session.durationFormatted else {
            return "N/A"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let dateStr = dateFormatter.string(from: session.createdAt)
        return "\(duration) (\(session.totalThrows) throws, \(dateStr))"
    }

    // MARK: - Weekly Round Metrics

    func currentWeekRounds(from localSessions: [TrainingSession]) -> Int {
        let all = allSessionItems(from: localSessions)
        guard !all.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let windowStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        return all
            .filter { $0.createdAt >= windowStart && $0.createdAt < windowEnd }
            .reduce(0) { $0 + $1.roundCount }
    }

    func mostRoundsInWeek(from localSessions: [TrainingSession]) -> Int {
        let all = allSessionItems(from: localSessions)
        guard !all.isEmpty else { return 0 }

        let sortedSessions = all.sorted { $0.createdAt < $1.createdAt }
        guard let firstDate = sortedSessions.first?.createdAt,
              let lastDate = sortedSessions.last?.createdAt else {
            return 0
        }

        var maxRounds = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: firstDate)
        let endDate = calendar.startOfDay(for: lastDate)

        while currentDate <= endDate {
            let windowStart = calendar.date(byAdding: .day, value: -6, to: currentDate) ?? currentDate
            let windowEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate

            let roundsInWindow = all
                .filter { $0.createdAt >= windowStart && $0.createdAt < windowEnd }
                .reduce(0) { $0 + $1.roundCount }

            maxRounds = max(maxRounds, roundsInWindow)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return maxRounds
    }

    // MARK: - Async Statistics Calculation

    func calculateExpensiveStats() async {
        isCalculatingStats = true

        let sortedSessions = cachedEightMeterSessions.sorted(by: { $0.createdAt < $1.createdAt })
        let sessionData: [SessionStatsData] = sortedSessions.map { item in
            extractSessionStatsData(from: item)
        }

        let (maxStreak, maxKubbs, perfectCount) = await Task.detached {
            var currentStreak = 0
            var maxStreakValue = 0
            var maxKubbsValue = 0
            var perfectRounds = 0

            for session in sessionData {
                for round in session.rounds {
                    for throwData in round.throwRecords {
                        if throwData.result == .hit {
                            currentStreak += 1
                            maxStreakValue = max(maxStreakValue, currentStreak)
                        } else {
                            currentStreak = 0
                        }
                    }
                }

                for round in session.rounds {
                    if round.accuracy == 100 && round.throwCount == 6 {
                        perfectRounds += 1
                    }
                }

                maxKubbsValue = max(maxKubbsValue, session.kubbHitCount)
            }

            return (maxStreakValue, maxKubbsValue, perfectRounds)
        }.value

        mostConsecutiveHits = maxStreak
        mostKubbsCleared = maxKubbs
        perfectRoundsCount = perfectCount
        isCalculatingStats = false
    }

    // MARK: - One-Time Migration

    func runMigrationIfNeeded(hasMigratedPersonalBests: Bool) {
        guard !hasMigratedPersonalBests else { return }

        let pbService = PersonalBestService(modelContext: modelContext)
        pbService.migrateExistingSessionsToPersonalBests()

        let milestoneService = MilestoneService(modelContext: modelContext)
        milestoneService.migrateExistingSessionsToMilestones()
    }

    // MARK: - Helper Methods for Data Extraction

    private func extractSessionStatsData(from item: SessionDisplayItem) -> SessionStatsData {
        let rounds: [RoundStatsData]

        switch item {
        case .local(let session):
            rounds = session.rounds.map { extractRoundStatsData(from: $0) }
        case .cloud(let session):
            rounds = session.rounds.map { extractRoundStatsData(from: $0) }
        }

        let allThrows: [ThrowStatsData] = rounds.flatMap { $0.throwRecords }
        let kubbHits = allThrows.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count

        return SessionStatsData(rounds: rounds, kubbHitCount: kubbHits)
    }

    private func extractRoundStatsData(from round: TrainingRound) -> RoundStatsData {
        let throwRecords: [ThrowStatsData] = round.throwRecords.map { throwRecord in
            ThrowStatsData(result: throwRecord.result, targetType: throwRecord.targetType)
        }
        return RoundStatsData(
            throwRecords: throwRecords,
            accuracy: round.accuracy,
            throwCount: round.throwRecords.count
        )
    }

    private func extractRoundStatsData(from round: CloudRound) -> RoundStatsData {
        let throwRecords: [ThrowStatsData] = round.throwRecords.map { throwRecord in
            ThrowStatsData(result: throwRecord.result, targetType: throwRecord.targetType)
        }
        return RoundStatsData(
            throwRecords: throwRecords,
            accuracy: round.accuracy,
            throwCount: round.throwRecords.count
        )
    }
}
