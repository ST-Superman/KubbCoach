//
//  TrainingSessionManager.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation
import SwiftData
import Observation

/// Manages the lifecycle and state of training sessions
@Observable
final class TrainingSessionManager {
    var currentSession: TrainingSession?
    var currentRound: TrainingRound?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Session Management

    /// Starts a new training session
    @discardableResult
    func startSession(phase: TrainingPhase, sessionType: SessionType, rounds: Int) -> TrainingSession {
        let session = TrainingSession(
            phase: phase,
            sessionType: sessionType,
            configuredRounds: rounds,
            startingBaseline: .north  // Always start at north baseline
        )

        modelContext.insert(session)
        currentSession = session

        // Create the first round
        startFirstRound(for: session)

        return session
    }

    /// Completes the current session
    func completeSession() {
        guard let session = currentSession else { return }

        session.completedAt = Date()
        currentSession = nil
        currentRound = nil

        try? modelContext.save()
    }

    // MARK: - Round Management

    /// Starts the first round of a session
    private func startFirstRound(for session: TrainingSession) {
        let round = TrainingRound(
            roundNumber: 1,
            targetBaseline: session.startingBaseline
        )

        modelContext.insert(round)
        session.rounds.append(round)
        currentRound = round

        try? modelContext.save()
    }

    /// Completes the current round (does NOT auto-start next round)
    func completeRound() {
        guard let round = currentRound else { return }

        round.completedAt = Date()
        try? modelContext.save()
    }

    /// Starts the next round (alternating baseline) - must be called explicitly
    func startNextRound() {
        guard let session = currentSession,
              let lastRound = currentRound else { return }

        let nextRound = TrainingRound(
            roundNumber: lastRound.roundNumber + 1,
            targetBaseline: lastRound.targetBaseline.opposite
        )

        modelContext.insert(nextRound)
        session.rounds.append(nextRound)
        currentRound = nextRound

        try? modelContext.save()
    }

    /// Checks if the current round is the last round
    var isLastRound: Bool {
        guard let session = currentSession,
              let round = currentRound else { return false }
        return round.roundNumber >= session.configuredRounds
    }

    // MARK: - Throw Management

    /// Records a throw in the current round
    func recordThrow(result: ThrowResult, targetType: TargetType) {
        guard let round = currentRound else { return }

        let throwNumber = round.throwRecords.count + 1
        let throwRecord = ThrowRecord(
            throwNumber: throwNumber,
            result: result,
            targetType: targetType
        )

        modelContext.insert(throwRecord)
        round.throwRecords.append(throwRecord)

        try? modelContext.save()

        // Don't auto-complete - user must explicitly confirm round completion
    }

    /// Undoes the last throw in the current round
    /// Returns true if successful, false if no throw to undo
    @discardableResult
    func undoLastThrow() -> Bool {
        guard let round = currentRound,
              let lastThrow = round.throwRecords.last,
              !round.isComplete else {
            return false
        }

        round.throwRecords.removeLast()
        modelContext.delete(lastThrow)

        try? modelContext.save()

        return true
    }

    // MARK: - 4m Blasting Mode

    /// Starts a 4m blasting session (always 9 rounds)
    @discardableResult
    func startBlastingSession() -> TrainingSession {
        return startSession(
            phase: .fourMetersBlasting,
            sessionType: .blasting,
            rounds: 9
        )
    }

    /// Records a throw with kubbs knocked down (for 4m blasting mode)
    func recordBlastingThrow(kubbsKnockedDown: Int) {
        guard let round = currentRound else { return }

        let throwNumber = round.throwRecords.count + 1
        let throwRecord = ThrowRecord(
            throwNumber: throwNumber,
            result: kubbsKnockedDown > 0 ? .hit : .miss,
            targetType: .baselineKubb
        )
        throwRecord.kubbsKnockedDown = kubbsKnockedDown

        modelContext.insert(throwRecord)
        round.throwRecords.append(throwRecord)

        try? modelContext.save()
    }

    /// Check if blasting round is complete (all kubbs knocked or 6 throws)
    var isBlastingRoundComplete: Bool {
        guard let round = currentRound,
              let session = currentSession,
              session.phase == .fourMetersBlasting else {
            return false
        }
        return round.isBlastingRoundComplete
    }

    /// Get target kubb count for current blasting round
    var targetKubbCount: Int? {
        currentRound?.targetKubbCount
    }

    /// Remaining kubbs in blasting round
    var blastingRemainingKubbs: Int {
        currentRound?.remainingKubbs ?? 0
    }

    #if os(iOS)
    // MARK: - Inkasting Mode

    /// Starts an inkasting training session
    @discardableResult
    func startInkastingSession(sessionType: SessionType, rounds: Int) -> TrainingSession {
        return startSession(
            phase: .inkastingDrilling,
            sessionType: sessionType,
            rounds: rounds
        )
    }

    /// Attaches inkasting analysis to the current round
    func attachInkastingAnalysis(_ analysis: InkastingAnalysis) {
        guard let round = currentRound else { return }

        // NOTE: Cannot set round.inkastingAnalysis due to SwiftData limitation with #if os(iOS)
        // The bidirectional relationship doesn't work with conditional compilation
        // Instead, we only set the one-way relationship: analysis -> round
        analysis.round = round

        modelContext.insert(analysis)
        try? modelContext.save()

        print("✅ Inkasting analysis saved successfully (roundNumber: \(round.roundNumber))")
    }

    /// Check if current round has inkasting data
    var hasInkastingData: Bool {
        currentRound?.hasInkastingData ?? false
    }

    /// Get kubb count for current inkasting session (5 or 10)
    var inkastingKubbCount: Int? {
        guard let session = currentSession,
              session.phase == .inkastingDrilling else { return nil }

        switch session.sessionType {
        case .inkasting5Kubb:
            return 5
        case .inkasting10Kubb:
            return 10
        default:
            return nil
        }
    }
    #endif

    // MARK: - Computed Properties

    /// Whether the user can throw at the king
    var canThrowAtKing: Bool {
        guard let round = currentRound else { return false }
        return round.canThrowAtKing
    }

    /// Number of kubbs remaining in current round
    var kubbsRemaining: Int {
        currentRound?.kubbsRemaining ?? 5
    }

    /// Current throw number (1-6) in the active round
    var currentThrowNumber: Int {
        (currentRound?.throwRecords.count ?? 0) + 1
    }

    /// Whether a session is currently active
    var isSessionActive: Bool {
        currentSession != nil && currentSession?.isComplete == false
    }

    /// Session progress (0.0 to 1.0)
    var sessionProgress: Double {
        currentSession?.progress ?? 0
    }

    /// Session accuracy percentage
    var sessionAccuracy: Double {
        currentSession?.accuracy ?? 0
    }

    // MARK: - Session Cancellation

    /// Cancels the current session and deletes all associated data
    func cancelSession() {
        guard let session = currentSession else { return }

        modelContext.delete(session)
        currentSession = nil
        currentRound = nil

        try? modelContext.save()
    }
}
