//
//  TrainingRound.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation
import SwiftData

/// Represents a single round within a training session (6 throws)
@Model
final class TrainingRound {
    var id: UUID
    var roundNumber: Int           // 1-based numbering (1, 2, 3, ...)
    var startedAt: Date
    var completedAt: Date?
    var targetBaseline: Baseline   // Which baseline the user is throwing toward

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \ThrowRecord.round)
    var throwRecords: [ThrowRecord] = []
    var session: TrainingSession?

    // Computed properties
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
        return Double(hits) / Double(throwRecords.count) * 100
    }

    /// Returns the number of baseline kubbs still standing
    var kubbsRemaining: Int {
        // Start with 5 kubbs, subtract the number of hits on baseline kubbs
        let baselineHits = throwRecords.filter {
            $0.result == .hit && $0.targetType == .baselineKubb
        }.count
        return max(0, 5 - baselineHits)
    }

    /// Determines if the user can throw at the king
    /// (all 5 kubbs hit and still have a throw remaining)
    var canThrowAtKing: Bool {
        let baselineHits = throwRecords.filter {
            $0.result == .hit && $0.targetType == .baselineKubb
        }.count
        return throwRecords.count == 5 && baselineHits == 5
    }

    init(
        id: UUID = UUID(),
        roundNumber: Int,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        targetBaseline: Baseline
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.targetBaseline = targetBaseline
    }
}
