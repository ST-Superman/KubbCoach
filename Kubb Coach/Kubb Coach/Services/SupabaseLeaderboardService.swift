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
                .select("user_id, display_name, accuracy_30d, accuracy_90d, streak_30d, streak_90d, throws_30d, throws_90d, avg_score_30d, avg_score_90d, avg_cluster_30d, avg_cluster_90d")
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

        let row = LeaderboardWriteRow(
            userId: userId,
            displayName: displayName,
            mode: mode.rawValue,
            accuracy30d:   computeAccuracy(sessions: sessions, phase: phase, window: .thirty),
            accuracy90d:   computeAccuracy(sessions: sessions, phase: phase, window: .ninety),
            streak30d:     computeStreak(sessions: sessions, phase: phase, window: .thirty),
            streak90d:     computeStreak(sessions: sessions, phase: phase, window: .ninety),
            throws30d:     computeThrows(sessions: sessions, phase: phase, window: .thirty),
            throws90d:     computeThrows(sessions: sessions, phase: phase, window: .ninety),
            avgScore30d:   phase == .fourMetersBlasting ? computeAvgScore(sessions: sessions, window: .thirty)  : nil,
            avgScore90d:   phase == .fourMetersBlasting ? computeAvgScore(sessions: sessions, window: .ninety)  : nil,
            avgCluster30d: nil,  // inkasting cluster requires modelContext — wired in a future pass
            avgCluster90d: nil,
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

    private func computeAccuracy(sessions: [TrainingSession], phase: TrainingPhase, window: RecencyWindow) -> Double? {
        let r = recent(sessions, phase: phase, window: window)
        guard !r.isEmpty else { return nil }
        return r.reduce(0.0) { $0 + $1.accuracy } / Double(r.count)
    }

    private func computeStreak(sessions: [TrainingSession], phase: TrainingPhase, window: RecencyWindow) -> Int? {
        let r = recent(sessions, phase: phase, window: window)
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        guard !r.isEmpty else { return nil }
        var best = 1, current = 1
        for i in 1..<r.count {
            let dayGap = Calendar.current.dateComponents(
                [.day],
                from: r[i - 1].completedAt ?? .distantPast,
                to:   r[i].completedAt ?? .distantPast
            ).day ?? 0
            current = dayGap == 1 ? current + 1 : 1
            best = max(best, current)
        }
        return best
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

    enum CodingKeys: String, CodingKey {
        case userId        = "user_id"
        case displayName   = "display_name"
        case accuracy30d   = "accuracy_30d"
        case accuracy90d   = "accuracy_90d"
        case streak30d     = "streak_30d"
        case streak90d     = "streak_90d"
        case throws30d     = "throws_30d"
        case throws90d     = "throws_90d"
        case avgScore30d   = "avg_score_30d"
        case avgScore90d   = "avg_score_90d"
        case avgCluster30d = "avg_cluster_30d"
        case avgCluster90d = "avg_cluster_90d"
    }

    func value(for metric: LeaderboardMetric, window: RecencyWindow) -> Double? {
        switch (metric, window) {
        case (.accuracy,         .thirty): return accuracy30d
        case (.accuracy,         .ninety): return accuracy90d
        case (.longestStreak,    .thirty): return streak30d.map(Double.init)
        case (.longestStreak,    .ninety): return streak90d.map(Double.init)
        case (.throwsLogged,     .thirty): return throws30d.map(Double.init)
        case (.throwsLogged,     .ninety): return throws90d.map(Double.init)
        case (.avgScoreVsPar,    .thirty): return avgScore30d
        case (.avgScoreVsPar,    .ninety): return avgScore90d
        case (.avgClusterRadius, .thirty): return avgCluster30d
        case (.avgClusterRadius, .ninety): return avgCluster90d
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
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId        = "user_id"
        case displayName   = "display_name"
        case mode
        case accuracy30d   = "accuracy_30d"
        case accuracy90d   = "accuracy_90d"
        case streak30d     = "streak_30d"
        case streak90d     = "streak_90d"
        case throws30d     = "throws_30d"
        case throws90d     = "throws_90d"
        case avgScore30d   = "avg_score_30d"
        case avgScore90d   = "avg_score_90d"
        case avgCluster30d = "avg_cluster_30d"
        case avgCluster90d = "avg_cluster_90d"
        case updatedAt     = "updated_at"
    }
}
