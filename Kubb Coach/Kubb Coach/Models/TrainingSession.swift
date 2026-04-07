//
//  TrainingSession.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation
import SwiftData
import OSLog

// MARK: - Constants

enum SessionConstants {
    static let maxNotesLength = 500
    static let analysisWindowDays = 30
    static let analysisWindowSeconds: TimeInterval = 30 * 24 * 60 * 60
    static let validRoundCounts = [5, 10, 15, 20]
    static let temporaryUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

// MARK: - TrainingSession Model

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
    var deviceType: String?           // "iPhone", "Watch", or nil for legacy sessions
    var isTutorialSession: Bool = false  // If true, session does not grant XP or count toward stats

    // Optional user notes about the session (max 500 chars)
    private var _notes: String?
    var notes: String? {
        get { _notes }
        set {
            if let newValue = newValue, newValue.count > SessionConstants.maxNotesLength {
                _notes = String(newValue.prefix(SessionConstants.maxNotesLength))
                AppLogger.database.warning("Session notes truncated to \(SessionConstants.maxNotesLength) characters")
            } else {
                _notes = newValue
            }
        }
    }

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \TrainingRound.session)
    var rounds: [TrainingRound] = []

    // Transient properties (not persisted)
    @Transient
    var newPersonalBests: [UUID] = []

    @Transient
    var newMilestones: [String] = []

    // Cache for expensive computed properties
    @Transient
    private var _cachedKingThrows: [ThrowRecord]?

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
    /// Cached for performance - call invalidateCache() if rounds change
    var kingThrows: [ThrowRecord] {
        if let cached = _cachedKingThrows {
            return cached
        }
        let kingThrowRecords = rounds.flatMap { round in
            round.throwRecords.filter { $0.targetType == .king }
        }
        _cachedKingThrows = kingThrowRecords
        return kingThrowRecords
    }

    /// Invalidates cached computed properties
    /// Call this when rounds or throws are modified
    func invalidateCache() {
        _cachedKingThrows = nil
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

    // MARK: - King Throw & Blasting Mode Properties
    // On iOS these delegate to SessionAnalytics for a single source of truth.
    // Cross-platform implementations below are used on watchOS.

    /// Calculates accuracy for king throws only
    var kingThrowAccuracy: Double {
        #if os(iOS)
        return analytics.kingThrowAccuracy
        #else
        guard !kingThrows.isEmpty else { return 0 }
        let kingHits = kingThrows.filter { $0.result == .hit }.count
        return Double(kingHits) / Double(kingThrows.count) * 100
        #endif
    }

    /// Total number of king throws attempted
    var kingThrowCount: Int {
        #if os(iOS)
        return analytics.kingThrowCount
        #else
        return kingThrows.count
        #endif
    }

    /// Total session score for 4m blasting mode (sum of all round scores)
    var totalSessionScore: Int? {
        #if os(iOS)
        return analytics.totalSessionScore
        #else
        guard phase == .fourMetersBlasting, !rounds.isEmpty else { return nil }
        return rounds.reduce(0) { $0 + $1.score }
        #endif
    }

    /// Average round score for 4m blasting mode
    var averageRoundScore: Double? {
        #if os(iOS)
        return analytics.averageRoundScore
        #else
        guard phase == .fourMetersBlasting, !rounds.isEmpty else { return nil }
        let total = Double(rounds.reduce(0) { $0 + $1.score })
        return total / Double(rounds.count)
        #endif
    }

    /// Count of rounds that finished under par
    var underParRoundsCount: Int {
        #if os(iOS)
        return analytics.underParRoundsCount
        #else
        guard phase == .fourMetersBlasting else { return 0 }
        return rounds.filter { $0.score < 0 }.count
        #endif
    }

    /// Returns the number of rounds that finished at a specific score
    func roundsAtScore(_ score: Int) -> Int {
        #if os(iOS)
        return analytics.roundsAtScore(score)
        #else
        guard phase == .fourMetersBlasting else { return 0 }
        return rounds.filter { $0.score == score }.count
        #endif
    }

    /// Best consecutive under-par streak in this session
    var bestUnderParStreak: Int {
        #if os(iOS)
        return analytics.bestUnderParStreak
        #else
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
        #endif
    }

    /// Returns true if all completed rounds in this blasting session are under par
    var isPerfectBlastingSession: Bool {
        #if os(iOS)
        return analytics.isPerfectBlastingSession
        #else
        guard phase == .fourMetersBlasting else { return false }
        let completedRounds = rounds.filter { $0.completedAt != nil }
        guard !completedRounds.isEmpty else { return false }
        return completedRounds.allSatisfy { $0.score < 0 }
        #endif
    }

    // MARK: - Inkasting Mode Properties

    /// Validates that all rounds are accessible and not invalidated
    /// Returns false if any round's backing data is missing or inaccessible
    private func validateRounds() -> Bool {
        guard !rounds.isEmpty else { return false }

        // Verify each round has valid backing data
        for round in rounds {
            // Check if round has a valid model context (not deleted/invalidated)
            guard round.modelContext != nil else { return false }

            // Verify the round has a non-zero ID (temporary IDs are all zeros)
            guard round.id != SessionConstants.temporaryUUID else { return false }
        }

        return true
    }

    /// Fetches all inkasting analyses for this session's rounds
    /// OPTIMIZED: Uses direct relationship instead of querying all analyses in database
    /// Available on both iOS and watchOS for goal evaluation compatibility
    /// Thread-safe: Can be called from any context (ModelContext reads are thread-safe)
    /// - Parameter context: ModelContext (parameter kept for API compatibility but not used)
    func fetchInkastingAnalyses(context: ModelContext) -> [InkastingAnalysis] {
        #if os(watchOS)
        // Inkasting sessions can only be created on iOS, so return empty on watchOS
        return []
        #else
        guard phase == .inkastingDrilling else { return [] }
        guard !rounds.isEmpty else { return [] }

        // CRITICAL FIX: Validate rounds before accessing properties
        guard validateRounds() else {
            AppLogger.database.warning("fetchInkastingAnalyses: Invalid rounds detected (temporary IDs or invalidated), returning empty")
            return []
        }

        // OPTIMIZED: Use direct relationship - O(n) where n = rounds in this session
        // Previous implementation was O(m) where m = all analyses in database
        // This is 10-100x faster depending on database size
        return rounds.compactMap { $0.inkastingAnalysis }
        #endif
    }

    // MARK: - Inkasting Mode Properties
    // On iOS these delegate to SessionAnalytics for a single source of truth.
    // averageClusterArea and totalOutliers are cross-platform (used for goal evaluation on iOS,
    // return nil/0 on watchOS via fetchInkastingAnalyses early-return).

    /// Average cluster area for inkasting session (lower is better)
    func averageClusterArea(context: ModelContext) -> Double? {
        #if os(iOS)
        return analytics.averageClusterArea(context: context)
        #else
        guard phase == .inkastingDrilling else { return nil }
        let analyses = fetchInkastingAnalyses(context: context)
        guard !analyses.isEmpty else { return nil }
        return analyses.reduce(0.0) { $0 + $1.clusterAreaSquareMeters } / Double(analyses.count)
        #endif
    }

    /// Total outliers across all rounds in inkasting session
    func totalOutliers(context: ModelContext) -> Int? {
        #if os(iOS)
        return analytics.totalOutliers(context: context)
        #else
        guard phase == .inkastingDrilling else { return nil }
        return fetchInkastingAnalyses(context: context).reduce(0) { $0 + $1.outlierCount }
        #endif
    }

    #if os(iOS)

    /// Best (smallest) cluster area achieved in inkasting session
    func bestClusterArea(context: ModelContext) -> Double? {
        analytics.bestClusterArea(context: context)
    }

    /// Kubb count for inkasting session (5 or 10)
    var inkastingKubbCount: Int? {
        analytics.inkastingKubbCount
    }

    /// Total number of kubbs placed across all rounds in this inkasting session
    var totalInkastKubbs: Int {
        analytics.totalInkastKubbs
    }

    /// Returns the count of rounds with perfect accuracy (0 outliers)
    func perfectRoundsCount(context: ModelContext) -> Int {
        analytics.perfectRoundsCount(context: context)
    }

    /// Returns true if all completed rounds in this inkasting session have 0 outliers
    func isPerfectInkastingSession(context: ModelContext) -> Bool {
        analytics.isPerfectInkastingSession(context: context)
    }

    /// Best consecutive no-outlier streak in this inkasting session
    func bestNoOutlierStreak(context: ModelContext) -> Int {
        analytics.bestNoOutlierStreak(context: context)
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
        startingBaseline: Baseline,
        isTutorialSession: Bool = false
    ) {
        // Validate configuredRounds and use safe fallback if invalid
        if !SessionConstants.validRoundCounts.contains(configuredRounds) {
            AppLogger.database.error("Invalid configuredRounds: \(configuredRounds). Must be 5, 10, 15, or 20. Defaulting to 10.")
            self.configuredRounds = 10
        } else {
            self.configuredRounds = configuredRounds
        }

        // Initialize all properties once
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.mode = mode
        self.phase = phase
        self.sessionType = sessionType
        self.startingBaseline = startingBaseline
        self.isTutorialSession = isTutorialSession

        // Set deviceType based on platform
        #if os(iOS)
        self.deviceType = "iPhone"
        #elseif os(watchOS)
        self.deviceType = "Watch"
        #else
        self.deviceType = nil
        #endif
    }
}
