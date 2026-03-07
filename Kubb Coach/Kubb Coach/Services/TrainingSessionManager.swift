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

        // Tag with device type
        #if os(iOS)
        session.deviceType = "iPhone"
        #elseif os(watchOS)
        session.deviceType = "Watch"
        #endif

        modelContext.insert(session)
        currentSession = session

        // Save this as last used config (iOS only)
        #if os(iOS)
        saveLastConfig(phase: phase, sessionType: sessionType, rounds: rounds)
        #endif

        // Create the first round
        startFirstRound(for: session)

        return session
    }

    #if os(iOS)
    /// Saves the last training configuration for Quick Start
    private func saveLastConfig(phase: TrainingPhase, sessionType: SessionType, rounds: Int) {
        let descriptor = FetchDescriptor<LastTrainingConfig>()
        let existing = try? modelContext.fetch(descriptor).first

        if let config = existing {
            config.phase = phase
            config.sessionType = sessionType
            config.configuredRounds = rounds
            config.lastUsedAt = Date()
        } else {
            let config = LastTrainingConfig(
                phase: phase,
                sessionType: sessionType,
                configuredRounds: rounds
            )
            modelContext.insert(config)
        }

        try? modelContext.save()
    }
    #endif

    /// Completes the current session
    @MainActor
    func completeSession() {
        guard let session = currentSession else { return }

        session.completedAt = Date()

        // Save the session first so it's included in milestone checks
        try? modelContext.save()

        #if os(iOS)
        // Fetch all completed sessions for milestone checks (now includes current session)
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        let sessionItems = allSessions.map { SessionDisplayItem.local($0) }

        // Calculate current streak
        let currentStreak = StreakCalculator.currentStreak(from: sessionItems)

        // Check if user should earn a freeze (every 10 days)
        if StreakCalculator.shouldEarnFreeze(currentStreak: currentStreak) {
            let freezeDescriptor = FetchDescriptor<StreakFreeze>()
            if let existingFreeze = try? modelContext.fetch(freezeDescriptor).first {
                existingFreeze.earnFreeze()
            } else {
                let newFreeze = StreakFreeze(availableFreeze: true, earnedAt: Date())
                modelContext.insert(newFreeze)
            }
        }

        // Check if freeze should be consumed (to prevent streak loss)
        if StreakCalculator.shouldConsumeFreeze(sessions: sessionItems) {
            let freezeDescriptor = FetchDescriptor<StreakFreeze>()
            if let freeze = try? modelContext.fetch(freezeDescriptor).first,
               freeze.availableFreeze {
                freeze.useFreeze()
            }
        }

        // Check for personal bests
        let pbService = PersonalBestService(modelContext: modelContext)
        let newBests = pbService.checkForPersonalBests(session: session)
        session.newPersonalBests = newBests.map { $0.id }

        // Check for milestones
        let milestoneService = MilestoneService(modelContext: modelContext)
        let newMilestones = milestoneService.checkForMilestones(
            session: session,
            allSessions: sessionItems
        )
        session.newMilestones = newMilestones.map { $0.id }

        // Update statistics aggregates
        StatisticsAggregator.updateAggregates(for: session, context: modelContext)

        // Save again with PB and milestone IDs
        try? modelContext.save()
        #endif

        currentSession = nil
        currentRound = nil
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

    /// Completes a round (does NOT auto-start next round)
    /// - Parameter round: The round to complete. If nil, uses currentRound.
    /// Note: Does NOT save - caller should save after all operations are complete
    func completeRound(_ round: TrainingRound? = nil) {
        guard let roundToComplete = round ?? currentRound else { return }
        roundToComplete.completedAt = Date()
    }

    /// Starts the next round (alternating baseline) - must be called explicitly
    /// - Parameters:
    ///   - afterRoundNumber: The round number of the previous round. If nil, uses currentRound.roundNumber.
    ///   - afterBaseline: The baseline of the previous round. If nil, uses currentRound.targetBaseline.
    /// - Returns: The newly created round, or nil if failed
    /// Note: Does NOT save - caller should save after all operations are complete
    @discardableResult
    func startNextRound(afterRoundNumber: Int? = nil, afterBaseline: Baseline? = nil) -> TrainingRound? {
        guard let session = currentSession else { return nil }

        // Use provided values or fall back to currentRound
        let previousRoundNumber: Int
        let previousBaseline: Baseline

        if let roundNum = afterRoundNumber, let baseline = afterBaseline {
            previousRoundNumber = roundNum
            previousBaseline = baseline
        } else {
            guard let lastRound = currentRound else { return nil }
            previousRoundNumber = lastRound.roundNumber
            previousBaseline = lastRound.targetBaseline
        }

        let nextRound = TrainingRound(
            roundNumber: previousRoundNumber + 1,
            targetBaseline: previousBaseline.opposite
        )

        modelContext.insert(nextRound)
        session.rounds.append(nextRound)
        currentRound = nextRound

        return nextRound
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

    /// Attaches inkasting analysis to the specified round
    /// Pass round as parameter to avoid accessing potentially-invalidated currentRound
    /// Note: Does NOT save - caller should save after all operations are complete
    func attachInkastingAnalysis(_ analysis: InkastingAnalysis, to round: TrainingRound) {
        // IMPORTANT: Insert the analysis FIRST before setting relationships
        // Setting relationships on unmanaged objects can cause crashes
        modelContext.insert(analysis)

        // NOTE: Cannot set round.inkastingAnalysis due to SwiftData limitation with #if os(iOS)
        // The bidirectional relationship doesn't work with conditional compilation
        // Instead, we only set the one-way relationship: analysis -> round
        analysis.round = round
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
