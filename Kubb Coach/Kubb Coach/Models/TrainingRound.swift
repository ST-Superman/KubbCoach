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
    #if os(iOS)
    @Relationship(deleteRule: .cascade, inverse: \InkastingAnalysis.round)
    var inkastingAnalysis: InkastingAnalysis?
    #endif
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

    // MARK: - 4m Blasting Mode Properties

    /// Target number of field kubbs for this round (4m blasting only)
    /// Round 1 = 2 kubbs, Round 2 = 3 kubbs, ..., Round 9 = 10 kubbs
    var targetKubbCount: Int? {
        guard session?.phase == .fourMetersBlasting else { return nil }
        return min(roundNumber + 1, 10)
    }

    /// Total kubbs knocked down in this round (4m blasting only)
    var totalKubbsKnockedDown: Int {
        throwRecords.compactMap { $0.kubbsKnockedDown }.reduce(0, +)
    }

    /// Check if blasting round is complete (all kubbs knocked or 6 throws used)
    var isBlastingRoundComplete: Bool {
        guard let target = targetKubbCount else { return false }
        return totalKubbsKnockedDown >= target || throwRecords.count >= 6
    }

    /// Remaining kubbs still standing (4m blasting only)
    var remainingKubbs: Int {
        guard let target = targetKubbCount else { return 0 }
        return max(0, target - totalKubbsKnockedDown)
    }

    /// Par score for this round (4m blasting only)
    /// Par = MIN(field kubbs, 6 throws)
    var par: Int {
        guard let target = targetKubbCount else { return 0 }
        return min(target, 6)
    }

    /// Round score for 4m blasting mode (golf-style scoring)
    /// Score = (throws used - par) + (2 × standing kubbs)
    var score: Int {
        guard session?.phase == .fourMetersBlasting else { return 0 }
        let throwsUsed = throwRecords.count
        let penalty = max(0, remainingKubbs) * 2
        return (throwsUsed - par) + penalty
    }

    // MARK: - Inkasting Mode Properties

    #if os(iOS)
    /// Check if this round has inkasting analysis data
    /// Note: Due to SwiftData limitations with conditional compilation,
    /// we cannot use the bidirectional relationship, so this always returns false.
    /// Use fetchInkastingAnalysis(context:) instead to check for analysis.
    var hasInkastingData: Bool {
        false  // Cannot use relationship due to SwiftData limitation
    }

    /// Fetches the inkasting analysis for this round using ModelContext
    func fetchInkastingAnalysis(context: ModelContext) -> InkastingAnalysis? {
        // Fetch all analyses and filter in memory (SwiftData predicates have limitations)
        let descriptor = FetchDescriptor<InkastingAnalysis>()
        guard let allAnalyses = try? context.fetch(descriptor) else { return nil }

        return allAnalyses.first { analysis in
            analysis.round?.id == self.id
        }
    }
    #endif

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
