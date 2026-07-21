// LeaderboardService.swift
// Backend abstraction for the global leaderboard. Currently backed by mock
// data. Replace MockLeaderboardService with CloudKitLeaderboardService (or
// SupabaseLeaderboardService) once the public data layer is provisioned.
//
// CloudKit setup required before shipping (manual, not code):
//   1. CloudKit Console → iCloud.ST-Superman.Kubb-Coach → Schema
//   2. Add Record Type "LeaderboardEntry" with fields:
//      playerName (String), mode (String), metric (String),
//      value (Double), windowDate (Date)
//   3. Indexes: value → Sortable; mode/metric/windowDate → Queryable
//   4. Deploy to Production

import Foundation

// MARK: - Protocol

protocol LeaderboardServiceProtocol {
    func fetchEntries(
        mode: LeaderboardMode,
        metric: LeaderboardMetric,
        window: RecencyWindow
    ) async -> [LeaderboardEntry]

    /// Upload the user's pre-aggregated stats for all modes. No-op on mock.
    func submitStats(sessions: [TrainingSession], displayName: String) async
}

// MARK: - Mock implementation

final class MockLeaderboardService: LeaderboardServiceProtocol {

    // Fixed player pool — same names every call, deterministic.
    private let basePool: [(name: String, seed: Double)] = [
        ("Lars N.",    97.0),
        ("Sofia B.",   95.0),
        ("Oskar L.",   91.0),
        ("Maja H.",    89.0),
        ("Erik S.",    87.0),
        ("Anna K.",    84.0),
        ("Björn T.",   80.0),
        ("Lena M.",    77.0),
        ("Petter A.",  73.0),
    ]

    func submitStats(sessions: [TrainingSession], displayName: String) async {}

    func fetchEntries(
        mode: LeaderboardMode,
        metric: LeaderboardMetric,
        window: RecencyWindow
    ) async -> [LeaderboardEntry] {
        // Slight offset for 90d window to make it feel different from 30d
        let windowBoost: Double = window == .ninety ? 1.08 : 1.0

        return basePool.enumerated().map { index, player in
            let value = mockValue(
                for: metric,
                rank: index + 1,
                seed: player.seed,
                windowBoost: windowBoost
            )
            return LeaderboardEntry(
                id: UUID(),
                rank: index + 1,
                displayName: player.name,
                value: value,
                isCurrentUser: false
            )
        }
    }

    // Produces realistic values per metric/rank combination
    private func mockValue(
        for metric: LeaderboardMetric,
        rank: Int,
        seed: Double,
        windowBoost: Double
    ) -> Double {
        switch metric {
        case .accuracy:
            let values = [96.8, 95.4, 91.2, 89.7, 87.3, 84.1, 80.5, 77.2, 73.8]
            return (values[safeIndex: rank - 1] ?? max(72.0, seed - Double(rank) * 2.5)) * windowBoost

        case .longestStreak:
            let values: [Double] = [18, 14, 12, 10, 9, 8, 7, 6, 5]
            return (values[safeIndex: rank - 1] ?? max(3, 15 - Double(rank))) * windowBoost

        case .throwsLogged:
            let values: [Double] = [780, 756, 703, 681, 640, 598, 555, 510, 487]
            return values[safeIndex: rank - 1] ?? max(300, 800 - Double(rank) * 38)

        case .avgScoreVsPar:
            // Lower (more negative) = better; rank 1 is best score
            let values = [-3.8, -3.2, -2.7, -2.1, -1.8, -1.2, -0.6, 0.1, 0.8]
            return (values[safeIndex: rank - 1] ?? Double(rank - 5) * 0.6) * windowBoost

        case .avgClusterRadius:
            let values = [0.18, 0.22, 0.27, 0.31, 0.35, 0.41, 0.48, 0.55, 0.63]
            return (values[safeIndex: rank - 1] ?? 0.12 + Double(rank) * 0.06) * windowBoost

        case .bestScore:
            let values = [-5.0, -4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0]
            return (values[safeIndex: rank - 1] ?? Double(rank - 4)) * windowBoost

        case .underParPercent:
            let values: [Double] = [88, 82, 76, 70, 63, 55, 47, 38, 29]
            return (values[safeIndex: rank - 1] ?? max(10, 90 - Double(rank) * 8)) * windowBoost

        case .sessionCount:
            let values: [Double] = [42, 38, 33, 28, 24, 20, 16, 12, 8]
            return values[safeIndex: rank - 1] ?? max(4, 45 - Double(rank) * 4)

        case .tightestCluster:
            let values = [0.14, 0.18, 0.22, 0.27, 0.32, 0.38, 0.44, 0.51, 0.59]
            return values[safeIndex: rank - 1] ?? 0.10 + Double(rank) * 0.05

        case .spreadRatio:
            let values = [1.15, 1.35, 1.60, 1.90, 2.25, 2.65, 3.10, 3.60, 4.20]
            return values[safeIndex: rank - 1] ?? 1.0 + Double(rank) * 0.32

        case .inkastCount:
            let values: [Double] = [480, 415, 355, 300, 250, 205, 165, 130, 100]
            return values[safeIndex: rank - 1] ?? max(60, 510 - Double(rank) * 45)
        }
    }
}

// MARK: - Helpers

// Local safe subscript — avoids conflicts with any project-wide extension
private extension Array {
    subscript(safeIndex index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
