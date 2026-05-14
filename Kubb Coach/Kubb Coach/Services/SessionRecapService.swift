// SessionRecapService.swift
// Builds the post-session "Recap Quiet" scenario consumed by SessionRecapView
// and TimelineRecapCard. Resolves the hero stat, delta vs last comparable
// session, the single adaptive habit hook, the coach cue, and a next-session
// nudge. Pure data — no UI imports.

import Foundation
import SwiftData

// MARK: - Scenario types

struct SessionRecapScenario {
    let session: TrainingSession
    let phase: TrainingPhase
    let isPB: Bool
    let isFirstOfPhase: Bool

    /// The big numeral shown in the hero band ("84%", "−2", "0.184").
    let statValue: String
    /// The unit/label under the numeral ("accuracy", "score", "cluster m²").
    let statLabel: String
    /// Optional "+2.2 vs last" line. Nil when no comparison is available
    /// AND it isn't the first-ever session of the phase.
    let deltaText: String?

    let hook: RecapHook
    /// One sentence ≤ 12 words, Fraunces italic voice.
    let cue: String
    let nextNudge: RecapNudge?

    /// Per-round values for the optional round-breakdown viz.
    /// 8m: accuracy 0–100. 4m: signed round score (negative under par).
    /// ink: cluster area m² (lower is better). Empty if not applicable.
    let roundValues: [Double]
}

struct RecapHook {
    enum Kind {
        case pb        // gold trophy
        case restart   // streak resumed after a break
        case first     // first session of this phase ever
        case recovery  // off-day, well below recent form
        case steady    // default — quiet acknowledgement
    }

    let kind: Kind
    /// Mono kicker shown above the line ("NEW PERSONAL BEST", "BACK AT IT").
    let kicker: String
    /// One-sentence line under the kicker.
    let line: String
}

struct RecapNudge {
    let phase: TrainingPhase
    let reason: String
}

// MARK: - Builder

enum SessionRecapService {
    static func scenario(for session: TrainingSession, context: ModelContext) -> SessionRecapScenario {
        let phase = session.phase ?? .eightMeters

        let prior = SessionComparisonService.findLastSession(matching: session, context: context)
        let comparison = prior.flatMap {
            SessionComparisonService.getComparison(current: session, previous: $0, context: context)
        }
        let isFirst = (prior == nil)
        let isPB = !session.newPersonalBests.isEmpty

        let daysSinceLast: Int = {
            guard let prior = prior, let priorCompleted = prior.completedAt else { return .max }
            let anchor = session.completedAt ?? Date()
            return Calendar.current.dateComponents([.day], from: priorCompleted, to: anchor).day ?? 0
        }()

        let hook = resolveHook(
            phase: phase,
            isPB: isPB,
            isFirst: isFirst,
            daysSinceLast: daysSinceLast,
            comparison: comparison
        )

        let (statValue, statLabel) = heroStat(for: session, phase: phase, context: context)

        let deltaText: String? = {
            if let c = comparison { return formatDelta(c, phase: phase) }
            if isFirst { return "First time tracked" }
            return nil
        }()

        return SessionRecapScenario(
            session: session,
            phase: phase,
            isPB: isPB,
            isFirstOfPhase: isFirst,
            statValue: statValue,
            statLabel: statLabel,
            deltaText: deltaText,
            hook: hook,
            cue: pickCue(phase: phase, kind: hook.kind),
            nextNudge: pickNextNudge(currentPhase: phase, context: context),
            roundValues: roundSpark(for: session, phase: phase, context: context)
        )
    }

    // MARK: Hook resolution
    // Priority: restart (streak break) > PB > first-of-phase > recovery (off day) > steady.

    private static func resolveHook(
        phase: TrainingPhase,
        isPB: Bool,
        isFirst: Bool,
        daysSinceLast: Int,
        comparison: ComparisonResult?
    ) -> RecapHook {
        if !isFirst, daysSinceLast >= 3 {
            return RecapHook(
                kind: .restart,
                kicker: "BACK AT IT",
                line: daysSinceLast >= 14
                    ? "\(daysSinceLast) days off. Muscle memory still landing close to form."
                    : "\(daysSinceLast) days off. Two more this week and the streak resets clean."
            )
        }
        if isPB {
            return RecapHook(
                kind: .pb,
                kicker: "NEW PERSONAL BEST",
                line: "Best result you've logged in \(phase.shortName). Note what felt different while it's fresh."
            )
        }
        if isFirst {
            return RecapHook(
                kind: .first,
                kicker: "FIRST \(phase.shortName.uppercased()) LOG",
                line: "This is your baseline. Every \(phase.shortName) session from here gets compared to today."
            )
        }
        if let c = comparison, !c.isImprovement, abs(c.percentChange) >= 10 {
            return RecapHook(
                kind: .recovery,
                kicker: "OFF DAY",
                line: "Below your average. Wind, grip, or head — pick one to note."
            )
        }
        return RecapHook(
            kind: .steady,
            kicker: "STEADY",
            line: "Reps are the work. Log it and move on."
        )
    }

    // MARK: Hero stat per phase

    private static func heroStat(
        for session: TrainingSession,
        phase: TrainingPhase,
        context: ModelContext
    ) -> (value: String, label: String) {
        switch phase {
        case .eightMeters:
            return (String(format: "%.0f%%", session.accuracy), "accuracy")
        case .fourMetersBlasting:
            if let score = session.totalSessionScore {
                let signed = score > 0 ? "+\(score)" : "\(score)"
                return (signed, "vs par")
            }
            return ("—", "score")
        case .inkastingDrilling:
            if let area = session.averageClusterArea(context: context) {
                return (String(format: "%.3f", area), "m² cluster")
            }
            return ("—", "cluster")
        case .gameTracker, .pressureCooker:
            return (String(format: "%.0f%%", session.accuracy), "result")
        }
    }

    // MARK: Delta formatter

    private static func formatDelta(_ c: ComparisonResult, phase: TrainingPhase) -> String {
        switch phase {
        case .eightMeters:
            let sign = c.delta >= 0 ? "+" : "−"
            return String(format: "%@%.1f vs last", sign, abs(c.delta))
        case .fourMetersBlasting:
            // Score: lower is better. Show signed integer delta.
            let sign = c.delta >= 0 ? "+" : "−"
            return String(format: "%@%.0f vs last", sign, abs(c.delta))
        case .inkastingDrilling:
            // Cluster area: percent-change reads cleaner than raw m².
            let sign = c.percentChange >= 0 ? "+" : "−"
            return String(format: "%@%.0f%% vs last", sign, abs(c.percentChange))
        case .gameTracker, .pressureCooker:
            return c.deltaString + " vs last"
        }
    }

    // MARK: Coach cue picker — small bank per (phase, hook kind)

    private static func pickCue(phase: TrainingPhase, kind: RecapHook.Kind) -> String {
        switch (phase, kind) {
        case (.eightMeters, .pb):       return "That's the form. Lock the elbow next time too."
        case (.eightMeters, .restart):  return "Welcome back. Same release, same arc as before."
        case (.eightMeters, .first):    return "This is your baseline. Same throw every round from here."
        case (.eightMeters, .recovery): return "Bad days log too. Note what felt wrong while it's fresh."
        case (.eightMeters, .steady):   return "Steady reps. Same elbow, same release."

        case (.fourMetersBlasting, .pb):       return "Clean clearing. Hold this rhythm next session."
        case (.fourMetersBlasting, .restart):  return "Welcome back. Mix in blasting again this week."
        case (.fourMetersBlasting, .first):    return "Under par means under six per row. That's the bar."
        case (.fourMetersBlasting, .recovery): return "Batons in hand matter more than score. Reset tomorrow."
        case (.fourMetersBlasting, .steady):   return "Count the batons. Score follows."

        case (.inkastingDrilling, .pb):       return "Tight cluster, locked release. Repeat the setup tomorrow."
        case (.inkastingDrilling, .restart):  return "Get the elbow back today. Five minutes is enough."
        case (.inkastingDrilling, .first):    return "This is your baseline. Aim small, miss small."
        case (.inkastingDrilling, .recovery): return "One outlier is wind. Three is form. Note which."
        case (.inkastingDrilling, .steady):   return "Same target every throw. Cluster follows."

        case (.gameTracker, _), (.pressureCooker, _):
            return "Logged. Note what carried over for next time."
        }
    }

    // MARK: Next-session nudge — pick the training phase with the longest gap

    private static func pickNextNudge(currentPhase: TrainingPhase, context: ModelContext) -> RecapNudge? {
        let candidates: [TrainingPhase] = [.eightMeters, .fourMetersBlasting, .inkastingDrilling]
            .filter { $0 != currentPhase }

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        let recent = (try? context.fetch(descriptor)) ?? []

        var nudge: (phase: TrainingPhase, gap: Int)? = nil
        for phase in candidates {
            let last = recent.first(where: { $0.phase == phase })
            let gap: Int
            if let completed = last?.completedAt {
                gap = Calendar.current.dateComponents([.day], from: completed, to: Date()).day ?? 0
            } else {
                gap = Int.max  // never tracked → highest priority nudge
            }
            if nudge == nil || gap > nudge!.gap {
                nudge = (phase, gap)
            }
        }

        guard let pick = nudge else { return nil }
        // Don't nudge if every other phase was practiced within 2 days.
        guard pick.gap >= 3 else { return nil }

        let reason: String
        if pick.gap == .max {
            reason = "You haven't tried \(pick.phase.shortName) yet."
        } else if pick.gap >= 14 {
            reason = "It's been \(pick.gap) days since your last \(pick.phase.shortName)."
        } else {
            reason = "You haven't \(pick.phase.verbForm) in \(pick.gap) days."
        }
        return RecapNudge(phase: pick.phase, reason: reason)
    }

    // MARK: Round-by-round spark values

    private static func roundSpark(
        for session: TrainingSession,
        phase: TrainingPhase,
        context: ModelContext
    ) -> [Double] {
        let rounds = session.rounds.sorted { $0.roundNumber < $1.roundNumber }
        switch phase {
        case .eightMeters:
            return rounds.map { $0.accuracy }
        case .fourMetersBlasting:
            return rounds.map { Double($0.score) }
        case .inkastingDrilling:
            #if os(iOS)
            let analyses = session.fetchInkastingAnalyses(context: context)
                .sorted { $0.timestamp < $1.timestamp }
            return analyses.map { $0.clusterAreaSquareMeters }
            #else
            return []
            #endif
        case .gameTracker, .pressureCooker:
            return []
        }
    }
}

// MARK: - TrainingPhase recap helpers

private extension TrainingPhase {
    /// Short name used in recap copy ("8m", "4m", "ink").
    var shortName: String {
        switch self {
        case .eightMeters:        return "8m"
        case .fourMetersBlasting: return "4m"
        case .inkastingDrilling:  return "ink"
        case .gameTracker:        return "game"
        case .pressureCooker:     return "pc"
        }
    }

    /// Verb used in nudge sentences ("trained 8m", "blasted", "drilled inkast").
    var verbForm: String {
        switch self {
        case .eightMeters:        return "trained 8m"
        case .fourMetersBlasting: return "blasted"
        case .inkastingDrilling:  return "drilled inkast"
        case .gameTracker:        return "tracked a game"
        case .pressureCooker:     return "run a Pressure Cooker"
        }
    }
}
