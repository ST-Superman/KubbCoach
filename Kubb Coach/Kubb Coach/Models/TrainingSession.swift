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

    // Transient properties (not persisted)
    @Transient
    var newPersonalBests: [UUID] = []

    @Transient
    var newMilestones: [String] = []

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

    // MARK: - 4m Blasting Mode Properties

    /// Total session score for 4m blasting mode (sum of all round scores)
    /// Lower is better (negative is under par)
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

    // MARK: - 4m Blasting Statistics

    /// Count of rounds that finished under par
    var underParRoundsCount: Int {
        guard phase == .fourMetersBlasting else { return 0 }
        return rounds.filter { $0.score < 0 }.count
    }

    /// Returns the number of rounds that finished at a specific score
    func roundsAtScore(_ score: Int) -> Int {
        guard phase == .fourMetersBlasting else { return 0 }
        return rounds.filter { $0.score == score }.count
    }

    /// Best consecutive under-par streak in this session
    var bestUnderParStreak: Int {
        guard phase == .fourMetersBlasting else { return 0 }
        var maxStreak = 0
        var currentStreak = 0

        for round in rounds {
            if round.score < 0 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        return maxStreak
    }

    /// Returns true if all completed rounds in this blasting session are under par
    var isPerfectBlastingSession: Bool {
        guard phase == .fourMetersBlasting else { return false }
        let completedRounds = rounds.filter { $0.completedAt != nil }
        guard !completedRounds.isEmpty else { return false }
        return completedRounds.allSatisfy { $0.score < 0 }
    }

    #if os(iOS)
    // MARK: - Inkasting Mode Properties

    /// Fetches all inkasting analyses for this session's rounds using ModelContext
    /// Note: Due to SwiftData limitations with conditional compilation, we cannot use
    /// the bidirectional relationship, so we query analyses directly
    func fetchInkastingAnalyses(context: ModelContext) -> [InkastingAnalysis] {
        guard phase == .inkastingDrilling else { return [] }

        // If this is a new or active session, don't fetch analyses yet
        // Only fetch for completed sessions or sessions with at least one completed round
        // This prevents crashes from trying to access old orphaned analyses
        guard !rounds.isEmpty else { return [] }

        // Check if at least one round is completed
        let hasCompletedRound = rounds.contains { $0.completedAt != nil }
        guard hasCompletedRound else { return [] }

        // Fetch only recent analyses (from the last 30 days) to avoid old orphaned data
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let descriptor = FetchDescriptor<InkastingAnalysis>(
            predicate: #Predicate { $0.timestamp >= thirtyDaysAgo }
        )
        guard let recentAnalyses = try? context.fetch(descriptor) else { return [] }

        let roundIDs = Set(rounds.map { $0.id })
        var validAnalyses: [InkastingAnalysis] = []

        for analysis in recentAnalyses {
            // Safely attempt to check the round relationship
            // Skip any analyses that cause errors when accessing the relationship
            do {
                if let round = analysis.round, roundIDs.contains(round.id) {
                    validAnalyses.append(analysis)
                }
            } catch {
                // Skip this analysis if accessing the round fails
                print("⚠️ Skipping orphaned analysis: \(error.localizedDescription)")
                continue
            }
        }

        return validAnalyses
    }

    /// Average cluster area for inkasting session (lower is better)
    /// - Parameter context: The ModelContext to use for fetching analyses
    func averageClusterArea(context: ModelContext) -> Double? {
        guard phase == .inkastingDrilling else { return nil }
        let analyses = fetchInkastingAnalyses(context: context)
        guard !analyses.isEmpty else { return nil }
        return analyses.reduce(0.0) { $0 + $1.clusterAreaSquareMeters } / Double(analyses.count)
    }

    /// Total outliers across all rounds in inkasting session
    /// - Parameter context: The ModelContext to use for fetching analyses
    func totalOutliers(context: ModelContext) -> Int? {
        guard phase == .inkastingDrilling else { return nil }
        return fetchInkastingAnalyses(context: context).reduce(0) { $0 + $1.outlierCount }
    }

    /// Best (smallest) cluster area achieved in inkasting session
    /// - Parameter context: The ModelContext to use for fetching analyses
    func bestClusterArea(context: ModelContext) -> Double? {
        guard phase == .inkastingDrilling else { return nil }
        return fetchInkastingAnalyses(context: context).map { $0.clusterAreaSquareMeters }.min()
    }

    /// Kubb count for inkasting session (5 or 10)
    var inkastingKubbCount: Int? {
        guard phase == .inkastingDrilling else { return nil }
        switch sessionType {
        case .inkasting5Kubb:
            return 5
        case .inkasting10Kubb:
            return 10
        default:
            return nil
        }
    }

    /// Total number of kubbs placed across all rounds in this inkasting session
    var totalInkastKubbs: Int {
        guard phase == .inkastingDrilling else { return 0 }
        return rounds.count * (inkastingKubbCount ?? 0)
    }

    /// Returns the count of rounds with perfect accuracy (0 outliers)
    /// - Parameter context: The ModelContext to use for fetching analyses
    func perfectRoundsCount(context: ModelContext) -> Int {
        guard phase == .inkastingDrilling else { return 0 }
        let analyses = fetchInkastingAnalyses(context: context)
        return analyses.filter { $0.outlierCount == 0 }.count
    }

    /// Returns true if all completed rounds in this inkasting session have 0 outliers
    /// - Parameter context: The ModelContext to use for fetching analyses
    func isPerfectInkastingSession(context: ModelContext) -> Bool {
        guard phase == .inkastingDrilling else { return false }
        let analyses = fetchInkastingAnalyses(context: context)
        guard !analyses.isEmpty else { return false }
        return analyses.allSatisfy { $0.outlierCount == 0 }
    }

    /// Best consecutive no-outlier streak in this inkasting session
    /// - Parameter context: The ModelContext to use for fetching analyses
    func bestNoOutlierStreak(context: ModelContext) -> Int {
        guard phase == .inkastingDrilling else { return 0 }
        let analyses = fetchInkastingAnalyses(context: context)
        var maxStreak = 0
        var currentStreak = 0

        for analysis in analyses {
            if analysis.outlierCount == 0 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        return maxStreak
    }
    #endif

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
