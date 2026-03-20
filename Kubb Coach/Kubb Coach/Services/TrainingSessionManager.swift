//
//  TrainingSessionManager.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import Foundation
import SwiftData
import Observation
import OSLog

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

    /// Resumes an existing incomplete session
    /// - Parameter session: The session to resume
    /// - Returns: The resumed session
    func resumeSession(_ session: TrainingSession) -> TrainingSession {
        currentSession = session

        // Find the last incomplete round or create a new one if all are complete
        if let lastRound = session.rounds.last(where: { $0.completedAt == nil }) {
            currentRound = lastRound
        } else {
            // All rounds are complete but session isn't - this shouldn't happen,
            // but handle it by starting a new round if we haven't hit the limit
            if session.rounds.count < session.configuredRounds {
                startNextRound()
            } else {
                // Session is effectively complete, just use the last round
                currentRound = session.rounds.last
            }
        }

        return session
    }

    /// Starts a new training session
    @discardableResult
    func startSession(phase: TrainingPhase, sessionType: SessionType, rounds: Int, isTutorialSession: Bool = false) -> TrainingSession {
        // Validate that inkasting is only on iPhone (requires camera)
        #if os(watchOS)
        if phase == .inkastingDrilling {
            fatalError("Inkasting sessions require a camera and cannot be created on Apple Watch")
        }
        #endif

        let session = TrainingSession(
            phase: phase,
            sessionType: sessionType,
            configuredRounds: rounds,
            startingBaseline: .north,  // Always start at north baseline
            isTutorialSession: isTutorialSession
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

        do {
            try modelContext.save()
        } catch {
            AppLogger.training.error(" Failed to save last config: \(error.localizedDescription)")
        }
    }
    #endif

    /// Completes the current session
    @MainActor
    func completeSession() async {
        guard let session = currentSession else { return }

        // Remove any incomplete/empty rounds before completing the session
        // For 8m/4m sessions: check for throws
        // For Inkasting sessions: check for analysis
        session.rounds.removeAll { round in
            let isIncomplete: Bool
            if session.phase == .inkastingDrilling {
                // Inkasting round is incomplete if it has no analysis and wasn't completed
                isIncomplete = !round.hasInkastingData && round.completedAt == nil
            } else {
                // 8m/4m round is incomplete if it has no throws and wasn't completed
                isIncomplete = round.throwRecords.isEmpty && round.completedAt == nil
            }
            return isIncomplete
        }

        session.completedAt = Date()

        // Save the session first so it's included in milestone checks
        do {
            try modelContext.save()
        } catch {
            AppLogger.training.error(" Failed to save session completion: \(error.localizedDescription)")
            try? modelContext.save()
        }

        #if os(iOS)
        // Fetch all completed real sessions for milestone checks (excludes tutorial sessions)
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil && !$0.isTutorialSession },
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

        // Track daily challenge progress
        DailyChallengeService.shared.trackSessionCompletion(
            session: session,
            context: modelContext
        )

        // Update statistics aggregates
        StatisticsAggregator.updateAggregates(for: session, context: modelContext)

        // Save again with PB and milestone IDs
        do {
            try modelContext.save()
        } catch {
            AppLogger.training.error(" Failed to save session with PB and milestones: \(error.localizedDescription)")
            try? modelContext.save()
        }
        #endif

        #if os(iOS)
        // Evaluate goals (iOS only - goals are managed on iPhone)
        // Watch sessions will have goals evaluated when they sync to iPhone
        do {
            AppLogger.training.info("🎯 Evaluating goals for session: phase=\(session.phase?.rawValue ?? "nil"), type=\(session.sessionType?.rawValue ?? "nil")")
            let goalResults = try await GoalService.shared.evaluateGoals(
                afterSession: session,
                context: modelContext
            )

            AppLogger.training.info("🎯 Goal evaluation complete: \(goalResults.count) goals processed")

            // Log goal progress for debugging
            for result in goalResults {
                AppLogger.training.info("🎯 Goal: \(result.goal.goalTypeEnum.displayName) - Progress: \(result.previousProgress)% → \(result.newProgress)%")
                if result.statusChanged {
                    AppLogger.training.info("🎯 Goal \(result.goal.statusEnum.displayName): +\(result.xpAwarded) XP")
                }
            }
        } catch {
            AppLogger.training.error("❌ Failed to evaluate goals: \(error.localizedDescription)")
        }
        #endif

        // Save after goal evaluation
        do {
            try modelContext.save()
        } catch {
            AppLogger.training.error(" Failed to save after goal evaluation: \(error.localizedDescription)")
            try? modelContext.save()
        }

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

        AppLogger.training.debug(" Creating round - ID before insert: \(String(describing: round.persistentModelID))")
        modelContext.insert(round)
        AppLogger.training.debug(" Round inserted - ID: \(String(describing: round.persistentModelID))")
        session.rounds.append(round)
        currentRound = round

        // Save immediately - this is critical to prevent temporary ID issues
        do {
            try modelContext.save()
            AppLogger.training.debug(" Round saved successfully - ID after save: \(String(describing: round.persistentModelID))")
            AppLogger.training.debug(" Session ID: \(String(describing: session.persistentModelID))")
        } catch {
            AppLogger.training.error(" Failed to save round on start: \(error.localizedDescription)")
            // Try once more
            try? modelContext.save()
        }
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

        do {
            try modelContext.save()
        } catch {
            AppLogger.training.error(" Failed to save throw: \(error.localizedDescription)")
            try? modelContext.save()  // Retry once
        }

        // Don't auto-complete - user must explicitly confirm round completion
    }

    /// Undoes the last throw in the current round
    /// Returns true if successful, false if no throw to undo
    @discardableResult
    func undoLastThrow() -> Bool {
        guard let round = currentRound,
              round.completedAt == nil,
              !round.throwRecords.isEmpty else {
            return false
        }

        // Sort throws by throwNumber to get the actual last throw (SwiftData arrays are unordered)
        let sortedThrows = round.throwRecords.sorted { $0.throwNumber < $1.throwNumber }
        guard let lastThrow = sortedThrows.last else {
            return false
        }

        // Remove the specific throw (not just .removeLast() which could remove the wrong one)
        if let index = round.throwRecords.firstIndex(where: { $0.id == lastThrow.id }) {
            round.throwRecords.remove(at: index)
        }
        modelContext.delete(lastThrow)

        do {
            try modelContext.save()
        } catch {
            AppLogger.training.error(" Failed to save undo: \(error.localizedDescription)")
            try? modelContext.save()  // Retry once
        }

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

        do {
            try modelContext.save()
        } catch {
            AppLogger.training.error(" Failed to save blasting throw: \(error.localizedDescription)")
            try? modelContext.save()  // Retry once
        }
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

        // CRITICAL FIX: Set BOTH sides of the bidirectional relationship
        // SwiftData requires both sides to be set explicitly for proper persistence
        analysis.round = round
        round.inkastingAnalysis = analysis
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

        do {
            try modelContext.save()
        } catch {
            AppLogger.training.error(" Failed to save session cancellation: \(error.localizedDescription)")
            try? modelContext.save()  // Retry once
        }
    }
}
