// SessionRecapView.swift
// Shared post-session recap body used by the 8m, 4m, and inkasting
// completion views. Renders the "Recap Quiet" layout from
// design_handoff_timeline/recap/recap-quiet.jsx: phase-color hero band,
// collapsible round breakdown, coach cue, single adaptive habit hook,
// notes field, and a next-session nudge.
//
// The view is body-only — it does NOT own the navigation chrome, overlay
// cascade (milestones / level-up / goals), share sheet, or final action
// buttons. Each calling completion view keeps that plumbing.

import SwiftUI
import SwiftData

struct SessionRecapView: View {
    let session: TrainingSession
    @Binding var notes: String

    @Environment(\.modelContext) private var modelContext
    @State private var scenario: SessionRecapScenario?
    @State private var showRounds = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if let scenario {
                    heroBand(scenario)
                    roundBreakdown(scenario)
                    cueCard(scenario)
                    habitHookCard(scenario)
                    notesField
                    if let nudge = scenario.nextNudge {
                        nextNudgeCard(nudge)
                    }
                    Spacer().frame(height: 120) // clearance for caller's footer
                } else {
                    ProgressView()
                        .padding(.top, 120)
                }
            }
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .task {
            scenario = SessionRecapService.scenario(for: session, context: modelContext)
        }
    }

    // MARK: - Hero band

    private func heroBand(_ scenario: SessionRecapScenario) -> some View {
        let color = Color.Kubb.phase(scenario.phase.kubbPhase)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: KubbSpacing.s) {
                Text("SESSION RECAP · \(scenario.phase.shortName.uppercased()) · JUST NOW")
                    .font(KubbFont.mono(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
                if scenario.isPB {
                    pbPill
                }
            }
            .padding(.bottom, KubbSpacing.m2)

            Text(scenario.phase.displayName)
                .font(KubbFont.inter(13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(scenario.statValue)
                    .font(KubbFont.inter(64, weight: .heavy))
                    .tracking(-2.4)
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.top, 4)

            HStack(spacing: 6) {
                Text(scenario.statLabel)
                    .font(KubbFont.inter(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                if let delta = scenario.deltaText {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.5))
                    Text(delta)
                        .font(KubbFont.inter(12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.xxl)
        .padding(.bottom, KubbSpacing.xxl)
        .background(
            LinearGradient(
                colors: [color, color.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private var pbPill: some View {
        Text("★ PB")
            .font(KubbFont.mono(10, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(Color(hex: "3D2C00"))
            .padding(.horizontal, KubbSpacing.s)
            .padding(.vertical, 4)
            .background(Color.Kubb.swedishGold)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.s))
    }

    // MARK: - Round breakdown expander

    @ViewBuilder
    private func roundBreakdown(_ scenario: SessionRecapScenario) -> some View {
        if !scenario.roundValues.isEmpty {
            let color = Color.Kubb.phase(scenario.phase.kubbPhase)
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showRounds.toggle() }
                } label: {
                    HStack(spacing: KubbSpacing.s2) {
                        Text("ROUND BREAKDOWN")
                            .font(KubbFont.mono(9, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(color)
                        sparkInline(scenario)
                        Spacer()
                        Text(showRounds ? "Hide" : "Show")
                            .font(KubbFont.inter(11, weight: .semibold))
                            .foregroundStyle(Color.Kubb.textSec)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.Kubb.textSec)
                            .rotationEffect(.degrees(showRounds ? 90 : 0))
                    }
                    .padding(.horizontal, KubbSpacing.m2)
                    .padding(.vertical, KubbSpacing.m)
                    .background(Color.Kubb.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: showRounds ? 0 : KubbRadius.ml)
                            .strokeBorder(Color.Kubb.sep, lineWidth: 1)
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: KubbRadius.ml,
                            bottomLeadingRadius: showRounds ? 0 : KubbRadius.ml,
                            bottomTrailingRadius: showRounds ? 0 : KubbRadius.ml,
                            topTrailingRadius: KubbRadius.ml
                        )
                    )
                }
                .buttonStyle(.plain)

                if showRounds {
                    roundDetail(scenario)
                        .padding(KubbSpacing.m2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.Kubb.card)
                        .overlay(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: KubbRadius.ml,
                                bottomTrailingRadius: KubbRadius.ml,
                                topTrailingRadius: 0
                            )
                            .strokeBorder(Color.Kubb.sep, lineWidth: 1)
                        )
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: KubbRadius.ml,
                                bottomTrailingRadius: KubbRadius.ml,
                                topTrailingRadius: 0
                            )
                        )
                }
            }
            .padding(.horizontal, KubbSpacing.xl)
            .padding(.top, KubbSpacing.m2)
        }
    }

    @ViewBuilder
    private func sparkInline(_ scenario: SessionRecapScenario) -> some View {
        let color = Color.Kubb.phase(scenario.phase.kubbPhase)
        switch scenario.phase {
        case .fourMetersBlasting:
            BarSpark(values: scenario.roundValues)
                .frame(width: 70, height: 20)
        default:
            LineSpark(values: scenario.roundValues, color: color)
                .frame(width: 70, height: 20)
        }
    }

    @ViewBuilder
    private func roundDetail(_ scenario: SessionRecapScenario) -> some View {
        let color = Color.Kubb.phase(scenario.phase.kubbPhase)
        switch scenario.phase {
        case .eightMeters:
            VStack(spacing: 5) {
                ForEach(Array(scenario.roundValues.enumerated()), id: \.offset) { idx, accuracy in
                    HStack(spacing: 6) {
                        Text("R\(idx + 1)")
                            .font(KubbFont.mono(9, weight: .medium))
                            .foregroundStyle(Color.Kubb.textSec)
                            .frame(width: 18, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.Kubb.paper2)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color)
                                    .frame(width: geo.size.width * accuracy / 100.0)
                            }
                        }
                        .frame(height: 12)
                        Text("\(Int(accuracy.rounded()))%")
                            .font(KubbFont.mono(10, weight: .bold))
                            .foregroundStyle(Color.Kubb.text)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        case .fourMetersBlasting:
            VStack(spacing: 4) {
                let max = scenario.roundValues.map { abs($0) }.max() ?? 2
                let span = max < 2 ? 2.0 : max
                ForEach(Array(scenario.roundValues.enumerated()), id: \.offset) { idx, score in
                    HStack(spacing: 8) {
                        Text("R\(idx + 1)")
                            .font(KubbFont.mono(9, weight: .medium))
                            .foregroundStyle(Color.Kubb.textSec)
                            .frame(width: 22, alignment: .leading)
                        GeometryReader { geo in
                            let half = geo.size.width / 2
                            let bar = (CGFloat(abs(score)) / CGFloat(span)) * half
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.Kubb.paper2)
                                Rectangle()
                                    .fill(Color.Kubb.sep)
                                    .frame(width: 1)
                                    .offset(x: half)
                                Rectangle()
                                    .fill(score < 0 ? Color.Kubb.forestGreen
                                          : score > 0 ? Color.Kubb.phasePC
                                          : Color.Kubb.textTer)
                                    .frame(width: bar)
                                    .offset(x: score < 0 ? half - bar : half)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                        .frame(height: 12)
                        Text(score > 0 ? "+\(Int(score))" : "\(Int(score))")
                            .font(KubbFont.mono(10, weight: .bold))
                            .foregroundStyle(score < 0 ? Color.Kubb.forestGreen
                                             : score > 0 ? Color.Kubb.phasePC
                                             : Color.Kubb.textSec)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        case .inkastingDrilling:
            VStack(spacing: 5) {
                let max = scenario.roundValues.max() ?? 0.001
                ForEach(Array(scenario.roundValues.enumerated()), id: \.offset) { idx, area in
                    HStack(spacing: 6) {
                        Text("R\(idx + 1)")
                            .font(KubbFont.mono(9, weight: .medium))
                            .foregroundStyle(Color.Kubb.textSec)
                            .frame(width: 18, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.Kubb.paper2)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color)
                                    .frame(width: geo.size.width * CGFloat(area / max))
                            }
                        }
                        .frame(height: 12)
                        Text(String(format: "%.2f m²", area))
                            .font(KubbFont.mono(10, weight: .bold))
                            .foregroundStyle(Color.Kubb.text)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }
        case .gameTracker, .pressureCooker:
            EmptyView()
        }
    }

    // MARK: - Coach cue

    private func cueCard(_ scenario: SessionRecapScenario) -> some View {
        let color = Color.Kubb.phase(scenario.phase.kubbPhase)
        return HStack(alignment: .top, spacing: KubbSpacing.m) {
            Text("✦")
                .font(KubbFont.fraunces(16, weight: .medium, italic: true))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("COACH CUE")
                    .font(KubbFont.mono(9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(color)
                Text(scenario.cue)
                    .font(KubbFont.fraunces(17, weight: .medium, italic: true))
                    .foregroundStyle(Color.Kubb.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.vertical, KubbSpacing.m2)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.m2)
    }

    // MARK: - Habit hook

    private func habitHookCard(_ scenario: SessionRecapScenario) -> some View {
        let palette = hookPalette(scenario.hook.kind, phaseColor: Color.Kubb.phase(scenario.phase.kubbPhase))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: palette.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text(scenario.hook.kicker)
                    .font(KubbFont.mono(9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(palette.accent)
            }
            Text(scenario.hook.line)
                .font(KubbFont.inter(13, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KubbSpacing.l)
        .padding(.vertical, KubbSpacing.m2)
        .background(Color.Kubb.card)
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.l)
                .strokeBorder(Color.Kubb.sep, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.m2)
    }

    private struct HookPalette {
        let icon: String
        let accent: Color
    }

    private func hookPalette(_ kind: RecapHook.Kind, phaseColor: Color) -> HookPalette {
        switch kind {
        case .pb:       return HookPalette(icon: "trophy.fill", accent: Color.Kubb.swedishGold)
        case .restart:  return HookPalette(icon: "flame.fill",  accent: Color(hex: "FF7A4D"))
        case .first:    return HookPalette(icon: "sparkles",     accent: phaseColor)
        case .recovery: return HookPalette(icon: "arrow.counterclockwise", accent: phaseColor)
        case .steady:   return HookPalette(icon: "circle.fill",   accent: phaseColor)
        }
    }

    // MARK: - Notes

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES")
                .font(KubbFont.mono(9, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(Color.Kubb.textSec)

            TextField(
                "What did you learn? Wind, grip, mental cues…",
                text: $notes,
                axis: .vertical
            )
            .lineLimit(2...6)
            .font(KubbFont.inter(13, weight: .regular))
            .padding(KubbSpacing.m2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Kubb.card)
            .overlay(
                RoundedRectangle(cornerRadius: KubbRadius.ml)
                    .strokeBorder(Color.Kubb.sep, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
        }
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.m2)
    }

    // MARK: - Next nudge

    private func nextNudgeCard(_ nudge: RecapNudge) -> some View {
        let kp = nudge.phase.kubbPhase
        let color = Color.Kubb.phase(kp)
        return HStack(spacing: KubbSpacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: KubbRadius.s)
                    .fill(color.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: kp.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("UP NEXT")
                    .font(KubbFont.mono(9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(Color.Kubb.textSec)
                Text(nudge.reason)
                    .font(KubbFont.inter(13, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.vertical, KubbSpacing.m)
        .background(Color.Kubb.card)
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.l)
                .strokeBorder(Color.Kubb.sep, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.m2)
    }
}

// MARK: - Shared footer bar (Share + primary CTA)
// Designed to sit at the bottom of a ZStack on top of SessionRecapView.
// Two-button row in the editorial paper aesthetic: white-card Share, navy
// primary Done. Each caller controls the button labels and actions.

struct RecapFooter: View {
    var shareLabel: String = "SHARE"
    var primaryLabel: String = "DONE"
    var onShare: () -> Void
    var onPrimary: () -> Void

    var body: some View {
        HStack(spacing: KubbSpacing.s) {
            Button(action: onShare) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text(shareLabel)
                }
                .font(KubbFont.inter(13, weight: .bold))
                .foregroundStyle(Color.Kubb.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.Kubb.card)
                .overlay(
                    RoundedRectangle(cornerRadius: KubbRadius.l)
                        .strokeBorder(Color.Kubb.sep, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
            }
            .buttonStyle(.plain)

            Button(action: onPrimary) {
                Text(primaryLabel)
                    .font(KubbFont.inter(13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(KubbColors.midnightNavy)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
                    .shadow(color: KubbColors.midnightNavy.opacity(0.22), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.vertical, KubbSpacing.m)
        .background(
            LinearGradient(
                colors: [Color.Kubb.paper.opacity(0), Color.Kubb.paper],
                startPoint: .top, endPoint: .bottom
            )
        )
        .safeAreaPadding(.bottom)
    }
}

// MARK: - Tiny sparkline primitives

/// 1-D line sparkline. Values rendered as a polyline scaled to [min, max].
struct LineSpark: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            let span = max(hi - lo, 0.001)
            Path { path in
                guard values.count > 1 else { return }
                for (i, v) in values.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                    let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else      { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: .init(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

/// 1-D bar sparkline for signed values. Bars above midline = positive (red, over-par),
/// below = negative (green, under-par).
struct BarSpark: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxAbs = values.map { abs($0) }.max() ?? 1
            let span = maxAbs < 1 ? 1.0 : maxAbs
            let halfH = geo.size.height / 2
            let slotW = geo.size.width / CGFloat(max(values.count, 1))
            HStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    let h = CGFloat(abs(v) / span) * halfH
                    ZStack(alignment: v < 0 ? .top : .bottom) {
                        Color.clear
                        Rectangle()
                            .fill(v < 0 ? Color.Kubb.forestGreen
                                  : v > 0 ? Color.Kubb.phasePC
                                  : Color.Kubb.textTer)
                            .frame(width: slotW * 0.6, height: max(h, 1))
                            .offset(y: v < 0 ? halfH : -halfH)
                    }
                    .frame(width: slotW, height: geo.size.height)
                }
            }
        }
    }
}

// MARK: - Phase shortName helper (kept private — service file owns its own)

private extension TrainingPhase {
    var shortName: String {
        switch self {
        case .eightMeters:        return "8m"
        case .fourMetersBlasting: return "4m"
        case .inkastingDrilling:  return "ink"
        case .gameTracker:        return "game"
        case .pressureCooker:     return "pc"
        }
    }

    var kubbPhase: KubbPhase {
        switch self {
        case .eightMeters:        return .eightMeter
        case .fourMetersBlasting: return .fourMeter
        case .inkastingDrilling:  return .inkasting
        case .gameTracker:        return .gameTracker
        case .pressureCooker:     return .pressureCooker
        }
    }
}
