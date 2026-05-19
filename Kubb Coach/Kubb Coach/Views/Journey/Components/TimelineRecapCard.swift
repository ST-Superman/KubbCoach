// TimelineRecapCard.swift
// Pinned card shown at the top of Journey Timeline for ~24h after a session
// completes. Richer than a normal session row: includes the phase tag,
// "RECAP" stamp, the hero stat, the coach cue, and a row of meta footer
// links. Sourced from design_handoff_timeline/recap/timeline-recap-card.jsx.

import SwiftUI
import SwiftData

struct TimelineRecapCard: View {
    let session: TrainingSession
    var onTap: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var scenario: SessionRecapScenario?

    var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        .task {
            scenario = SessionRecapService.scenario(for: session, context: modelContext)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let scenario {
            let kp = scenario.phase.kubbPhase
            let color = Color.Kubb.phase(kp)
            VStack(alignment: .leading, spacing: 0) {
                header(scenario: scenario, color: color)
                statRow(scenario: scenario, color: color)
                cueBlock(scenario: scenario, color: color)
                metaFooter(scenario: scenario)
            }
            .background(Color.Kubb.card)
            .overlay(alignment: .leading) {
                Rectangle().fill(color).frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xxl))
            .kubbCardShadow()
        } else {
            // Lightweight skeleton — keeps layout stable while the scenario builds.
            RoundedRectangle(cornerRadius: KubbRadius.xxl)
                .fill(Color.Kubb.card)
                .frame(height: 140)
        }
    }

    // MARK: - Header strip (phase badge + RECAP stamp + time)

    private func header(scenario: SessionRecapScenario, color: Color) -> some View {
        HStack(spacing: KubbSpacing.s) {
            Text(scenario.phase.shortName.uppercased())
                .font(KubbFont.mono(9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(.white)
                .padding(.horizontal, KubbSpacing.s)
                .padding(.vertical, 3)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            if scenario.isPB {
                Text("★ PB")
                    .font(KubbFont.mono(9, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(Color(hex: "3D2C00"))
                    .padding(.horizontal, KubbSpacing.s)
                    .padding(.vertical, 3)
                    .background(Color.Kubb.swedishGold)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text("RECAP")
                .font(KubbFont.mono(9, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(.white)
                .padding(.horizontal, KubbSpacing.s)
                .padding(.vertical, 3)
                .background(Color.Kubb.midnightNavy)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer(minLength: 0)

            // TimelineRecapCard only renders for TrainingSession-backed
            // scenarios; the optional unwrap below is just type-safety.
            Text(relativeTime(scenario.session?.completedAt))
                .font(KubbFont.inter(11, weight: .medium))
                .foregroundStyle(Color.Kubb.textSec)
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.top, KubbSpacing.m2)
    }

    // MARK: - Stat row (large numeral + spark)

    private func statRow(scenario: SessionRecapScenario, color: Color) -> some View {
        HStack(alignment: .bottom, spacing: KubbSpacing.m2) {
            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.statValue)
                    .font(KubbFont.fraunces(38, weight: .medium, italic: true))
                    .foregroundStyle(color)
                    .monospacedDigit()

                HStack(spacing: 6) {
                    Text(scenario.statLabel)
                        .font(KubbFont.inter(11, weight: .medium))
                        .foregroundStyle(Color.Kubb.textSec)
                    if let delta = scenario.deltaText {
                        Text("·")
                            .foregroundStyle(Color.Kubb.textTer)
                        Text(delta)
                            .font(KubbFont.inter(11, weight: .medium))
                            .foregroundStyle(Color.Kubb.textSec)
                    }
                }
            }
            Spacer(minLength: 0)

            if !scenario.roundValues.isEmpty {
                Group {
                    if scenario.phase == .fourMetersBlasting {
                        BarSpark(values: scenario.roundValues)
                    } else {
                        LineSpark(values: scenario.roundValues, color: color)
                    }
                }
                .frame(width: 80, height: 28)
            }
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.top, KubbSpacing.s2)
    }

    // MARK: - Cue block (pull-quote style)

    private func cueBlock(scenario: SessionRecapScenario, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scenario.hook.kicker)
                .font(KubbFont.mono(9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(color)
            Text(scenario.cue)
                .font(KubbFont.fraunces(15, weight: .regular, italic: true))
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KubbSpacing.m2)
        .padding(.vertical, KubbSpacing.m)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
        .padding(.horizontal, KubbSpacing.l)
        .padding(.top, KubbSpacing.m)
    }

    // MARK: - Footer (rounds · duration · open detail)

    @ViewBuilder
    private func metaFooter(scenario: SessionRecapScenario) -> some View {
        // TimelineRecapCard only renders for TrainingSession-backed scenarios.
        if let session = scenario.session {
            metaFooterContent(session: session)
        }
    }

    private func metaFooterContent(session: TrainingSession) -> some View {
        HStack(spacing: KubbSpacing.m) {
            Label("\(session.rounds.count)/\(session.configuredRounds)", systemImage: "list.bullet")
                .font(KubbFont.inter(11, weight: .medium))
                .foregroundStyle(Color.Kubb.textSec)
            if let dur = session.durationFormatted {
                Label(dur, systemImage: "clock")
                    .font(KubbFont.inter(11, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text("Open detail")
                    .font(KubbFont.inter(11, weight: .heavy))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .heavy))
            }
            .foregroundStyle(Color.Kubb.swedishBlue)
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.top, KubbSpacing.m)
        .padding(.bottom, KubbSpacing.m2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.Kubb.sep)
                .frame(height: 0.5)
                .padding(.horizontal, KubbSpacing.l)
        }
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date?) -> String {
        guard let date else { return "" }
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60         { return "just now" }
        if secs < 3600       { return "\(secs / 60)m ago" }
        if secs < 24 * 3600  { return "\(secs / 3600)h ago" }
        let fmt = DateFormatter(); fmt.dateStyle = .none; fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

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
