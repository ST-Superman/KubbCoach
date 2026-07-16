// SessionRecapView.swift
// Shared post-session recap body used by the 8m, 4m, and inkasting
// completion views. Renders the "Recap Quiet" layout from
// design_handoff_session_recap: phase-color hero band, collapsible round
// breakdown with Stat Strip, coach cue, single adaptive habit hook,
// notes field, and a next-session nudge.
//
// The view is body-only — it does NOT own the navigation chrome, overlay
// cascade (milestones / level-up / goals), share sheet, or final action
// buttons. Each calling completion view keeps that plumbing.

import SwiftUI
import SwiftData

struct SessionRecapView: View {
    private enum Source {
        case training(TrainingSession)
        case pressureCooker(PressureCookerSession)
        case historical(item: SessionDisplayItem?, row: LedgerRow)
    }
    private let source: Source

    init(session: TrainingSession) {
        self.source = .training(session)
    }

    init(pcSession: PressureCookerSession) {
        self.source = .pressureCooker(pcSession)
    }

    init(row: LedgerRow) {
        self.source = .historical(item: row.session, row: row)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(CoachingTipsService.showProTipsDefaultsKey) private var showProTips = true
    @State private var scenario: SessionRecapScenario?
    @State private var showRounds = false
    @State private var proTip: CoachingTip?
    @State private var noteText: String = ""

    private var isHistoricalContext: Bool {
        if case .historical = source { return true }
        return false
    }

    private var resolvedTrainingSession: TrainingSession? {
        switch source {
        case .training(let ts): return ts
        case .pressureCooker: return nil
        case .historical(let item, _): return item?.localSession
        }
    }

    private var heroContextSuffix: String {
        switch source {
        case .training, .pressureCooker: return "JUST NOW"
        case .historical(_, let row): return row.dateLabel
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let scenario {
                        let phaseColor = Color.Kubb.phase(scenario.phase.kubbPhase)

                        heroBand(scenario)

                        if let xpTier = scenario.xpTierLabel {
                            xpTierPill(xpTier, phaseColor: phaseColor)
                        }

                        // Conditions block — unlabeled, between hero and §01
                        if let ts = resolvedTrainingSession {
                            conditionsSection(from: ts)
                        }

                        // §01 Round breakdown + Stat Strip
                        if !scenario.roundValues.isEmpty {
                            recapSectionHeader("01", title: "Round breakdown", sub: "Stat strip", phaseColor: phaseColor)
                            statStrip(scenario, phaseColor: phaseColor)
                            roundBreakdown(scenario)
                        }

                        if let metrics = scenario.inkastingMetrics {
                            inkastingMetricsStrip(metrics, phaseColor: phaseColor)
                        }

                        // §02 Coach cue
                        recapSectionHeader("02", title: "Coach cue", sub: "", phaseColor: phaseColor)
                        cueCard(scenario)
                        if showProTips, let proTip {
                            proTipSection(proTip, phaseColor: phaseColor)
                        }

                        // §03 Up next — habit hook + next-session nudge
                        recapSectionHeader("03", title: "Up next", sub: "", phaseColor: phaseColor)
                        habitHookCard(scenario)
                        if let nudge = scenario.nextNudge {
                            nextNudgeCard(nudge)
                        }

                        // §04 Notes
                        recapSectionHeader("04", title: "Notes", sub: "", phaseColor: phaseColor)
                        notesField

                        Spacer().frame(height: isHistoricalContext ? 24 : 120)
                    } else if isHistoricalContext {
                        cloudEmptyState
                    } else {
                        ProgressView()
                            .padding(.top, 120)
                    }
                }
            }
            .background(Color.Kubb.paper.ignoresSafeArea())

            if isHistoricalContext {
                historicalFooter
            }
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .onAppear {
            switch source {
            case .training(let ts): noteText = ts.notes ?? ""
            case .pressureCooker(let pc): noteText = pc.notes ?? ""
            case .historical(let item, _): noteText = item?.localSession?.notes ?? ""
            }
        }
        .task {
            let resolved: SessionRecapScenario? = {
                switch source {
                case .training(let session):
                    return SessionRecapService.scenario(for: session, context: modelContext)
                case .pressureCooker(let pcSession):
                    return SessionRecapService.scenario(for: pcSession, context: modelContext)
                case .historical(let item, _):
                    guard let ts = item?.localSession else { return nil }
                    return SessionRecapService.scenario(for: ts, context: modelContext)
                }
            }()
            scenario = resolved
            if showProTips, let resolved {
                proTip = CoachingTipsService.shared.tip(for: TipCategory.from(phase: resolved.phase))
            }
        }
        .onDisappear { persistNotes() }
    }

    // MARK: - Section header (matches PASectionHeader from PhaseAnalysisView)

    private func recapSectionHeader(_ num: String, title: String, sub: String, phaseColor: Color) -> some View {
        PASectionHeader(num: num, title: title, sub: sub, accent: phaseColor)
            .padding(.horizontal, KubbSpacing.xl)
            .padding(.top, KubbSpacing.l)
    }

    // MARK: - XP tier pill (PC only)

    private func xpTierPill(_ label: String, phaseColor: Color) -> some View {
        HStack {
            Spacer(minLength: 0)
            Text(label)
                .font(KubbFont.mono(10, weight: .heavy))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(phaseColor)
                .padding(.horizontal, KubbSpacing.m)
                .padding(.vertical, 5)
                .background(phaseColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: KubbRadius.s))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.m2)
    }

    // MARK: - Pro tip

    private func proTipSection(_ tip: CoachingTip, phaseColor: Color) -> some View {
        CoachingTipCard(tip: tip, accent: phaseColor)
            .padding(.horizontal, KubbSpacing.xl)
            .padding(.top, KubbSpacing.m2)
    }

    // MARK: - Hero band

    private func heroBand(_ scenario: SessionRecapScenario) -> some View {
        let color = Color.Kubb.phase(scenario.phase.kubbPhase)
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row: back button + eyebrow label + PB pill
                HStack(spacing: KubbSpacing.s) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Text("SESSION RECAP · \(scenario.phase.shortName.uppercased()) · \(heroContextSuffix)")
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

                // Hero numeral — Fraunces 68/medium/tracking -3 (matches PhaseAnalysisView hero)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(scenario.statValue)
                        .font(KubbFont.fraunces(68, weight: .medium))
                        .tracking(-3)
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

                // Chip row: ROUNDS + DURATION (matches PAChip style)
                HStack(spacing: KubbSpacing.xs2) {
                    PAChip(label: "ROUNDS", value: scenario.roundsLabel)
                    PAChip(label: "DURATION", value: scenario.durationLabel)
                }
                .padding(.top, KubbSpacing.l)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, KubbSpacing.xl)
            .padding(.top, KubbSpacing.xxl)
            .padding(.bottom, KubbSpacing.xxl)
            .background(
                // Diagonal gradient matching PhaseAnalysisView hero
                LinearGradient(
                    colors: [color, color.shaded(by: -0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Decorative radial gold glow — off-canvas top-right, purely decorative
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.Kubb.swedishGold.opacity(0.30), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .offset(x: 40, y: -40)
                .allowsHitTesting(false)
        }
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

    // MARK: - §01 Stat Strip

    @ViewBuilder
    private func statStrip(_ scenario: SessionRecapScenario, phaseColor: Color) -> some View {
        switch scenario.phase {
        case .eightMeters:
            if let session = scenario.session {
                let kubbs = PhaseAnalysisData.perKubbStats(from: [session])
                    .filter { $0.label != "King" && $0.throwCount > 0 }
                if kubbs.count >= 2,
                   let best = kubbs.max(by: { $0.rate < $1.rate }),
                   let worst = kubbs.min(by: { $0.rate < $1.rate }) {
                    let streak = SessionRecapView.longestHitStreak(from: session)
                    HStack(spacing: KubbSpacing.s2) {
                        StatStripTile(label: "BEST KUBB",
                                      value: "\(best.label) · \(best.rate)%",
                                      valueColor: phaseColor)
                        StatStripTile(label: "WORST KUBB",
                                      value: "\(worst.label) · \(worst.rate)%",
                                      valueColor: nil)
                        StatStripTile(label: "STREAK",
                                      value: "\(streak) hit\(streak == 1 ? "" : "s")",
                                      valueColor: nil)
                    }
                    .padding(.horizontal, KubbSpacing.xl)
                    .padding(.top, KubbSpacing.m2)
                }
            }
        case .fourMetersBlasting:
            let values = scenario.roundValues
            if !values.isEmpty {
                let best = values.min() ?? 0
                let worst = values.max() ?? 0
                let underPar = values.filter { $0 < 0 }.count
                let bestStr = best > 0 ? "+\(Int(best))" : "\(Int(best))"
                let worstStr = worst > 0 ? "+\(Int(worst))" : "\(Int(worst))"
                HStack(spacing: KubbSpacing.s2) {
                    StatStripTile(label: "BEST ROUND",
                                  value: bestStr,
                                  valueColor: phaseColor)
                    StatStripTile(label: "WORST ROUND",
                                  value: worstStr,
                                  valueColor: nil)
                    StatStripTile(label: "UNDER PAR",
                                  value: "\(underPar)/\(values.count)",
                                  valueColor: nil)
                }
                .padding(.horizontal, KubbSpacing.xl)
                .padding(.top, KubbSpacing.m2)
            }
        default:
            EmptyView()
        }
    }

    private static func longestHitStreak(from session: TrainingSession) -> Int {
        var maxStreak = 0, cur = 0
        for round in session.rounds.sorted(by: { $0.roundNumber < $1.roundNumber }) {
            for t in round.throwRecords.sorted(by: { $0.throwNumber < $1.throwNumber })
            where t.targetType == .baselineKubb {
                if t.result == .hit {
                    cur += 1
                    maxStreak = max(maxStreak, cur)
                } else {
                    cur = 0
                }
            }
        }
        return maxStreak
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
            .kubbCardShadow()
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
        case .pressureCooker where scenario.pcSubType == .inTheRed:
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
        case .pressureCooker:
            pcRoundDetail(scenario)
        case .gameTracker:
            EmptyView()
        }
    }

    // MARK: - Pressure Cooker round detail

    @ViewBuilder
    private func pcRoundDetail(_ scenario: SessionRecapScenario) -> some View {
        switch scenario.pcSubType {
        case .threeForThree:
            VStack(spacing: KubbSpacing.s) {
                HStack(spacing: KubbSpacing.xs2) {
                    ForEach(0..<5, id: \.self) { idx in
                        pcFrameBox(frameNumber: idx + 1, score: pcFrameScore(scenario, idx))
                    }
                }
                HStack(spacing: KubbSpacing.xs2) {
                    ForEach(5..<10, id: \.self) { idx in
                        pcFrameBox(frameNumber: idx + 1, score: pcFrameScore(scenario, idx))
                    }
                }
            }
        case .inTheRed:
            VStack(spacing: 0) {
                let breakdown = pcITRBreakdown(scenario)
                ForEach(Array(breakdown.enumerated()), id: \.offset) { idx, item in
                    if idx > 0 {
                        Rectangle()
                            .fill(Color.Kubb.sep)
                            .frame(height: 0.5)
                    }
                    pcITRScenarioRow(item: item)
                }
            }
        case .none:
            EmptyView()
        }
    }

    private func pcFrameScore(_ scenario: SessionRecapScenario, _ idx: Int) -> Int {
        guard idx < scenario.roundValues.count else { return 0 }
        return Int(scenario.roundValues[idx])
    }

    private func pcFrameBox(frameNumber: Int, score: Int) -> some View {
        let (bg, fg, border): (Color, Color, Color) = {
            if score == 13 {
                return (Color.Kubb.swedishGold.opacity(0.14), Color.Kubb.swedishGold, Color.Kubb.swedishGold.opacity(0.4))
            }
            if score >= 10 {
                return (Color.Kubb.forestGreen.opacity(0.10), Color.Kubb.forestGreen, Color.Kubb.forestGreen.opacity(0.30))
            }
            if score >= 7 {
                return (Color.Kubb.paper2, Color.Kubb.phasePC, Color.Kubb.sep)
            }
            return (Color.Kubb.paper2, Color.Kubb.text, Color.Kubb.sep)
        }()
        return VStack(spacing: 3) {
            Text("\(frameNumber)")
                .font(KubbFont.mono(9, weight: .medium))
                .foregroundStyle(Color.Kubb.textSec)
            Text("\(score)")
                .font(KubbFont.fraunces(17, weight: .medium))
                .foregroundStyle(fg)
                .monospacedDigit()
                .frame(height: 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KubbSpacing.s)
        .background(bg)
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.s, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.s, style: .continuous))
    }

    private struct PCITRItem {
        let displayName: String
        let scores: [Int]
        var net: Int { scores.reduce(0, +) }
    }

    private func pcITRBreakdown(_ scenario: SessionRecapScenario) -> [PCITRItem] {
        var map: [InTheRedScenario: [Int]] = [:]
        for (idx, raw) in scenario.pcITRScenarios.enumerated() {
            guard idx < scenario.roundValues.count,
                  let key = InTheRedScenario(rawValue: raw) else { continue }
            map[key, default: []].append(Int(scenario.roundValues[idx]))
        }
        return InTheRedScenario.allCases.compactMap { key in
            guard let scores = map[key] else { return nil }
            return PCITRItem(displayName: key.displayName, scores: scores)
        }
    }

    private func pcITRScenarioRow(item: PCITRItem) -> some View {
        HStack(spacing: KubbSpacing.s2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(KubbFont.inter(13, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                Text("\(item.scores.count) round\(item.scores.count == 1 ? "" : "s")")
                    .font(KubbFont.mono(9, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(Color.Kubb.textSec)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(Array(item.scores.enumerated()), id: \.offset) { _, score in
                    pcITRDot(score: score)
                }
            }
            let signed = item.net > 0 ? "+\(item.net)" : "\(item.net)"
            Text(signed)
                .font(KubbFont.mono(11, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(item.net > 0 ? Color.Kubb.forestGreen
                                  : item.net < 0 ? Color.Kubb.miss
                                  : Color.Kubb.textSec)
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.horizontal, KubbSpacing.s2)
        .padding(.vertical, KubbSpacing.s)
    }

    private func pcITRDot(score: Int) -> some View {
        let (bg, fg, glyph): (Color, Color, String) = {
            switch score {
            case 1:  return (Color.Kubb.swedishGold.opacity(0.18), Color.Kubb.swedishGold, "✓")
            case 0:  return (Color.Kubb.forestGreen.opacity(0.18), Color.Kubb.forestGreen, "○")
            default: return (Color.Kubb.miss.opacity(0.15),         Color.Kubb.miss,         "✗")
            }
        }()
        return Text(glyph)
            .font(KubbFont.mono(10, weight: .heavy))
            .foregroundStyle(fg)
            .frame(width: 22, height: 22)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xs, style: .continuous))
    }

    // MARK: - Inkasting metrics strip

    private func inkastingMetricsStrip(_ metrics: InkastingSessionMetrics, phaseColor: Color) -> some View {
        HStack(spacing: 0) {
            inkMetricCell(
                value: "\(metrics.perfectRoundCount)/\(metrics.totalRounds)",
                label: "CLEAN ROUNDS",
                color: metrics.perfectRoundCount == metrics.totalRounds
                    ? Color.Kubb.forestGreen
                    : metrics.perfectRoundCount > 0 ? Color.Kubb.swedishGold : Color.Kubb.textSec
            )
            Divider().frame(height: 32)
            inkMetricCell(
                value: String(format: "%.1f%%", metrics.outlierRate),
                label: "OUTLIER RATE",
                color: metrics.outlierRate > 20.0 ? Color.Kubb.missBright : Color.Kubb.textSec
            )
            Divider().frame(height: 32)
            inkMetricCell(
                value: String(format: "%.2f×", metrics.spreadRatio),
                label: "SPREAD RATIO",
                color: Color.Kubb.textSec
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KubbSpacing.m2)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.m2)
    }

    private func inkMetricCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(KubbFont.fraunces(20, weight: .medium, italic: true))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(KubbFont.mono(8, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(Color.Kubb.textTer)
        }
        .frame(maxWidth: .infinity)
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
        .kubbCardShadow()
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
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
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
            TextField(
                "What did you learn? Wind, grip, mental cues…",
                text: $noteText,
                axis: .vertical
            )
            .lineLimit(2...6)
            .font(KubbFont.inter(13, weight: .regular))
            .padding(KubbSpacing.m2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
            .kubbCardShadow()
        }
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.m2)
    }

    // MARK: - Notes persistence

    private func persistNotes() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String? = trimmed.isEmpty ? nil : trimmed
        switch source {
        case .training(let ts):
            guard ts.notes != newValue else { return }
            ts.notes = newValue
            try? modelContext.save()
        case .pressureCooker(let pc):
            guard pc.notes != newValue else { return }
            pc.notes = newValue
            try? modelContext.save()
        case .historical(let item, _):
            guard let ts = item?.localSession, ts.notes != newValue else { return }
            ts.notes = newValue
            try? modelContext.save()
        }
    }

    // MARK: - Conditions block (unlabeled, sits between hero and §01)

    @ViewBuilder
    private func conditionsSection(from ts: TrainingSession) -> some View {
        let hasData = ts.locationName != nil || ts.weatherCondition != nil || ts.windSpeedMph != nil
        if hasData {
            SDCard {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    if let loc = ts.locationName {
                        SDConditionCell(label: "Location", value: loc, subtitle: sessionTimeRange(ts))
                    }
                    if let speed = ts.windSpeedMph {
                        let dir = ts.windDirection.map { " \($0)" } ?? ""
                        SDConditionCell(label: "Wind", value: "\(Int(speed.rounded())) mph\(dir)")
                    }
                    if let weather = ts.weatherCondition {
                        let rainSuffix = (ts.precipitation24hMm ?? 0) > 0.5 ? " · Recent rain" : ""
                        SDConditionCell(label: "Weather", value: "\(weather)\(rainSuffix)")
                    }
                    if let device = ts.deviceType {
                        SDConditionCell(label: "Tracked on", value: device)
                    }
                }
            }
            .padding(.horizontal, KubbSpacing.xl)
            .padding(.top, KubbSpacing.m2)
        }
    }

    private func sessionTimeRange(_ ts: TrainingSession) -> String? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let start = formatter.string(from: ts.createdAt)
        guard let end = ts.completedAt else { return start }
        return "\(start) – \(formatter.string(from: end))"
    }

    // MARK: - Historical context: cloud empty state + footer

    private var cloudEmptyState: some View {
        VStack(spacing: KubbSpacing.m) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.Kubb.textTer)
            Text("Analysis syncs when this session downloads")
                .font(KubbFont.inter(14, weight: .regular))
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, KubbSpacing.xxl)
    }

    private var historicalFooter: some View {
        RecapFooter(
            shareLabel: "SHARE",
            primaryLabel: "Close",
            onShare: { shareHistoricalSession() },
            onPrimary: { persistNotes(); dismiss() }
        )
    }

    @MainActor
    private func shareHistoricalSession() {
        guard let ts = resolvedTrainingSession else { return }
        let descriptor = FetchDescriptor<PersonalBest>()
        let allBests = (try? modelContext.fetch(descriptor)) ?? []
        let pbs = allBests.filter { ts.newPersonalBests.contains($0.id) }
        let data = ts.shareCardData(context: modelContext, personalBests: pbs)
        let items: [Any]
        if let image = ShareCardView(data: data).renderImage() {
            items = [image]
        } else {
            items = ["\(ts.phase?.rawValue ?? "Session") · \(ts.createdAt.formatted(date: .abbreviated, time: .omitted))"]
        }
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        av.popoverPresentationController?.sourceView = presenter.view
        presenter.present(av, animated: true)
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
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
        .padding(.horizontal, KubbSpacing.xl)
        .padding(.top, KubbSpacing.m2)
    }
}

// MARK: - Stat strip tile

struct StatStripTile: View {
    let label: String
    let value: String
    let valueColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(KubbFont.mono(8.5, weight: .heavy))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Color.Kubb.textSec)
            Text(value)
                .font(KubbFont.inter(15, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(valueColor ?? Color.Kubb.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KubbSpacing.s2)
        .padding(.vertical, KubbSpacing.s2)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
        .kubbCardShadow()
    }
}

// MARK: - Shared footer bar (Share + primary CTA)

struct RecapFooter: View {
    var shareLabel: String = "SHARE"
    var primaryLabel: String = "DONE"
    var onShare: () -> Void
    var onPrimary: () -> Void

    var body: some View {
        HStack(spacing: KubbSpacing.s) {
            Button(action: onShare) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text(shareLabel)
                        .font(KubbFont.inter(13, weight: .heavy))
                }
                .foregroundStyle(Color.Kubb.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.Kubb.card)
                .overlay(
                    RoundedRectangle(cornerRadius: KubbRadius.l)
                        .strokeBorder(Color.Kubb.text.opacity(0.25), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
            }
            .buttonStyle(.plain)

            Button(action: onPrimary) {
                Text(primaryLabel)
                    .font(KubbFont.inter(13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.Kubb.midnightNavy)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
                    .shadow(color: Color.Kubb.midnightNavy.opacity(0.22), radius: 10, y: 4)
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
