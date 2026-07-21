// SupabaseLeaderboardService.swift
// Real leaderboard backend backed by Supabase (PostgreSQL + RLS).
// Replaces MockLeaderboardService once the Supabase schema is provisioned.
//
// Schema:  leaderboard_entries (user_id, display_name, mode, accuracy_30d/90d,
//          streak_30d/90d, throws_30d/90d, avg_score_30d/90d,
//          avg_cluster_30d/90d, updated_at)
// Auth:    anonymous sign-in (stable UUID per device, stored by SDK in Keychain)
// RLS:     public SELECT, own-row INSERT/UPDATE

import Supabase
import Foundation
import OSLog

final class SupabaseLeaderboardService: LeaderboardServiceProtocol {

    private let db = SupabaseConfig.client
    private let log = Logger(subsystem: "com.sathomps.kubbcoach", category: "Leaderboard")

    // MARK: - LeaderboardServiceProtocol

    func fetchEntries(
        mode: LeaderboardMode,
        metric: LeaderboardMetric,
        window: RecencyWindow
    ) async -> [LeaderboardEntry] {
        await ensureAuth()
        let currentUserId = db.auth.currentUser?.id

        do {
            let rows: [LeaderboardReadRow] = try await db
                .from("leaderboard_entries")
                .select("user_id, display_name, accuracy_30d, accuracy_90d, streak_30d, streak_90d, throws_30d, throws_90d, avg_score_30d, avg_score_90d, avg_cluster_30d, avg_cluster_90d, best_score_30d, best_score_90d, under_par_pct_30d, under_par_pct_90d, session_count_30d, session_count_90d")
                .eq("mode", value: mode.rawValue)
                .execute()
                .value

            let pairs = rows.compactMap { row -> (LeaderboardReadRow, Double)? in
                guard let val = row.value(for: metric, window: window) else { return nil }
                return (row, val)
            }

            let sorted = metric.sortAscending
                ? pairs.sorted { $0.1 < $1.1 }
                : pairs.sorted { $0.1 > $1.1 }

            return sorted.prefix(100).enumerated().map { idx, pair in
                LeaderboardEntry(
                    id: UUID(),
                    rank: idx + 1,
                    displayName: pair.0.displayName,
                    value: pair.1,
                    secondaryValue: pair.0.secondaryValue(for: metric, window: window),
                    isCurrentUser: pair.0.userId == currentUserId
                )
            }
        } catch {
            log.error("Fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    func submitStats(sessions: [TrainingSession], displayName: String) async {
        await ensureAuth()
        guard let userId = db.auth.currentUser?.id else { return }
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for mode in LeaderboardMode.allCases {
                group.addTask { [weak self] in
                    await self?.upsertMode(mode, userId: userId, displayName: displayName, sessions: sessions)
                }
            }
        }
    }

    // MARK: - Auth

    private func ensureAuth() async {
        guard db.auth.currentUser == nil else { return }
        do {
            try await db.auth.signInAnonymously()
        } catch {
            log.error("Anonymous sign-in failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Per-mode upsert

    private func upsertMode(
        _ mode: LeaderboardMode,
        userId: UUID,
        displayName: String,
        sessions: [TrainingSession]
    ) async {
        let phase = mode.trainingPhase

        // Only upsert if the user has at least one session for this mode
        let hasSessions = sessions.contains {
            $0.completedAt != nil && !$0.isTutorialSession && $0.phase == phase
        }
        guard hasSessions else { return }

        let isBlasting  = phase == .fourMetersBlasting
        let isInkasting = phase == .inkastingDrilling
        let row = LeaderboardWriteRow(
            userId: userId,
            displayName: displayName,
            mode: mode.rawValue,
            accuracy30d:          computeAccuracy(sessions: sessions, phase: phase, window: .thirty),
            accuracy90d:          computeAccuracy(sessions: sessions, phase: phase, window: .ninety),
            streak30d:            computeStreak(sessions: sessions, phase: phase, window: .thirty),
            streak90d:            computeStreak(sessions: sessions, phase: phase, window: .ninety),
            throws30d:            computeThrows(sessions: sessions, phase: phase, window: .thirty),
            throws90d:            computeThrows(sessions: sessions, phase: phase, window: .ninety),
            avgScore30d:          isBlasting  ? computeAvgScore(sessions: sessions, window: .thirty)          : nil,
            avgScore90d:          isBlasting  ? computeAvgScore(sessions: sessions, window: .ninety)          : nil,
            avgCluster30d:        nil,
            avgCluster90d:        nil,
            bestScore30d:         isBlasting  ? computeBestScore(sessions: sessions, window: .thirty)         : nil,
            bestScore90d:         isBlasting  ? computeBestScore(sessions: sessions, window: .ninety)         : nil,
            underParPct30d:       isBlasting  ? computeUnderParPct(sessions: sessions, window: .thirty)       : nil,
            underParPct90d:       isBlasting  ? computeUnderParPct(sessions: sessions, window: .ninety)       : nil,
            sessionCount30d:      computeSessionCount(sessions: sessions, phase: phase, window: .thirty),
            sessionCount90d:      computeSessionCount(sessions: sessions, phase: phase, window: .ninety),
            tightestCluster30d:   isInkasting ? computeTightestCluster(sessions: sessions, window: .thirty)   : nil,
            tightestCluster90d:   isInkasting ? computeTightestCluster(sessions: sessions, window: .ninety)   : nil,
            spreadRatio30d:       isInkasting ? computeLowestSpreadRatio(sessions: sessions, window: .thirty)  : nil,
            spreadRatio90d:       isInkasting ? computeLowestSpreadRatio(sessions: sessions, window: .ninety)  : nil,
            inkastCount30d:       isInkasting ? computeInkastCount(sessions: sessions, window: .thirty)       : nil,
            inkastCount90d:       isInkasting ? computeInkastCount(sessions: sessions, window: .ninety)       : nil,
            updatedAt: Date()
        )

        do {
            try await db
                .from("leaderboard_entries")
                .upsert(row, onConflict: "user_id,mode")
                .execute()
        } catch {
            log.error("Upsert failed for \(mode.rawValue): \(error.localizedDescription)")
        }
    }

    // MARK: - Local stat computation

    private func recent(_ sessions: [TrainingSession], phase: TrainingPhase, window: RecencyWindow) -> [TrainingSession] {
        let cutoff = window.startDate
        return sessions.filter {
            $0.completedAt != nil &&
            !$0.isTutorialSession &&
            $0.phase == phase &&
            ($0.completedAt ?? .distantPast) >= cutoff
        }
    }

    // Returns the highest single-session accuracy in the window (used for ranking).
    private func computeAccuracy(sessions: [TrainingSession], phase: TrainingPhase, window: RecencyWindow) -> Double? {
        let r = recent(sessions, phase: phase, window: window)
        guard !r.isEmpty else { return nil }
        return r.map { $0.accuracy }.max()
    }

    // Returns the longest run of consecutive hit throws within a single session in the window.
    private func computeStreak(sessions: [TrainingSession], phase: TrainingPhase, window: RecencyWindow) -> Int? {
        let r = recent(sessions, phase: phase, window: window)
        guard !r.isEmpty else { return nil }
        let best = r.map { session -> Int in
            let allThrows = session.rounds
                .sorted { $0.roundNumber < $1.roundNumber }
                .flatMap { round in round.throwRecords.sorted { $0.throwNumber < $1.throwNumber } }
            var bestStreak = 0, current = 0
            for t in allThrows {
                if t.result == .hit {
                    current += 1
                    bestStreak = max(bestStreak, current)
                } else {
                    current = 0
                }
            }
            return bestStreak
        }.max() ?? 0
        return best > 0 ? best : nil
    }

    private func computeThrows(sessions: [TrainingSession], phase: TrainingPhase, window: RecencyWindow) -> Int? {
        let r = recent(sessions, phase: phase, window: window)
        guard !r.isEmpty else { return nil }
        return r.reduce(0) { $0 + $1.totalThrows }
    }

    private func computeAvgScore(sessions: [TrainingSession], window: RecencyWindow) -> Double? {
        let r = recent(sessions, phase: .fourMetersBlasting, window: window)
        let scores = r.compactMap { $0.totalSessionScore }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private func computeBestScore(sessions: [TrainingSession], window: RecencyWindow) -> Double? {
        let r = recent(sessions, phase: .fourMetersBlasting, window: window)
        let scores = r.compactMap { $0.totalSessionScore }
        guard !scores.isEmpty else { return nil }
        return Double(scores.min()!)
    }

    private func computeUnderParPct(sessions: [TrainingSession], window: RecencyWindow) -> Double? {
        let r = recent(sessions, phase: .fourMetersBlasting, window: window)
        guard !r.isEmpty else { return nil }
        let totalRounds = r.reduce(0) { $0 + $1.rounds.count }
        guard totalRounds > 0 else { return nil }
        let underPar = r.reduce(0) { $0 + $1.underParRoundsCount }
        return Double(underPar) / Double(totalRounds) * 100
    }

    private func computeSessionCount(sessions: [TrainingSession], phase: TrainingPhase, window: RecencyWindow) -> Int? {
        let r = recent(sessions, phase: phase, window: window)
        return r.isEmpty ? nil : r.count
    }

    // MARK: - Inkasting helpers (bypass modelContext — relationship graph is already loaded)

    private func sessionAvgClusterRadius(_ session: TrainingSession) -> Double? {
        let analyses = session.rounds.compactMap { $0.inkastingAnalysis }
        guard !analyses.isEmpty else { return nil }
        return analyses.map { $0.clusterRadiusMeters }.reduce(0.0, +) / Double(analyses.count)
    }

    private func sessionSpreadRatio(_ session: TrainingSession) -> Double? {
        let analyses = session.rounds.compactMap { $0.inkastingAnalysis }
        guard !analyses.isEmpty else { return nil }
        let avgCluster = analyses.map { $0.clusterRadiusMeters }.reduce(0.0, +) / Double(analyses.count)
        guard avgCluster > 0 else { return nil }
        let avgSpread = analyses.map { $0.totalSpreadRadius }.reduce(0.0, +) / Double(analyses.count)
        return avgSpread / avgCluster
    }

    private func computeTightestCluster(sessions: [TrainingSession], window: RecencyWindow) -> Double? {
        let r = recent(sessions, phase: .inkastingDrilling, window: window)
        return r.compactMap { sessionAvgClusterRadius($0) }.min()
    }

    private func computeLowestSpreadRatio(sessions: [TrainingSession], window: RecencyWindow) -> Double? {
        let r = recent(sessions, phase: .inkastingDrilling, window: window)
        return r.compactMap { sessionSpreadRatio($0) }.min()
    }

    private func computeInkastCount(sessions: [TrainingSession], window: RecencyWindow) -> Int? {
        let r = recent(sessions, phase: .inkastingDrilling, window: window)
        guard !r.isEmpty else { return nil }
        let total = r.reduce(0) { $0 + $1.totalInkastKubbs }
        return total > 0 ? total : nil
    }
}

// MARK: - Codable row types (private to this file)

private struct LeaderboardReadRow: Decodable {
    let userId: UUID
    let displayName: String
    let accuracy30d: Double?
    let accuracy90d: Double?
    let streak30d: Int?
    let streak90d: Int?
    let throws30d: Int?
    let throws90d: Int?
    let avgScore30d: Double?
    let avgScore90d: Double?
    let avgCluster30d: Double?
    let avgCluster90d: Double?
    let bestScore30d: Double?
    let bestScore90d: Double?
    let underParPct30d: Double?
    let underParPct90d: Double?
    let sessionCount30d: Int?
    let sessionCount90d: Int?
    let tightestCluster30d: Double?
    let tightestCluster90d: Double?
    let spreadRatio30d: Double?
    let spreadRatio90d: Double?
    let inkastCount30d: Int?
    let inkastCount90d: Int?

    enum CodingKeys: String, CodingKey {
        case userId               = "user_id"
        case displayName          = "display_name"
        case accuracy30d          = "accuracy_30d"
        case accuracy90d          = "accuracy_90d"
        case streak30d            = "streak_30d"
        case streak90d            = "streak_90d"
        case throws30d            = "throws_30d"
        case throws90d            = "throws_90d"
        case avgScore30d          = "avg_score_30d"
        case avgScore90d          = "avg_score_90d"
        case avgCluster30d        = "avg_cluster_30d"
        case avgCluster90d        = "avg_cluster_90d"
        case bestScore30d         = "best_score_30d"
        case bestScore90d         = "best_score_90d"
        case underParPct30d       = "under_par_pct_30d"
        case underParPct90d       = "under_par_pct_90d"
        case sessionCount30d      = "session_count_30d"
        case sessionCount90d      = "session_count_90d"
        case tightestCluster30d   = "tightest_cluster_30d"
        case tightestCluster90d   = "tightest_cluster_90d"
        case spreadRatio30d       = "spread_ratio_30d"
        case spreadRatio90d       = "spread_ratio_90d"
        case inkastCount30d       = "inkast_count_30d"
        case inkastCount90d       = "inkast_count_90d"
    }

    func value(for metric: LeaderboardMetric, window: RecencyWindow) -> Double? {
        let thirty = window == .thirty
        switch metric {
        case .accuracy:         return thirty ? accuracy30d             : accuracy90d
        case .longestStreak:    return thirty ? streak30d.map(Double.init)   : streak90d.map(Double.init)
        case .throwsLogged:     return thirty ? throws30d.map(Double.init)   : throws90d.map(Double.init)
        case .avgScoreVsPar:    return thirty ? avgScore30d             : avgScore90d
        case .avgClusterRadius: return thirty ? avgCluster30d           : avgCluster90d
        case .bestScore:        return thirty ? bestScore30d            : bestScore90d
        case .underParPercent:  return thirty ? underParPct30d          : underParPct90d
        case .sessionCount:     return thirty ? sessionCount30d.map(Double.init) : sessionCount90d.map(Double.init)
        case .tightestCluster:  return thirty ? tightestCluster30d      : tightestCluster90d
        case .spreadRatio:      return thirty ? spreadRatio30d          : spreadRatio90d
        case .inkastCount:      return thirty ? inkastCount30d.map(Double.init)  : inkastCount90d.map(Double.init)
        }
    }

    func secondaryValue(for metric: LeaderboardMetric, window: RecencyWindow) -> Double? {
        switch metric {
        case .bestScore: return window == .thirty ? avgScore30d : avgScore90d
        default: return nil
        }
    }
}

private struct LeaderboardWriteRow: Encodable {
    let userId: UUID
    let displayName: String
    let mode: String
    let accuracy30d: Double?
    let accuracy90d: Double?
    let streak30d: Int?
    let streak90d: Int?
    let throws30d: Int?
    let throws90d: Int?
    let avgScore30d: Double?
    let avgScore90d: Double?
    let avgCluster30d: Double?
    let avgCluster90d: Double?
    let bestScore30d: Double?
    let bestScore90d: Double?
    let underParPct30d: Double?
    let underParPct90d: Double?
    let sessionCount30d: Int?
    let sessionCount90d: Int?
    let tightestCluster30d: Double?
    let tightestCluster90d: Double?
    let spreadRatio30d: Double?
    let spreadRatio90d: Double?
    let inkastCount30d: Int?
    let inkastCount90d: Int?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId               = "user_id"
        case displayName          = "display_name"
        case mode
        case accuracy30d          = "accuracy_30d"
        case accuracy90d          = "accuracy_90d"
        case streak30d            = "streak_30d"
        case streak90d            = "streak_90d"
        case throws30d            = "throws_30d"
        case throws90d            = "throws_90d"
        case avgScore30d          = "avg_score_30d"
        case avgScore90d          = "avg_score_90d"
        case avgCluster30d        = "avg_cluster_30d"
        case avgCluster90d        = "avg_cluster_90d"
        case bestScore30d         = "best_score_30d"
        case bestScore90d         = "best_score_90d"
        case underParPct30d       = "under_par_pct_30d"
        case underParPct90d       = "under_par_pct_90d"
        case sessionCount30d      = "session_count_30d"
        case sessionCount90d      = "session_count_90d"
        case tightestCluster30d   = "tightest_cluster_30d"
        case tightestCluster90d   = "tightest_cluster_90d"
        case spreadRatio30d       = "spread_ratio_30d"
        case spreadRatio90d       = "spread_ratio_90d"
        case inkastCount30d       = "inkast_count_30d"
        case inkastCount90d       = "inkast_count_90d"
        case updatedAt            = "updated_at"
    }
}
