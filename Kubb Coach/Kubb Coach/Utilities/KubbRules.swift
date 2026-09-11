// KubbRules.swift
// Swift port of the Kubb Platform client-side rule mirrors (kubb-platform
// `src/lib/kubb-rules.ts`). The server's `submit_turn` remains authoritative —
// these functions only drive INSTANT form feedback (baton counter, disabled
// submit button, inline error) and turn-log text. The ladder order and copy are
// kept verbatim so the app's inline errors read the same as the web client's.
//
// Ported types: `MatchGameState` / `Side` from MatchModels.swift.

import Foundation

/// A turn being composed in the form (TS `TurnDraft`). Mirrors the server's
/// `submit_turn` inputs one-to-one.
struct TurnDraft: Equatable {
    var batonsField: Int = 0
    var batonsBaseline: Int = 0
    var baselineKubbs: Int = 0
    var baseKubbDouble: Bool = false
    var penaltyKubbs: Int = 0
    var fieldKubbsLeft: Int = 0
    var advantageLine: String = "6"
    var kingShots: Int = 0
    var kingHit: Bool = false
    var kingHitEarly: Bool = false
}

extension TurnDraft {
    /// A fresh, empty draft (TS `emptyDraft`).
    static let empty = TurnDraft()
}

/// A `{ value, label }` option for lag / advantage-line pickers.
struct LabeledOption: Identifiable, Hashable {
    let value: String
    let label: String
    var id: String { value }
}

enum KubbRules {

    // MARK: - Labels

    /// Friendly label for an advantage-line value (TS `advLineLabel`).
    static func advLineLabel(_ v: String?) -> String {
        guard let v, !v.isEmpty else { return "" }
        if v == "0.1" || v == ".1" { return "at the King" }
        if v == "13" { return "at the Baseline" }
        return "\(v) ft from the King"
    }

    /// Lag distance options (TS `LAG_OPTIONS`).
    static let lagOptions: [LabeledOption] = {
        var opts: [LabeledOption] = [
            LabeledOption(value: "", label: "Select lag…"),
            LabeledOption(value: "0.1", label: "Touching the King"),
        ]
        for i in 1...24 {
            opts.append(LabeledOption(value: String(i), label: "\(i) inch\(i > 1 ? "es" : "") from the King"))
        }
        opts.append(LabeledOption(value: "98", label: "Not even close"))
        opts.append(LabeledOption(value: "99", label: "Knocked down the King"))
        return opts
    }()

    /// Friendly label for a stored lag value (TS `lagLabel`).
    static func lagLabel(_ v: String?) -> String {
        guard let v, !v.isEmpty else { return "" }
        return lagOptions.first { $0.value == v }?.label ?? v
    }

    /// Advantage-line options (TS `ADV_LINE_OPTIONS`).
    static let advLineOptions: [LabeledOption] = {
        var opts: [LabeledOption] = [LabeledOption(value: "0.1", label: "At the King")]
        for i in 1...12 {
            opts.append(LabeledOption(value: String(i), label: "\(i) ft from the King"))
        }
        opts.append(LabeledOption(value: "13", label: "At the Baseline"))
        return opts
    }()

    // MARK: - Validation

    /// Max legal baseline hits: capped by batons thrown at the baseline + the
    /// opponent's remaining baseline kubbs (a double counts as one). TS
    /// `maxBaselineHits`.
    static func maxBaselineHits(_ s: MatchGameState, _ d: TurnDraft, _ side: Side) -> Int {
        max(0, min(d.batonsBaseline, s.baseline[side.opponent] - (d.baseKubbDouble ? 1 : 0)))
    }

    /// The buildErrors ladder — same order, same copy as the web client. The
    /// first entry blocks submit. TS `buildErrors`.
    static func buildErrors(_ s: MatchGameState, _ d: TurnDraft, _ x: Side) -> [String] {
        let o = x.opponent
        var errs: [String] = []
        let cap = s.roundCap
        let used = d.batonsField + d.batonsBaseline + d.kingShots
        let fieldX = s.field[x]
        let baseO = s.baseline[o]

        if used > cap {
            errs.append("Only \(cap) batons this round — field + baseline + king shots together.")
        }
        if used == 0 && !d.kingHitEarly {
            errs.append("Enter at least one baton.")
        }
        if d.batonsField == 0 && fieldX - d.fieldKubbsLeft > 0 {
            errs.append("Field kubbs went down — record the batons used to clear them.")
        }
        if d.fieldKubbsLeft > 0 &&
            (d.batonsBaseline > 0 ||
             d.baselineKubbs > 0 ||
             d.baseKubbDouble ||
             d.kingShots > 0 ||
             d.kingHit) {
            errs.append("Field kubbs left standing — no baseline or king throws this turn.")
        }
        if d.baseKubbDouble && fieldX == 0 {
            errs.append("A base kubb double needs a field kubb on the board.")
        }
        if d.baselineKubbs > d.batonsBaseline {
            errs.append("Baseline hits cannot exceed batons thrown at the baseline.")
        }
        if d.baselineKubbs + (d.baseKubbDouble ? 1 : 0) > baseO {
            errs.append("Only \(baseO) baseline kubbs remain — the double counts as one of them.")
        }
        if baseO == 0 && d.batonsBaseline > 0 {
            errs.append("No baseline kubbs remain — throws at the king are King Shots.")
        }
        let baseClear = (baseO - d.baselineKubbs - (d.baseKubbDouble ? 1 : 0)) == 0
        if d.kingShots > 0 && !(baseClear && d.fieldKubbsLeft == 0) {
            errs.append("King shots are legal only after all field AND baseline kubbs are down.")
        }
        if d.kingHit && d.kingShots == 0 {
            errs.append("King hit needs at least one king shot.")
        }
        if d.kingHit && d.kingHitEarly {
            errs.append("Pick one — king hit (win) or early king (foul).")
        }
        return errs
    }

    // MARK: - Turn log text

    /// Human-readable turn summary for the log/feed (TS `turnText`). Omits the
    /// felled count (not stored).
    static func turnText(_ t: TurnRow) -> String {
        if t.kingHitEarly { return "Hit the King EARLY — foul, game to the opponent." }
        var parts: [String] = []
        if t.batonsField > 0 || t.fieldKubbsLeft > 0 {
            var f = "\(t.batonsField) baton(s) at the field"
            if t.fieldKubbsLeft > 0 {
                f += " — \(t.fieldKubbsLeft) left standing, Advantage Line \(advLineLabel(t.advantageLine))"
            }
            parts.append(f)
        }
        if t.batonsBaseline > 0 {
            let from = t.throwLine == "advantage" ? "the advantage line" : "8 meters"
            parts.append("\(t.batonsBaseline) baton(s) at the baseline from \(from), hit \(t.baselineKubbs)")
        }
        if t.baseKubbDouble { parts.append("a Base Kubb Double") }
        if t.penaltyKubbs > 0 { parts.append("\(t.penaltyKubbs) Penalty Kubb(s)") }
        if t.kingShots > 0 {
            parts.append("\(t.kingShots) King Shot(s)\(t.kingHit ? " — KING DOWN, game over" : "")")
        }
        return parts.joined(separator: " · ") + "."
    }
}
