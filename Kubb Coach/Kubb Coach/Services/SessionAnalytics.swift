//
//  SessionAnalytics.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/29/26.
//

import Foundation
import SwiftData

/// Provides analytics and statistical computations for a single training session
/// Extracted from TrainingSession to improve separation of concerns and testability
struct SessionAnalytics {
    let session: TrainingSession

    // MARK: - Initialization

    init(session: TrainingSession) {
        self.session = session
    }

    // MARK: - King Throw Analytics

    /// Calculates accuracy for king throws only
    var kingThrowAccuracy: Double {
        guard !session.kingThrows.isEmpty else { return 0 }
        let kingHits = session.kingThrows.filter { $0.result == .hit }.count
        return Double(kingHits) / Double(session.kingThrows.count) * 100
    }

    /// Total number of king throws attempted
    var kingThrowCount: Int {
        session.kingThrows.count
    }

    // MARK: - 4m Blasting Analytics

    /// Count of rounds that finished under par
    var underParRoundsCount: Int {
        guard session.phase == .fourMetersBlasting else { return 0 }
        return session.rounds.filter { $0.score < 0 }.count
    }

    /// Returns the number of rounds that finished at a specific score
    func roundsAtScore(_ score: Int) -> Int {
        guard session.phase == .fourMetersBlasting else { return 0 }
        return session.rounds.filter { $0.score == score }.count
    }

    /// Best consecutive under-par streak in this session
    var bestUnderParStreak: Int {
        guard session.phase == .fourMetersBlasting else { return 0 }
        var maxStreak = 0
        var currentStreak = 0

        for round in session.rounds {
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
        guard session.phase == .fourMetersBlasting else { return false }
        let completedRounds = session.rounds.filter { $0.completedAt != nil }
        guard !completedRounds.isEmpty else { return false }
        return completedRounds.allSatisfy { $0.score < 0 }
    }

    // MARK: - Inkasting Analytics

    #if os(iOS)

    /// Average cluster area for inkasting session (lower is better)
    /// - Parameter context: The ModelContext to use for fetching analyses
    func averageClusterArea(context: ModelContext) -> Double? {
        guard session.phase == .inkastingDrilling else { return nil }
        let analyses = session.fetchInkastingAnalyses(context: context)
        guard !analyses.isEmpty else { return nil }
        return analyses.reduce(0.0) { $0 + $1.clusterAreaSquareMeters } / Double(analyses.count)
    }

    /// Total outliers across all rounds in inkasting session
    /// - Parameter context: The ModelContext to use for fetching analyses
    func totalOutliers(context: ModelContext) -> Int? {
        guard session.phase == .inkastingDrilling else { return nil }
        return session.fetchInkastingAnalyses(context: context).reduce(0) { $0 + $1.outlierCount }
    }

    /// Best (smallest) cluster area achieved in inkasting session
    /// - Parameter context: The ModelContext to use for fetching analyses
    func bestClusterArea(context: ModelContext) -> Double? {
        guard session.phase == .inkastingDrilling else { return nil }
        return session.fetchInkastingAnalyses(context: context).map { $0.clusterAreaSquareMeters }.min()
    }

    /// Returns the count of rounds with perfect accuracy (0 outliers)
    /// - Parameter context: The ModelContext to use for fetching analyses
    func perfectRoundsCount(context: ModelContext) -> Int {
        guard session.phase == .inkastingDrilling else { return 0 }
        let analyses = session.fetchInkastingAnalyses(context: context)
        return analyses.filter { $0.outlierCount == 0 }.count
    }

    /// Returns true if all completed rounds in this inkasting session have 0 outliers
    /// - Parameter context: The ModelContext to use for fetching analyses
    func isPerfectInkastingSession(context: ModelContext) -> Bool {
        guard session.phase == .inkastingDrilling else { return false }
        let analyses = session.fetchInkastingAnalyses(context: context)
        guard !analyses.isEmpty else { return false }
        return analyses.allSatisfy { $0.outlierCount == 0 }
    }

    /// Best consecutive no-outlier streak in this inkasting session
    /// - Parameter context: The ModelContext to use for fetching analyses
    func bestNoOutlierStreak(context: ModelContext) -> Int {
        guard session.phase == .inkastingDrilling else { return 0 }
        let analyses = session.fetchInkastingAnalyses(context: context)
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

    /// Kubb count for inkasting session (5 or 10)
    var inkastingKubbCount: Int? {
        guard session.phase == .inkastingDrilling else { return nil }
        switch session.sessionType {
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
        guard session.phase == .inkastingDrilling else { return 0 }
        return session.rounds.count * (inkastingKubbCount ?? 0)
    }

    #endif

    // MARK: - General Session Analytics

    /// Total session score for 4m blasting mode (sum of all round scores)
    /// Lower is better (negative is under par)
    var totalSessionScore: Int? {
        guard session.phase == .fourMetersBlasting else { return nil }
        return session.rounds.reduce(0) { $0 + $1.score }
    }

    /// Average round score for 4m blasting mode
    var averageRoundScore: Double? {
        guard session.phase == .fourMetersBlasting, !session.rounds.isEmpty else { return nil }
        guard let total = totalSessionScore else { return nil }
        return Double(total) / Double(session.rounds.count)
    }
}

// MARK: - TrainingSession Extension

extension TrainingSession {
    /// Returns an analytics wrapper for this session
    var analytics: SessionAnalytics {
        SessionAnalytics(session: self)
    }
}
