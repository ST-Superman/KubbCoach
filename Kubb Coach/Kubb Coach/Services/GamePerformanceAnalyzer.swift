//
//  GamePerformanceAnalyzer.swift
//  Kubb Coach
//
//  Computes per-game field efficiency and estimated 8m hit rate from
//  recorded GameTurn data, and produces a practice recommendation.
//  Also breaks metrics down by game phase (Early / Mid / Late) based on
//  the number of field kubbs in play at the start of each turn.
//

import Foundation

// MARK: - Practice Areas

enum PracticeArea {
    case eightMeter
    case inkasting
    case blasting
    case solidPerformance
    case insufficientData
}

// MARK: - Game Phase

/// Classifies a turn's game-state context by the number of field kubbs the
/// attacker faces at the start of their turn.
///
/// - Early (0–4):  Few or no field kubbs — baseline-heavy, 8m-focused turns.
/// - Mid   (5–7):  Moderate field pressure — common rally state.
/// - Late  (8+):   Heavy field pile-up — requires strong inkasting and blasting.
enum GamePhase: String, CaseIterable, Identifiable {
    case early = "Early"
    case mid   = "Mid"
    case late  = "Late"

    var id: String { rawValue }

    /// Human-readable kubb count range for this phase.
    var fieldKubbRange: String {
        switch self {
        case .early: return "0–4 kubbs"
        case .mid:   return "5–7 kubbs"
        case .late:  return "8+ kubbs"
        }
    }

    /// Classify a turn by the number of field kubbs the attacker faces.
    static func classify(_ fieldKubbs: Int) -> GamePhase {
        switch fieldKubbs {
        case 0...4: return .early
        case 5...7: return .mid
        default:    return .late
        }
    }
}

// MARK: - Phase Metrics

/// Accumulated field-clearing and 8m metrics for a single game phase.
struct GamePhaseMetrics {
    let phase: GamePhase
    let fieldKubbsCleared: Int
    let batonsUsedOnField: Int
    let fieldTurnsWithData: Int
    let eightMeterHits: Int
    let eightMeterAttempts: Int
    /// Total turns analyzed in this phase (including turns without full data).
    let turnCount: Int

    var fieldEfficiency: Double? {
        guard batonsUsedOnField > 0 else { return nil }
        return Double(fieldKubbsCleared) / Double(batonsUsedOnField)
    }

    var eightMeterHitRate: Double? {
        guard eightMeterAttempts > 0 else { return nil }
        return Double(eightMeterHits) / Double(eightMeterAttempts)
    }

    var hasFieldData: Bool { fieldTurnsWithData > 0 }
    var has8mData: Bool    { eightMeterAttempts > 0 }
}

// MARK: - Analysis Result

struct GamePerformanceAnalysis {
    // Field clearing metrics
    let fieldKubbsCleared: Int        // total field kubbs across all turns with data
    let batonsUsedOnField: Int        // total batons spent clearing field kubbs
    let fieldTurnsWithData: Int       // turns where batonsToClearField was recorded
    let fieldTurnsEligible: Int       // turns where field existed, was cleared, and data could have been entered

    var fieldEfficiency: Double? {
        guard batonsUsedOnField > 0 else { return nil }
        return Double(fieldKubbsCleared) / Double(batonsUsedOnField)
    }

    // 8m effectiveness metrics
    let eightMeterHits: Int
    let eightMeterAttempts: Int

    var eightMeterHitRate: Double? {
        guard eightMeterAttempts > 0 else { return nil }
        return Double(eightMeterHits) / Double(eightMeterAttempts)
    }

    // Practice recommendation
    let recommendations: [PracticeArea]

    // Per-phase breakdown (keyed by GamePhase)
    let phaseBreakdown: [GamePhase: GamePhaseMetrics]

    // Data quality helpers
    var isFieldDataComplete: Bool { fieldTurnsWithData == fieldTurnsEligible }
    var hasAnyData: Bool { eightMeterAttempts > 0 || fieldTurnsWithData > 0 }

    /// Convenience accessor — returns nil if the phase had no turns.
    func metrics(for phase: GamePhase) -> GamePhaseMetrics? {
        phaseBreakdown[phase]
    }
}

// MARK: - Analyzer

struct GamePerformanceAnalyzer {

    // Baton count per global turn number.
    // Turn 1 (Team A opening attack): 2 batons
    // Turn 2 (Team B opening attack): 4 batons
    // All subsequent turns: 6 batons
    static func batonCount(forTurnNumber n: Int) -> Int {
        n == 1 ? 2 : n == 2 ? 4 : 6
    }

    /// Analyzes performance for a game session.
    /// - Parameters:
    ///   - session: The game session to analyze.
    ///   - forSide: When specified, analyze only that side's turns. When nil, defaults to
    ///     the user's side in competitive mode or all turns in phantom mode.
    static func analyze(session: GameSession, forSide: GameSide? = nil) -> GamePerformanceAnalysis {
        let sorted = session.sortedTurns

        // Overall accumulators
        var fieldKubbsCleared = 0
        var batonsUsedOnField = 0
        var fieldTurnsWithData = 0
        var fieldTurnsEligible = 0
        var eightMeterHits = 0
        var eightMeterAttempts = 0

        // Per-phase accumulators (private nested struct avoids polluting the outer namespace)
        struct PhaseAcc {
            var fieldKubbsCleared = 0
            var batonsUsedOnField = 0
            var fieldTurnsWithData = 0
            var eightMeterHits = 0
            var eightMeterAttempts = 0
            var turnCount = 0
        }
        var phaseAccum: [GamePhase: PhaseAcc] = [:]

        // Determine which side's turns to include:
        // An explicit forSide overrides the default; otherwise competitive restricts to the user's side.
        let targetSide: GameSide? = forSide ?? (session.gameMode == .competitive ? session.userGameSide : nil)

        for (index, turn) in sorted.enumerated() {
            if let targetSide {
                guard turn.attackingGameSide == targetSide else { continue }
            }

            // Early king turns are exceptional events; skip them.
            guard !turn.wasEarlyKing else { continue }

            // Negative progress means the player failed to clear field kubbs —
            // no useful field or 8m data can be extracted.
            guard turn.progress >= 0 else { continue }

            let attacker = turn.attackingGameSide
            let prev = index > 0 ? sorted[index - 1] : nil

            let fieldBefore: Int
            let defenderBaselineBefore: Int

            if let prev {
                // sideAField = kubbs on Side A's half (Side B must clear)
                // sideBField = kubbs on Side B's half (Side A must clear)
                fieldBefore = (attacker == .sideA) ? prev.sideBFieldAfter : prev.sideAFieldAfter
                defenderBaselineBefore = (attacker == .sideA) ? prev.sideBBaselineAfter : prev.sideABaselineAfter
            } else {
                fieldBefore = 0
                defenderBaselineBefore = 5
            }

            // Classify this turn's game phase by the number of field kubbs the attacker faces.
            let phase = GamePhase.classify(fieldBefore)
            phaseAccum[phase, default: PhaseAcc()].turnCount += 1

            let totalBatons = batonCount(forTurnNumber: turn.turnNumber)
            // Cap baseline hits at the defender's remaining kubbs to handle king-throw turns
            // where progress exceeds the baseline count.
            let baselineHits = min(turn.progress, defenderBaselineBefore)

            if fieldBefore == 0 {
                // Pure 8-meter turn — no field kubbs to clear.
                eightMeterAttempts += totalBatons
                eightMeterHits += baselineHits

                phaseAccum[phase, default: PhaseAcc()].eightMeterAttempts += totalBatons
                phaseAccum[phase, default: PhaseAcc()].eightMeterHits     += baselineHits

            } else if let batons = turn.batonsToClearField {
                // Full data: both field clearing and 8m components are known.
                fieldKubbsCleared += fieldBefore
                batonsUsedOnField += batons
                fieldTurnsWithData += 1
                fieldTurnsEligible += 1

                phaseAccum[phase, default: PhaseAcc()].fieldKubbsCleared  += fieldBefore
                phaseAccum[phase, default: PhaseAcc()].batonsUsedOnField  += batons
                phaseAccum[phase, default: PhaseAcc()].fieldTurnsWithData += 1

                let remainingBatons = max(0, totalBatons - batons)
                eightMeterAttempts += remainingBatons
                eightMeterHits += baselineHits

                phaseAccum[phase, default: PhaseAcc()].eightMeterAttempts += remainingBatons
                phaseAccum[phase, default: PhaseAcc()].eightMeterHits     += baselineHits

            } else {
                // Field kubbs existed and were cleared, but baton count was skipped.
                // Count this turn in the eligible denominator but skip 8m calculation
                // since we can't determine the baton split.
                fieldTurnsEligible += 1
            }
        }

        let recommendations = computeRecommendations(
            fieldEfficiency: batonsUsedOnField > 0 ? Double(fieldKubbsCleared) / Double(batonsUsedOnField) : nil,
            eightMeterHitRate: eightMeterAttempts > 0 ? Double(eightMeterHits) / Double(eightMeterAttempts) : nil,
            hasAnyData: eightMeterAttempts > 0 || fieldTurnsWithData > 0
        )

        // Convert phase accumulators to final value types.
        let phaseBreakdown: [GamePhase: GamePhaseMetrics] = phaseAccum.reduce(into: [:]) { result, kv in
            let (p, acc) = kv
            result[p] = GamePhaseMetrics(
                phase: p,
                fieldKubbsCleared: acc.fieldKubbsCleared,
                batonsUsedOnField: acc.batonsUsedOnField,
                fieldTurnsWithData: acc.fieldTurnsWithData,
                eightMeterHits: acc.eightMeterHits,
                eightMeterAttempts: acc.eightMeterAttempts,
                turnCount: acc.turnCount
            )
        }

        return GamePerformanceAnalysis(
            fieldKubbsCleared: fieldKubbsCleared,
            batonsUsedOnField: batonsUsedOnField,
            fieldTurnsWithData: fieldTurnsWithData,
            fieldTurnsEligible: fieldTurnsEligible,
            eightMeterHits: eightMeterHits,
            eightMeterAttempts: eightMeterAttempts,
            recommendations: recommendations,
            phaseBreakdown: phaseBreakdown
        )
    }

    // MARK: - Private helpers

    private static func computeRecommendations(
        fieldEfficiency: Double?,
        eightMeterHitRate: Double?,
        hasAnyData: Bool
    ) -> [PracticeArea] {
        guard hasAnyData else { return [.insufficientData] }

        // Thresholds
        let fieldGoal = 2.0   // kubbs per baton
        let eightMGoal = 0.40 // 40% hit rate

        let fieldPoor = fieldEfficiency.map { $0 < fieldGoal } ?? false
        let eightMPoor = eightMeterHitRate.map { $0 < eightMGoal } ?? false

        // Both metrics present
        if fieldEfficiency != nil && eightMeterHitRate != nil {
            switch (fieldPoor, eightMPoor) {
            case (true, true):   return [.inkasting, .blasting, .eightMeter]
            case (true, false):  return [.inkasting, .blasting]
            case (false, true):  return [.eightMeter]
            case (false, false): return [.solidPerformance]
            }
        }

        // Only field data available
        if fieldEfficiency != nil {
            return fieldPoor ? [.inkasting, .blasting] : [.solidPerformance]
        }

        // Only 8m data available
        if eightMeterHitRate != nil {
            return eightMPoor ? [.eightMeter] : [.solidPerformance]
        }

        return [.insufficientData]
    }
}
