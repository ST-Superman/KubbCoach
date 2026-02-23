//
//  TrainingSession.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation
import SwiftData

/// Represents a complete 8M training session with multiple rounds
@Model
final class TrainingSession {
    var id: UUID
    var createdAt: Date
    var completedAt: Date?
    var mode: TrainingMode            // Currently only .eightMeter (legacy)
    var phase: TrainingPhase?         // Training phase (8m, 4m-blasting, inkasting) - optional for backward compatibility
    var sessionType: SessionType?     // Session type variant - optional for backward compatibility
    var configuredRounds: Int         // User-selected: 5, 10, 15, or 20
    var startingBaseline: Baseline    // Which baseline the user started from

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \TrainingRound.session)
    var rounds: [TrainingRound] = []

    // Computed properties
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
        guard totalThrows > 0 else { return 0 }
        return Double(totalHits) / Double(totalThrows) * 100
    }

    /// Returns all throws that targeted the king
    var kingThrows: [ThrowRecord] {
        rounds.flatMap { round in
            round.throwRecords.filter { $0.targetType == .king }
        }
    }

    /// Calculates accuracy for king throws only
    var kingThrowAccuracy: Double {
        guard !kingThrows.isEmpty else { return 0 }
        let kingHits = kingThrows.filter { $0.result == .hit }.count
        return Double(kingHits) / Double(kingThrows.count) * 100
    }

    /// Total number of king throws attempted
    var kingThrowCount: Int {
        kingThrows.count
    }

    /// Duration of the session (if completed)
    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(createdAt)
    }

    /// Human-readable duration string (e.g., "12:34")
    var durationFormatted: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard configuredRounds > 0 else { return 0 }
        let completedRounds = rounds.filter { $0.isComplete }.count
        return Double(completedRounds) / Double(configuredRounds)
    }

    /// Current round number (1-based), or nil if session complete
    var currentRoundNumber: Int? {
        guard !isComplete else { return nil }
        return rounds.last?.roundNumber
    }

    /// Safe access to phase with default value for legacy sessions
    var safePhase: TrainingPhase {
        phase ?? .eightMeters
    }

    /// Safe access to sessionType with default value for legacy sessions
    var safeSessionType: SessionType {
        sessionType ?? .standard
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        mode: TrainingMode = .eightMeter,
        phase: TrainingPhase? = .eightMeters,
        sessionType: SessionType? = .standard,
        configuredRounds: Int,
        startingBaseline: Baseline
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.mode = mode
        self.phase = phase
        self.sessionType = sessionType
        self.configuredRounds = configuredRounds
        self.startingBaseline = startingBaseline
    }
}
