// BotEngine.swift
// Swift port of the Kubb Platform bot move generator (kubb-platform
// `src/lib/bot-engine.ts`). Pure and dependency-free: given a bot's `BotStats`
// and the live per-game state for the bot's side, it rolls ONE legal turn as a
// `TurnDraft` — the same shape the human turn form produces — which the caller
// validates (KubbRules.buildErrors) and submits via submit_turn. The server's
// validation is authoritative; this aims to be legal by construction.
//
// Fixed strategy, skill-only difficulty: clear my field kubbs → throw remaining
// batons at the opponent baseline → attack the king once the baseline is clear.
// Bots differ only in execution (field efficiency by phase, 8m/king accuracy,
// consistency). Holding an advantage line doubles field efficiency (uncapped)
// and 8m accuracy (capped 0.95).

import Foundation

enum BotEngine {
    // Calibration constants (spread only; the field-efficiency mean is preserved at `e`).
    private static let baseUnder = 0.5   // P(weak toss) at consistency 0
    private static let weakFactor = 0.3  // a weak toss aims at 30% of intended efficiency
    private static let advAccCap = 0.95

    /// Advantage line conceded when the bot can't clear its field (0–5 ft; "0.1" = at the king).
    private static let advLineConcede = ["0.1", "1", "2", "3", "4", "5"]

    /// Per-phase field efficiency for the field kubbs faced this turn.
    static func phaseEff(_ stats: BotStats, _ fieldBefore: Int) -> Double {
        if fieldBefore >= 8 { return stats.fieldEffLate }
        if fieldBefore >= 5 { return stats.fieldEffMid }
        return stats.fieldEffEarly   // 1..4 (never called with 0)
    }

    private static func clamp01(_ x: Double) -> Double { x < 0 ? 0 : (x > 1 ? 1 : x) }

    /// Knuth's Poisson(lambda) draw (lambda small here, ≤ ~6).
    private static func poisson(_ lambda: Double, _ rng: () -> Double) -> Int {
        if lambda <= 0 { return 0 }
        let L = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= rng()
        } while p > L
        return k - 1
    }

    /// Kubbs knocked by ONE field baton, mean = `e`, spread controlled by `consistency`.
    /// Two-Poisson mixture whose blended mean stays exactly `e`; lower consistency fattens
    /// the low tail (streakiness) without capping the high tail.
    static func fieldBatonKnock(_ e: Double, _ consistency: Double, _ rng: () -> Double) -> Int {
        if e <= 0 { return 0 }
        let pUnder = baseUnder * (1 - clamp01(consistency))
        let lambda = rng() < pUnder
            ? e * weakFactor
            : (e * (1 - pUnder * weakFactor)) / (1 - pUnder)
        return poisson(lambda, rng)
    }

    /// Generate one legal turn for `side` given the live game state.
    static func generateBotTurn(
        _ stats: BotStats,
        _ s: MatchGameState,
        _ side: Side,
        rng: () -> Double = { Double.random(in: 0..<1) }
    ) -> TurnDraft {
        let o = side.opponent
        let cap = s.roundCap
        let holdsAdvantage = (s.advantage[side] ?? nil) != nil
        var d = TurnDraft.empty
        d.advantageLine = ""   // engine leaves it empty unless it concedes one below

        // Stage 1: clear my own field kubbs (must go first).
        var field = s.field[side]
        let e = phaseEff(stats, field) * (holdsAdvantage ? 2 : 1)
        var batonsField = 0
        while field > 0 && batonsField < cap {
            field -= min(field, fieldBatonKnock(e, stats.consistency, rng))
            batonsField += 1
        }
        d.batonsField = batonsField
        d.fieldKubbsLeft = field

        if field > 0 {
            // Couldn't clear within the baton cap: concede an advantage line, no baseline/king.
            let idx = min(advLineConcede.count - 1, Int(rng() * Double(advLineConcede.count)))
            d.advantageLine = advLineConcede[idx]
            return d
        }

        // Stage 2: throw remaining batons at the opponent baseline.
        let acc = holdsAdvantage ? min(advAccCap, stats.acc8m * 2) : stats.acc8m
        var batonsLeft = cap - batonsField
        var baseline = s.baseline[o]
        while batonsLeft > 0 && baseline > 0 {
            d.batonsBaseline += 1
            batonsLeft -= 1
            if rng() < acc {
                d.baselineKubbs += 1
                baseline -= 1
            }
        }

        // Stage 3: attack the king (opponent baseline clear + my field clear).
        if baseline == 0 && batonsLeft > 0 {
            while batonsLeft > 0 && !d.kingHit {
                d.kingShots += 1
                batonsLeft -= 1
                if rng() < stats.kingAcc { d.kingHit = true }
            }
        }

        return d
    }
}
