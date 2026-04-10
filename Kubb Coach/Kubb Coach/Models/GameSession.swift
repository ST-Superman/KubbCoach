//
//  GameSession.swift
//  Kubb Coach
//
//  Data models and game state logic for the Game Tracker feature.
//

import Foundation
import SwiftData

// MARK: - GameSession

/// Root model for a tracked game (Phantom or Competitive).
@Model
final class GameSession {
    var id: UUID
    var createdAt: Date
    var completedAt: Date?
    var mode: String                // GameMode raw value
    var sideAName: String
    var sideBName: String
    var userSide: String?           // GameSide raw value; nil for phantom (user plays both)
    @Relationship(deleteRule: .cascade) var turns: [GameTurn]
    var winner: String?             // GameSide raw value; nil if abandoned
    var endReason: String?          // GameEndReason raw value

    init(
        mode: GameMode,
        sideAName: String = "Side A",
        sideBName: String = "Side B",
        userSide: GameSide? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.completedAt = nil
        self.mode = mode.rawValue
        self.sideAName = sideAName
        self.sideBName = sideBName
        self.userSide = userSide?.rawValue
        self.turns = []
        self.winner = nil
        self.endReason = nil
    }

    // MARK: - Typed accessors

    var gameMode: GameMode {
        GameMode(rawValue: mode) ?? .phantom
    }

    var winnerSide: GameSide? {
        winner.flatMap { GameSide(rawValue: $0) }
    }

    var userGameSide: GameSide? {
        userSide.flatMap { GameSide(rawValue: $0) }
    }

    var isComplete: Bool {
        completedAt != nil
    }

    /// Name to display for a given side
    func name(for side: GameSide) -> String {
        side == .sideA ? sideAName : sideBName
    }

    // MARK: - Turn helpers (ordered)

    var sortedTurns: [GameTurn] {
        turns.sorted { $0.turnNumber < $1.turnNumber }
    }

    /// Turns belonging to the user's side (all turns for phantom)
    var userTurns: [GameTurn] {
        guard let userSide = userGameSide else { return sortedTurns }
        return sortedTurns.filter { $0.attackingGameSide == userSide }
    }

    // MARK: - Summary stats

    var totalTurns: Int { turns.count }

    /// Average progress per turn for the user's side (phantom = all turns)
    var averageUserProgress: Double {
        let t = userTurns
        guard !t.isEmpty else { return 0 }
        return Double(t.map(\.progress).reduce(0, +)) / Double(t.count)
    }

    var bestUserTurn: GameTurn? {
        userTurns.max { $0.progress < $1.progress }
    }

    var worstUserTurn: GameTurn? {
        userTurns.min { $0.progress < $1.progress }
    }

    /// Turns where attacker failed to clear field kubbs (negative progress)
    var advantageLineTurns: [GameTurn] {
        userTurns.filter { $0.progress < 0 }
    }

    /// Turns where attacker cleared all baselines (could have thrown at king)
    /// Progress equals defender's remaining baseline before the turn would be: we store turn data
    /// A king opportunity = the turn that ended the game (progress > defenderBaseline before turn)
    /// OR turns where all baselines were cleared (positive progress reaching max without king)
    /// We approximate: turns with progress > 0 where the king was reachable
    var kingOpportunityTurns: [GameTurn] {
        userTurns.filter { $0.kingThrown }
    }

    var userWon: Bool? {
        guard let winner = winnerSide else { return nil }
        if gameMode == .phantom { return true }  // phantom: user always "wins" in a sense
        return winner == userGameSide
    }
}

// MARK: - GameTurn

/// A single side's turn within a game session.
@Model
final class GameTurn {
    var id: UUID
    var turnNumber: Int
    var attackingSide: String       // GameSide raw value
    var progress: Int               // negative = field fail, positive = baseline + king
    var wasEarlyKing: Bool          // king knocked illegally (opponent wins)
    var kingThrown: Bool            // true if all baselines cleared and king thrown (win attempt)
    var timestamp: Date
    // State snapshot AFTER this turn (avoids full replay for display)
    var sideABaselineAfter: Int
    var sideBBaselineAfter: Int
    var sideAFieldAfter: Int
    var sideBFieldAfter: Int
    var sideAHasAdvantageAfter: Bool
    var sideBHasAdvantageAfter: Bool
    var session: GameSession?

    init(
        turnNumber: Int,
        attackingSide: GameSide,
        progress: Int,
        wasEarlyKing: Bool = false,
        kingThrown: Bool = false,
        stateAfter: GameState
    ) {
        self.id = UUID()
        self.turnNumber = turnNumber
        self.attackingSide = attackingSide.rawValue
        self.progress = progress
        self.wasEarlyKing = wasEarlyKing
        self.kingThrown = kingThrown
        self.timestamp = Date()
        self.sideABaselineAfter = stateAfter.sideABaseline
        self.sideBBaselineAfter = stateAfter.sideBBaseline
        self.sideAFieldAfter = stateAfter.sideAField
        self.sideBFieldAfter = stateAfter.sideBField
        self.sideAHasAdvantageAfter = stateAfter.sideAHasAdvantage
        self.sideBHasAdvantageAfter = stateAfter.sideBHasAdvantage
    }

    var attackingGameSide: GameSide {
        GameSide(rawValue: attackingSide) ?? .sideA
    }
}

// MARK: - GameState

/// Pure value type representing the live state of a game.
/// Not stored — computed from scratch at game start and updated in memory each turn.
struct GameState {
    var sideABaseline: Int = 5
    var sideBBaseline: Int = 5
    var sideAField: Int = 0         // field kubbs on Side A's half (Side B clears these)
    var sideBField: Int = 0         // field kubbs on Side B's half (Side A clears these)
    var sideAHasAdvantage: Bool = false  // Side A has uncleaned field kubbs → Side A throws from advantage line
    var sideBHasAdvantage: Bool = false
    var currentAttacker: GameSide = .sideA
    var isComplete: Bool = false
    var winner: GameSide? = nil

    static let initial = GameState()

    // MARK: - Derived state

    /// Field kubbs on the defender's half (the attacker must clear these)
    var defenderField: Int {
        currentAttacker == .sideA ? sideBField : sideAField
    }

    /// Baseline kubbs remaining for the defender
    var defenderBaseline: Int {
        currentAttacker == .sideA ? sideBBaseline : sideABaseline
    }

    /// Minimum valid progress value for the current turn.
    /// Zero if no field kubbs to clear; otherwise negative up to -defenderField.
    var minProgress: Int {
        defenderField > 0 ? -defenderField : 0
    }

    /// Maximum valid progress value.
    /// defenderBaseline + 1 accounts for knocking the King after clearing all baselines.
    var maxProgress: Int {
        defenderBaseline + 1
    }

    /// True if this progress value implies the King was knocked (game-winning turn)
    func wouldKnockKing(_ p: Int) -> Bool {
        p > 0 && p > defenderBaseline
    }

    /// Total kubbs in play invariant check (should always equal 10)
    var totalKubbs: Int {
        sideABaseline + sideBBaseline + sideAField + sideBField
    }

    // MARK: - State transitions

    /// Apply a recorded progress value for the current attacker.
    /// Returns whether the king was thrown (game-over trigger).
    @discardableResult
    mutating func applyProgress(_ p: Int) -> Bool {
        guard !isComplete else { return false }

        let kingKnocked = wouldKnockKing(p)

        if p >= 0 {
            // Cleared all defender field kubbs → they move to attacker's field.
            // Knocked baseline kubbs also move to attacker's field (defender inkasts them).
            let baselineHits = min(p, defenderBaseline)

            if currentAttacker == .sideA {
                sideAField += sideBField + baselineHits
                sideBField = 0
                sideBBaseline -= baselineHits
                sideBHasAdvantage = false   // advantage expired: attacker cleared defender's field
            } else {
                sideBField += sideAField + baselineHits
                sideAField = 0
                sideABaseline -= baselineHits
                sideAHasAdvantage = false
            }

            if kingKnocked {
                isComplete = true
                winner = currentAttacker
            }
        } else {
            // Negative: attacker failed to clear |p| field kubbs on defender's half.
            let uncleaned = abs(p)
            let cleared = defenderField - uncleaned

            if currentAttacker == .sideA {
                sideAField += cleared       // cleared kubbs move to attacker's field
                sideBField = uncleaned      // uncleaned remain on defender's half
                sideBHasAdvantage = true    // Side B benefits: shorter throw distance next attack
            } else {
                sideBField += cleared
                sideAField = uncleaned
                sideAHasAdvantage = true
            }
        }

        if !isComplete {
            currentAttacker = currentAttacker.opposite
        }

        return kingKnocked
    }

    /// Record an early-king event. The OPPONENT of the current attacker wins.
    mutating func applyEarlyKing() {
        isComplete = true
        winner = currentAttacker.opposite
    }

    // MARK: - Replay

    /// Rebuild state by replaying a sequence of completed turns from scratch.
    static func replay(turns: [GameTurn]) -> GameState {
        var state = GameState.initial
        for turn in turns.sorted(by: { $0.turnNumber < $1.turnNumber }) {
            if turn.wasEarlyKing {
                state.applyEarlyKing()
            } else {
                state.applyProgress(turn.progress)
            }
        }
        return state
    }
}
