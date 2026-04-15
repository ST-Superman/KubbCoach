//
//  GamePerformanceAnalyzer.swift
//  Kubb Coach
//
//  Computes per-game field efficiency and estimated 8m hit rate from
//  recorded GameTurn data, and produces a practice recommendation.
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

    // Data quality helpers
    var isFieldDataComplete: Bool { fieldTurnsWithData == fieldTurnsEligible }
    var hasAnyData: Bool { eightMeterAttempts > 0 || fieldTurnsWithData > 0 }
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

        var fieldKubbsCleared = 0
        var batonsUsedOnField = 0
        var fieldTurnsWithData = 0
        var fieldTurnsEligible = 0

        var eightMeterHits = 0
        var eightMeterAttempts = 0

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

            let totalBatons = batonCount(forTurnNumber: turn.turnNumber)
            // Cap baseline hits at the defender's remaining kubbs to handle king-throw turns
            // where progress exceeds the baseline count.
            let baselineHits = min(turn.progress, defenderBaselineBefore)

            if fieldBefore == 0 {
                // Pure 8-meter turn — no field kubbs to clear.
                eightMeterAttempts += totalBatons
                eightMeterHits += baselineHits
            } else if let batons = turn.batonsToClearField {
                // Full data: both field clearing and 8m components are known.
                fieldKubbsCleared += fieldBefore
                batonsUsedOnField += batons
                fieldTurnsWithData += 1
                fieldTurnsEligible += 1

                let remainingBatons = max(0, totalBatons - batons)
                eightMeterAttempts += remainingBatons
                eightMeterHits += baselineHits
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

        return GamePerformanceAnalysis(
            fieldKubbsCleared: fieldKubbsCleared,
            batonsUsedOnField: batonsUsedOnField,
            fieldTurnsWithData: fieldTurnsWithData,
            fieldTurnsEligible: fieldTurnsEligible,
            eightMeterHits: eightMeterHits,
            eightMeterAttempts: eightMeterAttempts,
            recommendations: recommendations
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
