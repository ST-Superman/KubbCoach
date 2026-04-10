//
//  GameTrackerService.swift
//  Kubb Coach
//
//  Manages Game Tracker session lifecycle: start, record turn, undo, complete, abandon.
//

import Foundation
import SwiftData
import Observation
import OSLog

private let logger = Logger(subsystem: "com.sathomps.kubbcoach", category: "GameTrackerService")

@Observable
final class GameTrackerService {

    // MARK: - Published state

    /// The active game session, if any.
    var currentSession: GameSession?

    /// Live game state, updated after every recorded turn.
    var currentState: GameState = .initial

    // MARK: - Convenience

    var isGameActive: Bool { currentSession != nil && !(currentSession?.isComplete ?? true) }

    /// Name to display for the current attacker
    func attackerName(for session: GameSession) -> String {
        session.name(for: currentState.currentAttacker)
    }

    // MARK: - Session lifecycle

    /// Start a new game session and reset live state.
    @MainActor
    func startGame(
        mode: GameMode,
        sideAName: String,
        sideBName: String,
        userSide: GameSide?,
        context: ModelContext
    ) {
        let session = GameSession(
            mode: mode,
            sideAName: sideAName,
            sideBName: sideBName,
            userSide: userSide
        )
        context.insert(session)
        do {
            try context.save()
        } catch {
            logger.error("Failed to save new GameSession: \(error)")
        }
        currentSession = session
        currentState = .initial
        logger.info("Started \(mode.rawValue) game: \(session.id)")
    }

    /// Record the progress value for the current turn.
    @MainActor
    func recordTurn(progress: Int, context: ModelContext) {
        guard let session = currentSession, !session.isComplete else { return }

        // Clamp to valid range
        let clamped = max(currentState.minProgress, min(currentState.maxProgress, progress))

        // Capture who is attacking BEFORE applyProgress flips currentAttacker
        let attacker = currentState.currentAttacker
        let kingThrown = clamped > currentState.defenderBaseline
        let turnNum = session.turns.count + 1

        // Apply to live state — this flips currentAttacker and may set isComplete
        currentState.applyProgress(clamped)

        let turn = GameTurn(
            turnNumber: turnNum,
            attackingSide: attacker,
            progress: clamped,
            wasEarlyKing: false,
            kingThrown: kingThrown,
            stateAfter: currentState
        )
        session.turns.append(turn)
        context.insert(turn)

        if currentState.isComplete {
            finishSession(winner: currentState.winner, reason: .kingKnocked, session: session, context: context)
        } else {
            save(context: context)
        }

        logger.info("Recorded turn \(turnNum): progress=\(clamped), attacker=\(attacker.rawValue)")
    }

    /// Record an early-king event. The current attacker's opponent wins.
    @MainActor
    func recordEarlyKing(context: ModelContext) {
        guard let session = currentSession, !session.isComplete else { return }

        let turnNum = session.turns.count + 1
        let attacker = currentState.currentAttacker  // capture before applyEarlyKing

        currentState.applyEarlyKing()

        let turn = GameTurn(
            turnNumber: turnNum,
            attackingSide: attacker,
            progress: 0,
            wasEarlyKing: true,
            kingThrown: true,
            stateAfter: currentState
        )
        session.turns.append(turn)
        context.insert(turn)

        let winnerRaw = currentState.winner?.rawValue ?? "none"
        finishSession(winner: currentState.winner, reason: .earlyKing, session: session, context: context)
        logger.info("Recorded early king — winner: \(winnerRaw)")
    }

    /// Undo the last recorded turn.
    @MainActor
    func undoLastTurn(context: ModelContext) {
        guard let session = currentSession, !session.turns.isEmpty else { return }

        let sorted = session.sortedTurns
        guard let lastTurn = sorted.last else { return }

        session.turns.removeAll { $0.id == lastTurn.id }
        context.delete(lastTurn)

        // Recompute live state by replaying remaining turns
        currentState = GameState.replay(turns: session.turns)

        save(context: context)
        logger.info("Undid turn \(lastTurn.turnNumber)")
    }

    /// Abandon the current game without saving a winner.
    @MainActor
    func abandonGame(context: ModelContext) {
        guard let session = currentSession else { return }
        finishSession(winner: nil, reason: .abandoned, session: session, context: context)
        logger.info("Abandoned game \(session.id)")
    }

    // MARK: - Private helpers

    @MainActor
    private func finishSession(
        winner: GameSide?,
        reason: GameEndReason,
        session: GameSession,
        context: ModelContext
    ) {
        session.winner = winner?.rawValue
        session.endReason = reason.rawValue
        session.completedAt = Date()
        save(context: context)
        currentSession = nil
        currentState = .initial
    }

    private func save(context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("GameTrackerService save failed: \(error)")
        }
    }
}
