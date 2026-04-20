// PhaseAnalysisView.swift
// Kubbly Stats · Phase Analysis screen
// Entry: tap a phase row on Journey. Exit: back chevron.

import SwiftUI
import SwiftData
import Charts

// MARK: – Data models

struct PAHeroData {
    let bigStat: String
    let unit: String
    let statLabel: String
    let delta: String
    let pb: String
    let pbDate: String
    let streak: Int
    let subtitle: String
}

struct KubbHitRate: Identifiable {
    let id = UUID()
    let label: String
    let rate: Int
    let throwCount: Int
}

struct InkastingThrow: Identifiable {
    let id = UUID()
    let xRel: Double    // relative offset from cluster center (normalized coords, can be negative)
    let yRel: Double
    let isOutlier: Bool
}

struct RoundAvgScore: Identifiable {
    let id = UUID()
    let roundNumber: Int
    let kubbCount: Int
    let avgScore: Double   // golf-style: negative = under par (good), positive = over par (bad)
    let sampleCount: Int
}

struct PCModeData {
    let gameType: PressureCookerGameType
    let sessionCount: Int
    let trend: [Double]
}

enum PAVizData {
    case eightMeter(kubbs: [KubbHitRate])
    case fourMeter(rounds: [RoundAvgScore])
    case inkasting(throwPoints: [InkastingThrow], targetRadiusNorm: Double, targetRadiusLabel: String, outlierCount: Int)
    case pressureCooker(modes: [PCModeData])
}

struct CoachingInsight: Identifiable {
    let id = UUID()
    let kind: InsightKind
    let title: String
    let body: String
    let accent: Color

    enum InsightKind: String {
        case trend, strength, warning, suggestion, insight

        var symbol: String {
            switch self {
            case .trend:      return "arrow.up.right"
            case .strength:   return "star.fill"
            case .warning:    return "exclamationmark.triangle.fill"
            case .suggestion: return "arrow.right.circle.fill"
            case .insight:    return "lightbulb.fill"
            }
        }
    }
}

struct PhaseAnalysisData {
    let hero: PAHeroData
    let vizData: PAVizData
    let trend: [Double]
    let priorTrend: [Double]
    let insights: [CoachingInsight]

    static func mock(for phase: KubbPhase) -> PhaseAnalysisData {
        switch phase {
        case .eightMeter:
            return PhaseAnalysisData(
                hero: PAHeroData(bigStat: "82.1", unit: "%", statLabel: "AVG ACCURACY · 30D",
                                 delta: "+3.2%", pb: "88%", pbDate: "Mar 13", streak: 4,
                                 subtitle: "ACCURACY SHOOTING · 8M THROWS"),
                vizData: .eightMeter(kubbs: [
                    KubbHitRate(label: "K1", rate: 78, throwCount: 62),
                    KubbHitRate(label: "K2", rate: 91, throwCount: 58),
                    KubbHitRate(label: "K3", rate: 86, throwCount: 55),
                    KubbHitRate(label: "K4", rate: 83, throwCount: 60),
                    KubbHitRate(label: "K5", rate: 72, throwCount: 54),
                    KubbHitRate(label: "King", rate: 38, throwCount: 21),
                ]),
                trend:      [68,72,70,74,76,72,78,80,76,82,78,80,82,84,82,85,82,86,84,82],
                priorTrend: [65,68,66,70,70,68,72,74,70,74,72,76,74,78,76,78,78,80,78,80],
                insights: [
                    CoachingInsight(kind: .trend, title: "Warm-up rounds are limiting you",
                        body: "Your first 3 rounds average 71%; rounds 6–10 average 88%. Try 2 practice throws before starting.",
                        accent: Color.Kubb.swedishBlue),
                    CoachingInsight(kind: .strength, title: "Left-side targets are your strong side",
                        body: "You hit 91% on K2 vs 72% on K5. Drill the later kubbs next session.",
                        accent: Color.Kubb.forestGreen),
                    CoachingInsight(kind: .suggestion, title: "Ready for an 85% target",
                        body: "You've been within 2–3% for four sessions. Set a session goal of 85%+ to push through.",
                        accent: Color.Kubb.swedishGold),
                ]
            )

        case .fourMeter:
            return PhaseAnalysisData(
                hero: PAHeroData(bigStat: "−3.4", unit: "", statLabel: "AVG SCORE VS PAR · 30D",
                                 delta: "−0.8", pb: "−6", pbDate: "Today", streak: 3,
                                 subtitle: "PAR SCORE · 4M CLEARS"),
                vizData: .fourMeter(rounds: [
                    RoundAvgScore(roundNumber: 1, kubbCount: 2, avgScore: -1.2, sampleCount: 20),
                    RoundAvgScore(roundNumber: 2, kubbCount: 3, avgScore: -0.8, sampleCount: 20),
                    RoundAvgScore(roundNumber: 3, kubbCount: 4, avgScore: -0.4, sampleCount: 19),
                    RoundAvgScore(roundNumber: 4, kubbCount: 5, avgScore:  0.2, sampleCount: 19),
                    RoundAvgScore(roundNumber: 5, kubbCount: 6, avgScore:  0.8, sampleCount: 18),
                    RoundAvgScore(roundNumber: 6, kubbCount: 7, avgScore:  1.4, sampleCount: 17),
                    RoundAvgScore(roundNumber: 7, kubbCount: 8, avgScore:  2.1, sampleCount: 15),
                    RoundAvgScore(roundNumber: 8, kubbCount: 9, avgScore:  2.8, sampleCount: 12),
                    RoundAvgScore(roundNumber: 9, kubbCount: 10, avgScore: 3.5, sampleCount: 10),
                ]),
                trend:      [0.5,0,-0.5,-1,-0.8,-1.5,-2,-2.2,-2.5,-3,-2.8,-3.2,-3,-3.4,-3,-3.5,-3.2,-3.6,-3.4,-3.8],
                priorTrend: [1,0.8,0.5,0.2,0,-0.3,-0.5,-0.2,-0.8,-1,-0.8,-1.2,-1,-1.5,-1.2,-1.8,-1.5,-2,-1.8,-2.2],
                insights: [
                    CoachingInsight(kind: .trend, title: "Rounds 6–9 are where you bleed strokes",
                        body: "You're under par through R5, then over par for the heavy rounds. Drill 7–10 kubb sets.",
                        accent: Color.Kubb.phase4m),
                    CoachingInsight(kind: .warning, title: "Watch your 9th round",
                        body: "R9 (10 kubbs) costs you 3.5 strokes on average. Fatigue or focus?",
                        accent: Color(hex: 0xC53030)),
                    CoachingInsight(kind: .strength, title: "Clearing 2–3 kubbs feels automatic",
                        body: "Rounds 1–2 are consistently under par. You own the short sets.",
                        accent: Color.Kubb.forestGreen),
                ]
            )

        case .inkasting:
            return PhaseAnalysisData(
                hero: PAHeroData(bigStat: "0.45", unit: "m", statLabel: "AVG CLUSTER RADIUS · 30D",
                                 delta: "−0.08m", pb: "0.28m", pbDate: "Apr 2", streak: 2,
                                 subtitle: "THROW CLUSTERING · FIELD PLACEMENT"),
                vizData: .inkasting(
                    throwPoints: [
                        InkastingThrow(xRel:  0.000, yRel:  0.000, isOutlier: false),
                        InkastingThrow(xRel:  0.018, yRel:  0.012, isOutlier: false),
                        InkastingThrow(xRel: -0.015, yRel: -0.010, isOutlier: false),
                        InkastingThrow(xRel:  0.022, yRel: -0.008, isOutlier: false),
                        InkastingThrow(xRel: -0.008, yRel:  0.020, isOutlier: false),
                        InkastingThrow(xRel:  0.010, yRel:  0.018, isOutlier: false),
                        InkastingThrow(xRel: -0.020, yRel:  0.005, isOutlier: false),
                        InkastingThrow(xRel:  0.005, yRel: -0.022, isOutlier: false),
                        InkastingThrow(xRel:  0.012, yRel: -0.015, isOutlier: false),
                        InkastingThrow(xRel: -0.010, yRel: -0.018, isOutlier: false),
                        InkastingThrow(xRel: -0.025, yRel:  0.030, isOutlier: false),
                        InkastingThrow(xRel:  0.028, yRel: -0.025, isOutlier: false),
                        InkastingThrow(xRel:  0.095, yRel:  0.060, isOutlier: true),
                        InkastingThrow(xRel: -0.085, yRel: -0.070, isOutlier: true),
                    ],
                    targetRadiusNorm: 0.040,
                    targetRadiusLabel: "0.45m",
                    outlierCount: 2
                ),
                trend:      [5.2,5.0,4.8,4.5,4.6,4.2,4.0,4.3,3.9,3.7,3.8,3.6,3.4,3.5,3.3,3.4,3.2,3.4,3.3,3.2],
                priorTrend: [5.8,5.5,5.4,5.2,5.3,5.0,4.8,5.0,4.6,4.4,4.5,4.3,4.1,4.2,4.0,4.1,3.9,4.1,4.0,3.9],
                insights: [
                    CoachingInsight(kind: .trend, title: "Cluster tightening rapidly",
                        body: "Down 0.08m radius over the last 30 days — fastest improvement of any phase.",
                        accent: Color.Kubb.forestGreen),
                    CoachingInsight(kind: .strength, title: "Center of mass is on-target",
                        body: "Your cluster center sits within competitive range of the king line.",
                        accent: Color.Kubb.swedishBlue),
                    CoachingInsight(kind: .suggestion, title: "Try the 8-throw tight drill",
                        body: "Skip outliers. Focus only on your first 8 throws feeling tight.",
                        accent: Color.Kubb.swedishGold),
                ]
            )

        case .pressureCooker:
            return PhaseAnalysisData(
                hero: PAHeroData(bigStat: "8", unit: "/10", statLabel: "3-4-3 BEST · LAST WEEK",
                                 delta: "+1", pb: "9", pbDate: "Mar 27", streak: 5,
                                 subtitle: "PRESSURE COOKER · MINI-GAMES"),
                vizData: .pressureCooker(modes: [
                    PCModeData(gameType: .threeForThree, sessionCount: 12,
                               trend: [60,62,65,68,70,72,75,74,78,80,79,82]),
                    PCModeData(gameType: .inTheRed, sessionCount: 6,
                               trend: [1, 2, 1, 3, 2, 4]),
                ]),
                trend:      [4,5,5,6,5,7,6,8,7,8,7,8,8,9,8,8,9,8,8,8],
                priorTrend: [3,3,4,4,5,4,5,6,5,6,5,7,6,7,6,7,7,7,6,7],
                insights: [
                    CoachingInsight(kind: .trend, title: "Consistent in the 7-9 zone",
                        body: "Every session for 2 weeks has cleared at least 7/10. Your floor is rising.",
                        accent: Color.Kubb.phasePC),
                    CoachingInsight(kind: .warning, title: "Round 4 is your bottleneck",
                        body: "The 4-kubb round is where you miss 62% of your dropped points.",
                        accent: Color.Kubb.phase4m),
                    CoachingInsight(kind: .suggestion, title: "Ready for timed pressure",
                        body: "Try 3-4-3 with a 90-second round cap.",
                        accent: Color.Kubb.swedishGold),
                ]
            )
        }
    }
}

// MARK: – Main view

struct PhaseAnalysisView: View {
    let phase: KubbPhase
    @AppStorage("compareMode") private var compareMode = false
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<TrainingSession> { $0.completedAt != nil && !$0.isTutorialSession },
        sort: \TrainingSession.createdAt, order: .reverse
    ) private var allSessions: [TrainingSession]

    @Query(
        filter: #Predicate<PressureCookerSession> { $0.completedAt != nil },
        sort: \PressureCookerSession.createdAt, order: .reverse
    ) private var pcSessions: [PressureCookerSession]

    private var phaseSessions: [TrainingSession] {
        let tp = phase.trainingPhase
        return allSessions.filter { ($0.phase ?? .eightMeters) == tp }
    }

    private var data: PhaseAnalysisData {
        switch phase {
        case .pressureCooker:
            return pcSessions.isEmpty
                ? PhaseAnalysisData.mock(for: phase)
                : PhaseAnalysisData.computePC(from: pcSessions)
        default:
            return phaseSessions.isEmpty
                ? PhaseAnalysisData.mock(for: phase)
                : PhaseAnalysisData.compute(from: phaseSessions, phase: phase)
        }
    }

    private var phaseColor: Color { Color.Kubb.phase(phase) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.Kubb.paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Gradient zone: header + hero
                    VStack(spacing: 0) {
                        PAPhaseHeader(phase: phase, compareMode: $compareMode, onBack: { dismiss() })
                        PAHeroBlock(phase: phase, data: data.hero)
                    }
                    .background(
                        LinearGradient(
                            colors: [phaseColor, phaseColor.shaded(by: -0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    // Body: paper bg
                    VStack(spacing: KubbSpacing.xl) {
                        // §01 Phase visualization
                        PASectionHeader(
                            num: "01",
                            title: vizTitle,
                            sub: vizSub,
                            accent: phaseColor
                        )
                        PAVizCard(phase: phase, data: data.vizData, phaseColor: phaseColor)

                        // §02 Trend
                        PASectionHeader(
                            num: "02",
                            title: "Trend",
                            sub: compareMode ? "Current · Prior 30d" : "Last 30 days",
                            accent: phaseColor
                        )
                        PATrendCard(
                            trend: data.trend,
                            priorTrend: compareMode ? data.priorTrend : nil,
                            phaseColor: phaseColor
                        )

                        // §03 Coaching insights
                        PASectionHeader(
                            num: "03",
                            title: "Coaching insights",
                            sub: "\(data.insights.count) notes",
                            accent: phaseColor
                        )
                        VStack(spacing: KubbSpacing.s2) {
                            ForEach(data.insights) { insight in
                                PAInsightCard(insight: insight)
                            }
                        }
                    }
                    .padding(.horizontal, KubbSpacing.m2)
                    .padding(.top, KubbSpacing.l2)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
    }

    private var vizTitle: String {
        switch phase {
        case .eightMeter:     return "Per-kubb hit rate"
        case .fourMeter:      return "Score distribution"
        case .inkasting:      return "Throw placement"
        case .pressureCooker: return "Round clears"
        }
    }

    private var vizSub: String {
        switch phase {
        case .eightMeter:     return "Sequential target order"
        case .fourMeter:      return "Avg score vs par per round"
        case .inkasting:      return "Last 3 sessions"
        case .pressureCooker: return "Last 10 sessions"
        }
    }
}

// MARK: – Phase header

struct PAPhaseHeader: View {
    let phase: KubbPhase
    @Binding var compareMode: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: KubbSpacing.s) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Text("PHASE ANALYSIS")
                .font(KubbType.monoS)
                .tracking(KubbTracking.monoS)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            PACompareToggle(on: $compareMode)
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.top, 60)
        .padding(.bottom, KubbSpacing.l)
    }
}

struct PACompareToggle: View {
    @Binding var on: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) { on.toggle() }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(on ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(on ? "COMPARE ON" : "COMPARE OFF")
                    .font(KubbType.monoXS)
                    .tracking(0.3)
            }
            .padding(.horizontal, KubbSpacing.s2)
            .padding(.vertical, 5)
            .background(on ? Color.Kubb.swedishGold : Color.white.opacity(0.12))
            .foregroundStyle(on ? Color.black : Color.white.opacity(0.85))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Hero block

struct PAHeroBlock: View {
    let phase: KubbPhase
    let data: PAHeroData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(data.subtitle)
                .font(KubbType.monoS)
                .tracking(KubbTracking.monoS)
                .foregroundStyle(.white.opacity(0.8))

            Text(phase.fullName)
                .font(KubbType.displayL)
                .tracking(KubbTracking.displayL)
                .foregroundStyle(.white)
                .padding(.top, KubbSpacing.xs2)

            HStack(alignment: .bottom, spacing: KubbSpacing.xl) {
                VStack(alignment: .leading, spacing: KubbSpacing.xs) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(data.bigStat)
                            .font(KubbType.displayXL)
                            .tracking(KubbTracking.displayXL)
                            .foregroundStyle(.white)
                        if !data.unit.isEmpty {
                            Text(data.unit)
                                .font(KubbFont.fraunces(30, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    Text(data.statLabel)
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: KubbSpacing.xs) {
                    Text(data.delta)
                        .font(KubbType.monoS)
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, KubbSpacing.s2)
                        .padding(.vertical, KubbSpacing.xs)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                    Text("vs prior 30d")
                        .font(KubbType.monoXS)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.top, KubbSpacing.xl)

            HStack(spacing: KubbSpacing.xs2) {
                PAChip(label: "PB", value: "\(data.pb) · \(data.pbDate)")
                PAChip(label: "STREAK", value: "\(data.streak) sess")
            }
            .padding(.top, KubbSpacing.l)
        }
        .padding(.horizontal, KubbSpacing.l2)
        .padding(.top, KubbSpacing.s)
        .padding(.bottom, KubbSpacing.xxl)
    }
}

struct PAChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
            Text(label)
                .font(KubbType.monoXS)
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(KubbFont.inter(13, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KubbSpacing.s2)
        .padding(.vertical, KubbSpacing.s)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m))
    }
}

// MARK: – Section header

struct PASectionHeader: View {
    let num: String
    let title: String
    let sub: String
    let accent: Color

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: KubbSpacing.s) {
            Text(num)
                .font(KubbType.monoXS)
                .tracking(1.2)
                .foregroundStyle(accent)
            Text(title)
                .font(KubbFont.inter(13, weight: .bold))
                .foregroundStyle(Color.Kubb.text)
                .tracking(-0.2)
            Spacer()
            Text(sub)
                .font(KubbType.monoXS)
                .tracking(0.3)
                .foregroundStyle(Color.Kubb.textSec)
        }
        .padding(.horizontal, 2)
    }
}

// MARK: – Viz card dispatcher

struct PAVizCard: View {
    let phase: KubbPhase
    let data: PAVizData
    let phaseColor: Color

    var body: some View {
        Group {
            switch data {
            case .eightMeter(let kubbs):
                PAHitRateBars(kubbs: kubbs, phaseColor: phaseColor)
            case .fourMeter(let rounds):
                PABlastingRoundBars(rounds: rounds, phaseColor: phaseColor)
            case .inkasting(let throwPoints, let targetRadiusNorm, let targetRadiusLabel, let outlierCount):
                PAInkastingClusterMap(throwPoints: throwPoints, targetRadiusNorm: targetRadiusNorm,
                                      targetRadiusLabel: targetRadiusLabel, outlierCount: outlierCount, phaseColor: phaseColor)
            case .pressureCooker(let modes):
                PAPressureCookerModeChart(modes: modes, phaseColor: phaseColor)
            }
        }
        .padding(KubbSpacing.m2)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
    }
}

// MARK: – 8m: Hit rate bars

struct PAHitRateBars: View {
    let kubbs: [KubbHitRate]
    let phaseColor: Color
    private let maxBarHeight: CGFloat = 60

    private var totalThrows: Int { kubbs.map(\.throwCount).reduce(0, +) }

    var body: some View {
        VStack(spacing: KubbSpacing.s) {
            HStack(alignment: .bottom, spacing: KubbSpacing.s) {
                ForEach(kubbs) { kubb in
                    let barHeight = maxBarHeight * (CGFloat(kubb.rate) / 100.0)
                    let opacity = 0.30 + (Double(kubb.rate) / 100.0) * 0.70

                    VStack(spacing: KubbSpacing.xs2) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(phaseColor.opacity(opacity))
                                .frame(height: barHeight + 20)

                            Text("\(kubb.rate)%")
                                .font(KubbType.monoXS)
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.bottom, KubbSpacing.xs)
                        }

                        Text(kubb.label)
                            .font(KubbType.monoXS)
                            .tracking(1.0)
                            .foregroundStyle(Color.Kubb.textSec)

                        Text("\(kubb.throwCount)")
                            .font(KubbFont.mono(8, weight: .regular))
                            .foregroundStyle(Color.Kubb.textTer)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("\(totalThrows) throws tracked across all sessions")
                .font(KubbType.monoXS)
                .foregroundStyle(Color.Kubb.textTer)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: – 4m: Round score bars

struct PABlastingRoundBars: View {
    let rounds: [RoundAvgScore]
    let phaseColor: Color
    private let halfHeight: CGFloat = 52

    private var maxAbs: Double {
        max(rounds.map { abs($0.avgScore) }.max() ?? 1, 0.5)
    }

    var body: some View {
        VStack(spacing: KubbSpacing.s) {
            HStack(alignment: .top, spacing: KubbSpacing.xs) {
                ForEach(rounds) { round in
                    BlastingBarColumn(
                        round: round, phaseColor: phaseColor,
                        halfHeight: halfHeight, maxAbs: maxAbs
                    )
                }
            }

            // Legend
            HStack(spacing: KubbSpacing.m) {
                HStack(spacing: KubbSpacing.xs) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.Kubb.forestGreen)
                        .frame(width: 10, height: 6)
                    Text("Under par").font(KubbType.monoXS).foregroundStyle(Color.Kubb.textSec)
                }
                HStack(spacing: KubbSpacing.xs) {
                    RoundedRectangle(cornerRadius: 2).fill(phaseColor)
                        .frame(width: 10, height: 6)
                    Text("Over par").font(KubbType.monoXS).foregroundStyle(Color.Kubb.textSec)
                }
                Spacer()
                Text("\(rounds.first?.sampleCount ?? 0)+ sessions").font(KubbType.monoXS).foregroundStyle(Color.Kubb.textTer)
            }
        }
    }
}

private struct BlastingBarColumn: View {
    let round: RoundAvgScore
    let phaseColor: Color
    let halfHeight: CGFloat
    let maxAbs: Double

    private var isUnderPar: Bool { round.avgScore < 0 }
    private var isEven: Bool { round.avgScore == 0 }
    private var barColor: Color { isUnderPar ? Color.Kubb.forestGreen : phaseColor }
    private var barH: CGFloat { halfHeight * CGFloat(abs(round.avgScore) / maxAbs) }
    private var label: String {
        isEven ? "E"
            : round.avgScore > 0 ? String(format: "+%.1f", round.avgScore)
            : String(format: "%.1f", round.avgScore)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Over-par label (tip of upward bar)
            Text(isUnderPar || isEven ? "" : label)
                .font(KubbType.monoXS)
                .tracking(0.3)
                .foregroundStyle(barColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 14)

            // Upper zone: over-par bars grow up from the par line
            ZStack(alignment: .bottom) {
                Color.clear.frame(height: halfHeight)
                if !isUnderPar && !isEven {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(0.85))
                        .frame(height: max(4, barH))
                } else if isEven {
                    // Even: hair at the par line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor.opacity(0.5))
                        .frame(height: 2)
                }
            }

            // Par / zero line
            Rectangle()
                .fill(Color.Kubb.textTer.opacity(0.35))
                .frame(height: 1)

            // Lower zone: under-par bars grow down from the par line
            ZStack(alignment: .top) {
                Color.clear.frame(height: halfHeight)
                if isUnderPar {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(0.85))
                        .frame(height: max(4, barH))
                }
            }

            // Under-par label (tip of downward bar)
            Text(isUnderPar ? label : (isEven ? "E" : ""))
                .font(KubbType.monoXS)
                .tracking(0.3)
                .foregroundStyle(barColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 14)

            // Round / kubb labels
            Spacer().frame(height: KubbSpacing.xs)
            Text("R\(round.roundNumber)")
                .font(KubbType.monoXS)
                .tracking(0.5)
                .foregroundStyle(Color.Kubb.textSec)
            Text("\(round.kubbCount)K")
                .font(KubbFont.mono(8, weight: .regular))
                .foregroundStyle(Color.Kubb.textTer)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – Inkasting: Cluster-relative placement map

struct PAInkastingClusterMap: View {
    let throwPoints: [InkastingThrow]
    let targetRadiusNorm: Double
    let targetRadiusLabel: String
    let outlierCount: Int
    let phaseColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, size in
                    drawClusterMap(ctx: ctx, size: size)
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PAClusterLegend(targetLabel: targetRadiusLabel, outlierCount: outlierCount)
                    }
                }
                .padding(KubbSpacing.s)
            }
        }
        .background(Color.Kubb.fieldMap)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m))
        .aspectRatio(4/3, contentMode: .fit)
    }

    private func drawClusterMap(ctx: GraphicsContext, size: CGSize) {
        let W = size.width, H = size.height
        let cx = W / 2, cy = H / 2

        // Compute display scale: fit all throws + target circle with 20% padding
        let allAbs = throwPoints.flatMap { [abs($0.xRel), abs($0.yRel)] }
        let maxDelta = max(allAbs.max() ?? 0, targetRadiusNorm * 1.5, 0.02)
        let scale = (min(W, H) / 2) / (maxDelta * 1.25)

        // Subtle concentric reference rings
        for mult in [0.5, 1.0] {
            let r = CGFloat(targetRadiusNorm * mult) * CGFloat(scale)
            if r > 2 {
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(Color.Kubb.sep),
                           style: StrokeStyle(lineWidth: 0.5))
            }
        }

        // Target circle (green fill + stroke)
        let circR = CGFloat(targetRadiusNorm) * CGFloat(scale)
        if circR > 2 {
            let circRect = CGRect(x: cx - circR, y: cy - circR, width: circR * 2, height: circR * 2)
            ctx.fill(Path(ellipseIn: circRect), with: .color(phaseColor.opacity(0.12)))
            ctx.stroke(Path(ellipseIn: circRect), with: .color(phaseColor),
                       style: StrokeStyle(lineWidth: 1.5))
        }

        // Crosshair at cluster center
        let arm: CGFloat = 6
        var h = Path(); h.move(to: CGPoint(x: cx - arm, y: cy)); h.addLine(to: CGPoint(x: cx + arm, y: cy))
        var v = Path(); v.move(to: CGPoint(x: cx, y: cy - arm)); v.addLine(to: CGPoint(x: cx, y: cy + arm))
        ctx.stroke(h, with: .color(Color.Kubb.textTer), style: StrokeStyle(lineWidth: 1))
        ctx.stroke(v, with: .color(Color.Kubb.textTer), style: StrokeStyle(lineWidth: 1))

        // Throw dots: core = phaseColor, outlier = textTer
        for t in throwPoints {
            let px = cx + CGFloat(t.xRel) * CGFloat(scale)
            let py = cy + CGFloat(t.yRel) * CGFloat(scale)
            let dotR: CGFloat = t.isOutlier ? 3.0 : 3.5
            let ringR = dotR + 1.5
            let color: Color = t.isOutlier ? Color.Kubb.textTer : phaseColor

            ctx.fill(Path(ellipseIn: CGRect(x: px - ringR, y: py - ringR, width: ringR * 2, height: ringR * 2)),
                     with: .color(.white))
            ctx.fill(Path(ellipseIn: CGRect(x: px - dotR, y: py - dotR, width: dotR * 2, height: dotR * 2)),
                     with: .color(color))
        }
    }
}

struct PAClusterLegend: View {
    let targetLabel: String
    let outlierCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
            Text("TARGET: \(targetLabel)")
                .font(KubbType.monoXS)
                .tracking(0.5)
                .foregroundStyle(Color.Kubb.textSec)
            Text("OUTLIERS: \(outlierCount)")
                .font(KubbType.monoXS)
                .tracking(0.5)
                .foregroundStyle(Color.Kubb.textTer)
        }
        .padding(.horizontal, KubbSpacing.s)
        .padding(.vertical, KubbSpacing.xs2)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.s))
    }
}

// MARK: – PC: Mode session counts + trend lines

struct PAPressureCookerModeChart: View {
    let modes: [PCModeData]
    let phaseColor: Color

    var body: some View {
        VStack(spacing: KubbSpacing.m) {
            if modes.isEmpty {
                Text("No sessions yet")
                    .font(KubbType.bodyS)
                    .foregroundStyle(Color.Kubb.textTer)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(modes.enumerated()), id: \.offset) { _, mode in
                    PCModeRow(mode: mode, phaseColor: phaseColor)
                    if mode.gameType != modes.last?.gameType {
                        Rectangle().fill(Color.Kubb.sep).frame(height: 0.5)
                    }
                }
            }
        }
    }
}

private struct PCModeRow: View {
    let mode: PCModeData
    let phaseColor: Color

    var body: some View {
        HStack(spacing: KubbSpacing.m) {
            VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
                Text(mode.gameType.displayName)
                    .font(KubbFont.inter(12, weight: .bold))
                    .foregroundStyle(Color.Kubb.text)
                HStack(spacing: 3) {
                    Text("\(mode.sessionCount)")
                        .font(KubbFont.fraunces(16, weight: .medium))
                        .foregroundStyle(phaseColor)
                    Text("sess")
                        .font(KubbType.monoXS)
                        .foregroundStyle(Color.Kubb.textSec)
                }
            }
            .frame(width: 80, alignment: .leading)

            MiniSparkline(values: mode.trend.isEmpty ? [0] : mode.trend, color: phaseColor)
                .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)

            if let last = mode.trend.last {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.0f", last))
                        .font(KubbFont.fraunces(18, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                    Text("latest")
                        .font(KubbType.monoXS)
                        .foregroundStyle(Color.Kubb.textTer)
                }
                .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.vertical, KubbSpacing.xs2)
    }
}

// MARK: – Trend chart

struct PATrendCard: View {
    let trend: [Double]
    let priorTrend: [Double]?
    let phaseColor: Color

    var body: some View {
        VStack(spacing: 0) {
            if #available(iOS 16.0, *) {
                PATrendChartContent(trend: trend, priorTrend: priorTrend, phaseColor: phaseColor)
                    .frame(height: 100)
            } else {
                PATrendFallback(trend: trend, phaseColor: phaseColor)
                    .frame(height: 100)
            }

            HStack {
                Text("30d ago")
                Spacer()
                Text("Today")
            }
            .font(KubbType.monoXS)
            .tracking(KubbTracking.monoXS)
            .foregroundStyle(Color.Kubb.textSec)
            .padding(.top, KubbSpacing.xs)
        }
        .padding(KubbSpacing.m2)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
    }
}

@available(iOS 16.0, *)
struct PATrendChartContent: View {
    let trend: [Double]
    let priorTrend: [Double]?
    let phaseColor: Color

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let index: Int
        let value: Double
        let series: String
    }

    private var allPoints: [TrendPoint] {
        let current = trend.enumerated().map { TrendPoint(index: $0.offset, value: $0.element, series: "current") }
        let prior   = (priorTrend ?? []).enumerated().map { TrendPoint(index: $0.offset, value: $0.element, series: "prior") }
        return current + prior
    }

    var body: some View {
        Chart(allPoints) { point in
            if point.series == "current" {
                AreaMark(
                    x: .value("Day", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [phaseColor.opacity(0.28), phaseColor.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(phaseColor)
                .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            } else {
                LineMark(
                    x: .value("Day", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Color.Kubb.textTer)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .animation(.easeOut(duration: 0.25), value: priorTrend != nil)
    }
}

struct PATrendFallback: View {
    let trend: [Double]
    let phaseColor: Color

    var body: some View {
        Canvas { ctx, size in
            guard trend.count > 1 else { return }
            let minV = trend.min() ?? 0, maxV = trend.max() ?? 1
            let range = max(maxV - minV, 0.001)
            let w = size.width, h = size.height

            func pt(_ i: Int) -> CGPoint {
                let x = CGFloat(i) / CGFloat(trend.count - 1) * w
                let y = h - (CGFloat(trend[i] - minV) / CGFloat(range)) * h
                return CGPoint(x: x, y: y)
            }

            var linePath = Path()
            linePath.move(to: pt(0))
            for i in 1..<trend.count { linePath.addLine(to: pt(i)) }
            ctx.stroke(linePath, with: .color(phaseColor),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }
}

// MARK: – Insight card

struct PAInsightCard: View {
    let insight: CoachingInsight

    var body: some View {
        HStack(alignment: .top, spacing: KubbSpacing.s2) {
            Image(systemName: insight.kind.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(insight.accent)
                .frame(width: 26, height: 26)
                .background(insight.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
                Text(insight.kind.rawValue.uppercased())
                    .font(KubbType.monoXS)
                    .tracking(1.0)
                    .foregroundStyle(insight.accent)

                Text(insight.title)
                    .font(KubbType.body)
                    .tracking(-0.2)
                    .foregroundStyle(Color.Kubb.text)

                Text(insight.body)
                    .font(KubbType.bodyS)
                    .foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(KubbSpacing.m2)
        .background(Color.Kubb.card)
        .overlay(
            Rectangle()
                .fill(insight.accent)
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
    }
}

// MARK: – PAVizData accessors (for mock fallbacks)

private extension PAVizData {
    var asKubbs: [KubbHitRate] {
        if case .eightMeter(let k) = self { return k }; return []
    }
    var asRounds: [RoundAvgScore] {
        if case .fourMeter(let r) = self { return r }; return []
    }
    var asThrowPoints: [InkastingThrow] {
        if case .inkasting(let pts, _, _, _) = self { return pts }; return []
    }
    var asModes: [PCModeData] {
        if case .pressureCooker(let m) = self { return m }; return []
    }
}

// MARK: – Real data computation

extension PhaseAnalysisData {

    static func compute(from sessions: [TrainingSession], phase: KubbPhase) -> PhaseAnalysisData {
        let cal = Calendar.current
        let now = Date()
        let cut30 = cal.date(byAdding: .day, value: -30, to: now)!
        let cut60 = cal.date(byAdding: .day, value: -60, to: now)!
        let recent = sessions.filter { $0.createdAt >= cut30 }
        let prev   = sessions.filter { $0.createdAt >= cut60 && $0.createdAt < cut30 }
        let sorted = sessions.sorted { $0.createdAt < $1.createdAt }
        switch phase {
        case .eightMeter:     return compute8m(recent: recent, prev: prev, all: sorted)
        case .fourMeter:      return compute4m(recent: recent, prev: prev, all: sorted)
        case .inkasting:      return computeInk(recent: recent, prev: prev, all: sorted)
        case .pressureCooker: return mock(for: .pressureCooker)  // handled by computePC(from:) separately
        }
    }

    // MARK: 8m

    // Sequential per-kubb hit rate: K1 is the first target, advance on each hit.
    // King is only attempted after all 5 baseline kubbs are cleared.
    static func perKubbStats(from sessions: [TrainingSession]) -> [KubbHitRate] {
        let labels = ["K1", "K2", "K3", "K4", "K5", "King"]
        var hits     = Array(repeating: 0, count: 6)
        var attempts = Array(repeating: 0, count: 6)

        for session in sessions {
            for round in session.rounds {
                let orderedThrows = round.throwRecords.sorted { $0.throwNumber < $1.throwNumber }
                var kubbIndex = 0
                for t in orderedThrows {
                    guard kubbIndex < 6 else { break }
                    attempts[kubbIndex] += 1
                    if t.result == .hit {
                        hits[kubbIndex] += 1
                        kubbIndex += 1
                    }
                }
            }
        }

        return (0..<6).compactMap { i in
            guard attempts[i] > 0 else { return nil }
            let rate = Int(Double(hits[i]) / Double(attempts[i]) * 100)
            return KubbHitRate(label: labels[i], rate: rate, throwCount: attempts[i])
        }
    }

    private static func compute8m(
        recent: [TrainingSession], prev: [TrainingSession], all: [TrainingSession]
    ) -> PhaseAnalysisData {
        // TrainingSession.accuracy is already 0–100 (not 0–1)
        let recentAvg = dblAvg(recent.map { $0.accuracy })
        let prevAvg   = dblAvg(prev.map   { $0.accuracy })
        let delta     = recentAvg - prevAvg
        let pb        = all.max { $0.accuracy < $1.accuracy }
        let pbPct     = pb?.accuracy ?? 0
        let streak    = phaseStreak(all)

        let kubbs      = perKubbStats(from: all)
        let trend      = all.suffix(20).map { $0.accuracy }
        let priorTrend = Array(all.dropLast(min(20, all.count)).suffix(20).map { $0.accuracy })

        var insights: [CoachingInsight] = []
        if delta > 2 {
            insights.append(CoachingInsight(kind: .trend, title: "Accuracy trending up",
                body: String(format: "Up %.1f%% vs last month — consistent improvement.", delta),
                accent: Color.Kubb.forestGreen))
        } else if delta < -2 {
            insights.append(CoachingInsight(kind: .warning, title: "Accuracy dipped",
                body: String(format: "Down %.1f%% vs last month. Focus on release consistency.", abs(delta)),
                accent: Color(hex: 0xC53030)))
        }
        if streak >= 3 {
            insights.append(CoachingInsight(kind: .strength, title: "\(streak)-session streak",
                body: "You've been showing up. Don't break the chain.",
                accent: Color.Kubb.swedishBlue))
        }
        insights.append(recentAvg >= 80
            ? CoachingInsight(kind: .suggestion, title: "Time to work king throws",
                body: "At \(Int(recentAvg))%+ you have the accuracy base. Mix in king shots to simulate game pressure.",
                accent: Color.Kubb.swedishGold)
            : CoachingInsight(kind: .suggestion, title: "Focus on rhythm",
                body: "Pick one distance and repeat 20 throws before moving back.",
                accent: Color.Kubb.swedishGold))

        return PhaseAnalysisData(
            hero: PAHeroData(
                bigStat: recent.isEmpty ? "—" : String(format: "%.1f", recentAvg),
                unit: "%", statLabel: "AVG ACCURACY · 30D",
                delta: fmtDelta(delta, suffix: "%"),
                pb: String(format: "%.0f%%", pbPct),
                pbDate: pb.map { shortDate($0.createdAt) } ?? "—",
                streak: streak,
                subtitle: "ACCURACY SHOOTING · 8M THROWS"),
            vizData: .eightMeter(kubbs: kubbs.isEmpty ? mock(for: .eightMeter).vizData.asKubbs : kubbs),
            trend: trend.isEmpty ? mock(for: .eightMeter).trend : Array(trend),
            priorTrend: priorTrend,
            insights: insights)
    }

    // MARK: 4m

    private static func compute4m(
        recent: [TrainingSession], prev: [TrainingSession], all: [TrainingSession]
    ) -> PhaseAnalysisData {
        let recentScores = recent.compactMap { $0.totalSessionScore }
        let prevScores   = prev.compactMap   { $0.totalSessionScore }
        let recentAvg    = dblAvg(recentScores.map(Double.init))
        let prevAvg      = dblAvg(prevScores.map(Double.init))
        let delta        = recentAvg - prevAvg
        let pb           = all.compactMap { $0.totalSessionScore }.min()
        let streak       = phaseStreak(all)

        // Per-round average score (golf-style: negative = under par = good)
        var roundScoreMap: [Int: [Int]] = [:]
        for session in all {
            for round in session.rounds where round.completedAt != nil || !round.throwRecords.isEmpty {
                guard let kubbCount = round.targetKubbCount, kubbCount >= 2 else { continue }
                roundScoreMap[round.roundNumber, default: []].append(round.score)
            }
        }
        let rounds: [RoundAvgScore] = (1...9).compactMap { rn in
            guard let scores = roundScoreMap[rn], !scores.isEmpty else { return nil }
            let avg = Double(scores.reduce(0, +)) / Double(scores.count)
            return RoundAvgScore(roundNumber: rn, kubbCount: min(rn + 1, 10),
                                 avgScore: avg, sampleCount: scores.count)
        }

        let trend      = all.suffix(20).compactMap { $0.totalSessionScore.map(Double.init) }
        let priorTrend = Array(all.dropLast(min(20, all.count)).suffix(20).compactMap { $0.totalSessionScore.map(Double.init) })

        var insights: [CoachingInsight] = []
        if delta < -0.5 {
            insights.append(CoachingInsight(kind: .trend, title: "Improving below par",
                body: String(format: "%.1f score improvement vs last month.", abs(delta)),
                accent: Color.Kubb.forestGreen))
        } else if delta > 0.5 {
            insights.append(CoachingInsight(kind: .warning, title: "Scoring crept up",
                body: "Taking more throws to clear. Drill single-throw clears.",
                accent: Color(hex: 0xC53030)))
        }
        // Identify hardest round
        if let hardest = rounds.max(by: { $0.avgScore < $1.avgScore }), hardest.avgScore > 0 {
            insights.append(CoachingInsight(kind: .warning, title: "R\(hardest.roundNumber) (\(hardest.kubbCount) kubbs) is your weak spot",
                body: String(format: "Averaging +%.1f vs par. Drill this kubb count in isolation.", hardest.avgScore),
                accent: Color.Kubb.phase4m))
        }
        if streak >= 3 {
            insights.append(CoachingInsight(kind: .strength, title: "Consistent practice",
                body: "\(streak) sessions in a row. Frequency is what drives improvement here.",
                accent: Color.Kubb.swedishBlue))
        }
        if recentAvg < -3 {
            insights.append(CoachingInsight(kind: .suggestion, title: "Try 6-kubb rounds",
                body: "You're clearing 5 comfortably. Add a 6th kubb to build difficulty.",
                accent: Color.Kubb.swedishGold))
        } else {
            insights.append(CoachingInsight(kind: .suggestion, title: "Target single-throw clears",
                body: "Count how many rounds you clear with one throw — that's your key metric.",
                accent: Color.Kubb.swedishGold))
        }

        let bigStat  = recentScores.isEmpty ? "—" : (recentAvg >= 0 ? String(format: "+%.1f", recentAvg) : String(format: "%.1f", recentAvg))
        let pbStr    = pb.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"

        return PhaseAnalysisData(
            hero: PAHeroData(
                bigStat: bigStat, unit: "",
                statLabel: "AVG SCORE VS PAR · 30D",
                delta: delta <= 0 ? String(format: "%.1f", delta) : String(format: "+%.1f", delta),
                pb: pbStr,
                pbDate: all.first { $0.totalSessionScore == pb }.map { shortDate($0.createdAt) } ?? "—",
                streak: streak,
                subtitle: "PAR SCORE · 4M CLEARS"),
            vizData: .fourMeter(rounds: rounds.isEmpty ? mock(for: .fourMeter).vizData.asRounds : rounds),
            trend: trend.isEmpty ? mock(for: .fourMeter).trend : Array(trend),
            priorTrend: priorTrend,
            insights: insights)
    }

    // MARK: Inkasting

    private static func computeInk(
        recent: [TrainingSession], prev: [TrainingSession], all: [TrainingSession]
    ) -> PhaseAnalysisData {
        let recentAnalyses = recent.flatMap { $0.rounds.compactMap { $0.inkastingAnalysis } }
        let prevAnalyses   = prev.flatMap   { $0.rounds.compactMap { $0.inkastingAnalysis } }
        let allAnalyses    = all.flatMap    { $0.rounds.compactMap { $0.inkastingAnalysis } }

        let recentAvgRadius = dblAvg(recentAnalyses.map { $0.clusterRadiusMeters })
        let prevAvgRadius   = dblAvg(prevAnalyses.map   { $0.clusterRadiusMeters })
        let delta           = recentAvgRadius - prevAvgRadius

        // Compute relative throw positions (translated to each analysis's cluster center)
        var relativeThrows: [InkastingThrow] = []
        var coreDeltaSqNorm: [Double] = []
        var coreMeanDistances: [Double] = []

        for a in allAnalyses {
            let cx = a.clusterCenterX, cy = a.clusterCenterY
            let outlierSet = Set(a.outlierIndices)
            for (i, pt) in a.kubbPositions.enumerated() {
                let dx = pt.x - cx, dy = pt.y - cy
                let isOutlier = outlierSet.contains(i)
                relativeThrows.append(InkastingThrow(xRel: dx, yRel: dy, isOutlier: isOutlier))
                if !isOutlier { coreDeltaSqNorm.append(dx * dx + dy * dy) }
            }
            if a.meanCoreDistance > 0 { coreMeanDistances.append(a.meanCoreDistance) }
        }

        // Derive display scale: normalized coords per meter, using RMS spread vs meanCoreDistance
        let rmsNorm = coreDeltaSqNorm.isEmpty ? 0.0
            : sqrt(coreDeltaSqNorm.reduce(0, +) / Double(coreDeltaSqNorm.count))
        let avgMeanCoreDist = dblAvg(coreMeanDistances)
        let targetRadiusNorm: Double
        if avgMeanCoreDist > 0 && rmsNorm > 0 {
            let normPerMeter = rmsNorm / avgMeanCoreDist
            targetRadiusNorm = recentAvgRadius * normPerMeter
        } else {
            targetRadiusNorm = 0.04
        }

        let outlierCount     = relativeThrows.filter { $0.isOutlier }.count
        let targetRadiusLabel = recentAnalyses.isEmpty ? "—" : String(format: "%.2fm", recentAvgRadius)

        let pb = allAnalyses.map { $0.clusterRadiusMeters }.min()
        let pbSession = all.first { session in
            session.rounds.compactMap { $0.inkastingAnalysis?.clusterRadiusMeters }.min() == pb
        }
        let streak = phaseStreak(all)

        let trend = all.suffix(20).compactMap { s -> Double? in
            let radii = s.rounds.compactMap { $0.inkastingAnalysis?.clusterRadiusMeters }
            return radii.isEmpty ? nil : dblAvg(radii)
        }

        var insights: [CoachingInsight] = []
        if delta < -0.05 {
            insights.append(CoachingInsight(kind: .trend, title: "Cluster tightening",
                body: String(format: "Radius down %.2fm vs last month — clear improvement.", abs(delta)),
                accent: Color.Kubb.forestGreen))
        } else if delta > 0.05 {
            insights.append(CoachingInsight(kind: .warning, title: "Spread widening",
                body: "Cluster radius grew. Slow your throw and focus on wrist follow-through.",
                accent: Color(hex: 0xC53030)))
        }
        if streak >= 3 {
            insights.append(CoachingInsight(kind: .strength, title: "Consistent inkasting work",
                body: "\(streak) sessions of field placement. This phase rewards volume.",
                accent: Color.Kubb.swedishBlue))
        }
        insights.append(recentAvgRadius > 0 && recentAvgRadius < 1.5
            ? CoachingInsight(kind: .suggestion, title: "Try 10-kubb clusters",
                body: "Your tight cluster shows you're ready for full 10-kubb drills.",
                accent: Color.Kubb.swedishGold)
            : CoachingInsight(kind: .suggestion, title: "Aim for the center marker",
                body: "Place a marker at your target zone and count only throws inside 1.5m.",
                accent: Color.Kubb.swedishGold))

        return PhaseAnalysisData(
            hero: PAHeroData(
                bigStat: recentAnalyses.isEmpty ? "—" : String(format: "%.2f", recentAvgRadius),
                unit: "m", statLabel: "AVG CLUSTER RADIUS · 30D",
                delta: delta <= 0 ? String(format: "%.2fm", delta) : String(format: "+%.2fm", delta),
                pb: pb.map { String(format: "%.2fm", $0) } ?? "—",
                pbDate: pbSession.map { shortDate($0.createdAt) } ?? "—",
                streak: streak,
                subtitle: "THROW CLUSTERING · FIELD PLACEMENT"),
            vizData: .inkasting(
                throwPoints: relativeThrows.isEmpty ? mock(for: .inkasting).vizData.asThrowPoints : relativeThrows,
                targetRadiusNorm: targetRadiusNorm,
                targetRadiusLabel: targetRadiusLabel,
                outlierCount: outlierCount),
            trend: trend.isEmpty ? mock(for: .inkasting).trend : Array(trend),
            priorTrend: [],
            insights: insights)
    }

    // MARK: Pressure Cooker

    static func computePC(from sessions: [PressureCookerSession]) -> PhaseAnalysisData {
        let sorted = sessions.sorted { $0.createdAt < $1.createdAt }
        let cal = Calendar.current
        let cutoff30 = cal.date(byAdding: .day, value: -30, to: Date())!

        // Group by game type
        func sessionsFor(_ gt: PressureCookerGameType) -> [PressureCookerSession] {
            sorted.filter { $0.gameType == gt.rawValue }
        }

        let modes: [PCModeData] = PressureCookerGameType.allCases.compactMap { gt in
            let gSessions = sessionsFor(gt)
            guard !gSessions.isEmpty else { return nil }
            let trend = gSessions.suffix(20).map { Double($0.totalScore) }
            return PCModeData(gameType: gt, sessionCount: gSessions.count, trend: Array(trend))
        }

        // Hero stats: use 3-4-3 as primary if available, else first mode
        let primary343 = sessionsFor(.threeForThree)
        let primarySessions = primary343.isEmpty ? sorted : primary343

        let recentPrimary = primarySessions.filter { $0.createdAt >= cutoff30 }
        let recentBest    = recentPrimary.map { $0.totalScore }.max() ?? 0
        let allBest       = primarySessions.map { $0.totalScore }.max() ?? 0
        let pbSession     = primarySessions.last { $0.totalScore == allBest }

        let prevCutoff = cal.date(byAdding: .day, value: -60, to: Date())!
        let prevPrimary = primarySessions.filter { $0.createdAt >= prevCutoff && $0.createdAt < cutoff30 }
        let prevBest    = prevPrimary.map { $0.totalScore }.max() ?? 0
        let delta       = recentBest - prevBest

        let streak = pcStreak(sessions)
        let trendAll = primarySessions.suffix(20).map { Double($0.totalScore) }

        let primaryMode = primary343.isEmpty
            ? (PressureCookerGameType.allCases.first { sessionsFor($0).count > 0 })
            : .threeForThree

        var insights: [CoachingInsight] = []
        if delta > 0 {
            insights.append(CoachingInsight(kind: .trend, title: "New best this month",
                body: "Improved by \(delta) point(s) vs last month. Momentum is real.",
                accent: Color.Kubb.forestGreen))
        }
        if streak >= 3 {
            insights.append(CoachingInsight(kind: .strength, title: "\(streak)-session run",
                body: "Consistency under pressure is what separates competitors.",
                accent: Color.Kubb.swedishBlue))
        }
        insights.append(recentBest >= 8
            ? CoachingInsight(kind: .suggestion, title: "Push for perfect",
                body: "At \(recentBest) you're close. Identify and drill your weakest round.",
                accent: Color.Kubb.swedishGold)
            : CoachingInsight(kind: .suggestion, title: "Track your weak round",
                body: "Find which round you drop the most points on, then drill it separately.",
                accent: Color.Kubb.swedishGold))

        return PhaseAnalysisData(
            hero: PAHeroData(
                bigStat: recentPrimary.isEmpty ? "—" : "\(recentBest)",
                unit: primaryMode == .threeForThree ? "/10" : "",
                statLabel: "\(primaryMode?.displayName.uppercased() ?? "PC") BEST · 30D",
                delta: delta >= 0 ? "+\(delta)" : "\(delta)",
                pb: "\(allBest)",
                pbDate: pbSession.map { shortDate($0.createdAt) } ?? "—",
                streak: streak,
                subtitle: "PRESSURE COOKER · MINI-GAMES"),
            vizData: .pressureCooker(modes: modes.isEmpty ? mock(for: .pressureCooker).vizData.asModes : modes),
            trend: trendAll.isEmpty ? mock(for: .pressureCooker).trend : Array(trendAll),
            priorTrend: [],
            insights: insights)
    }

    private static func pcStreak(_ sessions: [PressureCookerSession]) -> Int {
        let cal = Calendar.current
        let activeDays = Set(sessions.map { cal.startOfDay(for: $0.createdAt) })
        var streak = 0
        var day = cal.startOfDay(for: Date())
        if !activeDays.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        while activeDays.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    // MARK: Shared helpers

    private static func dblAvg(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func fmtDelta(_ delta: Double, suffix: String) -> String {
        delta >= 0
            ? String(format: "+%.1f\(suffix)", delta)
            : String(format: "%.1f\(suffix)", delta)
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private static func phaseStreak(_ sessions: [TrainingSession]) -> Int {
        let cal = Calendar.current
        let activeDays = Set(sessions.map { cal.startOfDay(for: $0.createdAt) })
        var streak = 0
        // Start from today; if no session today, start from yesterday
        var day = cal.startOfDay(for: Date())
        if !activeDays.contains(day) {
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        while activeDays.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }
}

// MARK: – Preview

#Preview("Inkasting") {
    NavigationStack { PhaseAnalysisView(phase: .inkasting) }
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self, InkastingAnalysis.self], inMemory: true)
}

#Preview("8 Meters") {
    NavigationStack { PhaseAnalysisView(phase: .eightMeter) }
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self, InkastingAnalysis.self], inMemory: true)
}

#Preview("4M Blasting") {
    NavigationStack { PhaseAnalysisView(phase: .fourMeter) }
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self, InkastingAnalysis.self], inMemory: true)
}

#Preview("Pressure Cooker") {
    NavigationStack { PhaseAnalysisView(phase: .pressureCooker) }
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self, InkastingAnalysis.self], inMemory: true)
}
