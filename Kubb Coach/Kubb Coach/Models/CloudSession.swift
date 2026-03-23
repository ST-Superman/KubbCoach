//
//  CloudSession.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import Foundation

/// Lightweight model for training sessions fetched from CloudKit
/// Mirrors TrainingSession structure but doesn't use SwiftData
struct CloudSession: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let completedAt: Date?
    let mode: TrainingMode
    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int
    let startingBaseline: Baseline
    let deviceType: String // "iPhone" or "Watch"
    let syncedAt: Date? // When session was synced to iPhone (nil for newly uploaded sessions)

    var rounds: [CloudRound]

    // Computed properties matching TrainingSession
    var isComplete: Bool {
        completedAt != nil
    }

    var totalThrows: Int {
        rounds.reduce(0) { $0 + $1.throwRecords.count }
    }

    var totalHits: Int {
        rounds.reduce(0) { $0 + $1.hits }
    }

    var totalMisses: Int {
        rounds.reduce(0) { $0 + $1.misses }
    }

    var accuracy: Double {
        let total = totalThrows
        guard total > 0 else { return 0 }
        return (Double(totalHits) / Double(total)) * 100.0
    }

    var kingThrows: [CloudThrow] {
        rounds.flatMap { round in
            round.throwRecords.filter { $0.targetType == .king }
        }
    }

    var kingThrowAccuracy: Double {
        let kingThrows = kingThrows
        guard !kingThrows.isEmpty else { return 0 }
        let hits = kingThrows.filter { $0.result == .hit }.count
        return (Double(hits) / Double(kingThrows.count)) * 100.0
    }

    var kingThrowCount: Int {
        kingThrows.count
    }

    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(createdAt)
    }

    var durationFormatted: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard configuredRounds > 0 else { return 0 }
        return Double(rounds.count) / Double(configuredRounds)
    }

    var currentRoundNumber: Int? {
        rounds.last?.roundNumber
    }

    // MARK: - 4m Blasting Mode Properties

    /// Total session score for 4m blasting mode (sum of all round scores)
    var totalSessionScore: Int? {
        guard phase == .fourMetersBlasting else { return nil }
        return rounds.reduce(0) { $0 + $1.score }
    }

    /// Average round score for 4m blasting mode
    var averageRoundScore: Double? {
        guard phase == .fourMetersBlasting, !rounds.isEmpty else { return nil }
        guard let total = totalSessionScore else { return nil }
        return Double(total) / Double(rounds.count)
    }
}

/// Lightweight model for training rounds from CloudKit
struct CloudRound: Identifiable, Hashable {
    let id: UUID
    let roundNumber: Int
    let startedAt: Date
    let completedAt: Date?
    let targetBaseline: Baseline

    var throwRecords: [CloudThrow]

    var isComplete: Bool {
        throwRecords.count == 6
    }

    var hits: Int {
        throwRecords.filter { $0.result == .hit }.count
    }

    var misses: Int {
        throwRecords.filter { $0.result == .miss }.count
    }

    var accuracy: Double {
        guard !throwRecords.isEmpty else { return 0 }
        return (Double(hits) / Double(throwRecords.count)) * 100.0
    }

    var kubbsRemaining: Int {
        let baselineHits = throwRecords.filter { $0.targetType == .baselineKubb && $0.result == .hit }.count
        return max(0, 5 - baselineHits)
    }

    var canThrowAtKing: Bool {
        kubbsRemaining == 0 && throwRecords.count < 6
    }

    // MARK: - 4m Blasting Mode Properties

    /// Target number of field kubbs for this round (4m blasting only)
    var targetKubbCount: Int {
        min(roundNumber + 1, 10)
    }

    /// Total kubbs knocked down in this round (4m blasting only)
    var totalKubbsKnockedDown: Int {
        throwRecords.compactMap { $0.kubbsKnockedDown }.reduce(0, +)
    }

    /// Check if blasting round is complete
    var isBlastingRoundComplete: Bool {
        let target = targetKubbCount
        return totalKubbsKnockedDown >= target || throwRecords.count >= 6
    }

    /// Remaining kubbs still standing (4m blasting only)
    var remainingKubbs: Int {
        let target = targetKubbCount
        return max(0, target - totalKubbsKnockedDown)
    }

    /// Par score for this round (4m blasting only)
    var par: Int {
        let target = targetKubbCount
        switch target {
        case 2: return 2
        case 3: return 2
        case 4: return 3
        case 5: return 3
        case 6: return 3
        case 7: return 4
        case 8: return 4
        case 9: return 4
        case 10: return 5
        default: return min(target, 6)
        }
    }

    /// Round score for 4m blasting mode (golf-style scoring)
    var score: Int {
        let throwsUsed = throwRecords.count
        let penalty = max(0, remainingKubbs) * 2
        return (throwsUsed - par) + penalty
    }
}

/// Lightweight model for throw records from CloudKit
struct CloudThrow: Identifiable, Hashable {
    let id: UUID
    let throwNumber: Int
    let timestamp: Date
    let result: ThrowResult
    let targetType: TargetType
    let kubbsKnockedDown: Int?  // 4m blasting mode: kubbs knocked (0-10), nil for 8m
}
