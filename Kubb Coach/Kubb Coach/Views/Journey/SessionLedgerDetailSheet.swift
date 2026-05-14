// SessionLedgerDetailSheet.swift
// V2 "Tabbed compact" session detail — full-bleed gradient hero, sticky 3-tab bar (Overview / Rounds / Compare).

import SwiftUI
import SwiftData

// MARK: – Main view

struct SessionLedgerDetailSheet: View {
    @State private var currentRow: LedgerRow
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<TrainingSession> { $0.completedAt != nil || $0.deviceType == "Watch" },
        sort: \TrainingSession.createdAt, order: .reverse
    ) private var allLocalSessions: [TrainingSession]

    @State private var activeTab = "overview"
    @State private var noteText = ""
    @State private var noteFocused = false

    init(row: LedgerRow) {
        _currentRow = State(initialValue: row)
    }

    private var row: LedgerRow { currentRow }
    private var phaseColor: Color { Color.Kubb.phase(row.phase) }
    private var session: SessionDisplayItem { row.session! }

    private var samePhaseSessions: [SessionDisplayItem] {
        allLocalSessions
            .filter { $0.phase == session.phase }
            .map { .local($0) }
    }

    private var deltaVsAvg: (delta: Double, avg: Double)? {
        guard session.phase == .eightMeters else { return nil }
        let me = session.accuracy
        let others = samePhaseSessions.filter { $0.id != session.id }.map(\.accuracy)
        guard !others.isEmpty else { return nil }
        let avg = others.reduce(0, +) / Double(others.count)
        return (me - avg, avg)
    }

    private var trendSessions: [SessionDisplayItem] {
        Array(samePhaseSessions.prefix(6).reversed())
    }

    private var relatedSessions: [SessionDisplayItem] {
        Array(samePhaseSessions.filter { $0.id != session.id }.prefix(3))
    }

    // MARK: – body

    var body: some View {
        VStack(spacing: 0) {
            heroBlock
            tabBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    switch activeTab {
                    case "rounds":  roundsTab
                    case "compare": compareTab
                    default:        overviewTab
                    }
                    Spacer().frame(height: 110)
                }
            }
            .background(Color(hex: "FBFAF6"))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: – Hero block

    private var heroBlock: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [phaseColor, phaseColor.opacity(0.847)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                // Back button · context line · PB badge
                HStack(spacing: 8) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .background(.ultraThinMaterial, in: Circle())
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)

                    Text("\(row.phase.fullName.uppercased()) · \(row.dateLabel) · \(row.timeLabel)")
                        .font(KubbFont.inter(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 4)

                    if row.isPersonalBest {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("PB")
                                .font(KubbFont.inter(10, weight: .heavy))
                        }
                        .foregroundStyle(Color(hex: "3D2C00"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.Kubb.swedishGold)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // Headline stat + sparkline
                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.phase.fullName)
                            .font(KubbFont.inter(13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        Text(row.statLine)
                            .font(KubbFont.inter(56, weight: .heavy))
                            .tracking(-2)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        HStack(spacing: 4) {
                            Text(heroStatLabel)
                                .foregroundStyle(.white.opacity(0.85))
                            if let d = deltaVsAvg {
                                Text("·")
                                    .foregroundStyle(.white.opacity(0.55))
                                Text(String(format: "%@%.1f", d.delta >= 0 ? "+" : "", d.delta))
                                    .fontWeight(.heavy)
                                    .foregroundStyle(.white)
                                Text("vs avg")
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        .font(KubbFont.inter(12, weight: .regular))
                        .padding(.top, 2)
                    }

                    if !sparkValues.isEmpty {
                        Spacer()
                        SDSparkLine(values: sparkValues, color: .white)
                            .frame(width: 100, height: 42)
                    }
                }
            }
            .padding(.top, 52)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    // MARK: – Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(
                [("overview", "Overview"), ("rounds", "Rounds"), ("compare", "Compare")],
                id: \.0
            ) { id, label in
                let active = activeTab == id
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { activeTab = id }
                } label: {
                    Text(label)
                        .font(KubbFont.inter(13, weight: .bold))
                        .foregroundStyle(active ? phaseColor : Color.Kubb.textSec)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(active ? phaseColor : Color.clear)
                                .frame(height: 2)
                                .offset(y: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 0)
        .background(
            Color(hex: "FBFAF6").opacity(0.92)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.Kubb.sep).frame(height: 0.5)
        }
    }

    // MARK: – Overview tab

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 2×2 stat tiles
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(Array(phaseStatItems.enumerated()), id: \.offset) { _, item in
                    SDStatTile(label: item.label, value: item.value, sub: item.sub, color: item.color)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 14)

            // Conditions
            SDSectionHeader(kicker: "Conditions", title: "Where & how")
                .padding(.horizontal, 18)
            SDCard {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    SDConditionCell(label: "Location", value: "—")
                    SDConditionCell(label: "Weather", value: "—")
                    SDConditionCell(label: "Equipment", value: "Standard set")
                    SDConditionCell(label: "Tracked on", value: session.deviceType)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            // Notes
            overviewNotesSection

            // Footer
            footerActions
        }
    }

    private var overviewNotesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("NOTES")
                        .font(KubbFont.inter(9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.Kubb.textSec)
                    Text("What did you learn?")
                        .font(KubbFont.inter(15, weight: .heavy))
                        .foregroundStyle(Color.Kubb.midnightNavy)
                        .tracking(-0.2)
                }
                Spacer()
                if noteFocused {
                    Button {
                        noteFocused = false
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    } label: {
                        Text("Save")
                            .font(KubbFont.inter(11, weight: .bold))
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                }
            }
            .padding(.horizontal, 18)

            SDCard {
                ZStack(alignment: .topLeading) {
                    if noteText.isEmpty {
                        Text("Add notes about wind, grip, mental cues, anything to remember…")
                            .font(KubbFont.inter(13, weight: .regular))
                            .foregroundStyle(Color.Kubb.textTer)
                            .padding(4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $noteText)
                        .font(KubbFont.inter(13, weight: .regular))
                        .foregroundStyle(Color.Kubb.text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 72)
                        .onTapGesture { noteFocused = true }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
    }

    // MARK: – Rounds tab

    private var roundsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SDSectionHeader(kicker: "Round breakdown", title: phaseVizTitle)
                .padding(.horizontal, 18)
                .padding(.top, 14)

            SDCard { phaseVizBody }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            // 8m: 3-tile summary row
            if row.phase == .eightMeter, !session.roundSummaries.isEmpty {
                let rounds = session.roundSummaries
                let best  = rounds.max(by: { $0.accuracy < $1.accuracy })
                let worst = rounds.min(by: { $0.accuracy < $1.accuracy })
                HStack(spacing: 8) {
                    SDStatTile(
                        label: "Best round",
                        value: best.map { "\(Int(round($0.accuracy / 100.0 * 6)))/6" } ?? "—",
                        sub: best.map { "round \($0.roundNumber)" },
                        color: Color.Kubb.forestGreen
                    )
                    SDStatTile(
                        label: "Worst",
                        value: worst.map { "\(Int(round($0.accuracy / 100.0 * 6)))/6" } ?? "—",
                        sub: worst.map { "round \($0.roundNumber)" },
                        color: Color(hex: "C53030")
                    )
                    SDStatTile(
                        label: "King hits",
                        value: "\(session.kingThrowCount)/3",
                        sub: nil,
                        color: Color.Kubb.swedishGold
                    )
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private var phaseVizBody: some View {
        switch row.phase {
        case .eightMeter:
            SDHitMissGrid(rounds: session.roundSummaries, phaseColor: phaseColor, king: session.kingThrowCount)
        case .fourMeter:
            SDParBars(rounds: session.roundSummaries)
        case .inkasting:
            SDClusterMap(accuracy: session.accuracy, phaseColor: phaseColor)
        case .pressureCooker:
            SDPatternWalkthrough(rounds: session.roundSummaries, phaseColor: phaseColor)
        case .gameTracker:
            EmptyView()
        }
    }

    // MARK: – Compare tab

    private var compareTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SDSectionHeader(
                kicker: "In context",
                title: "Last 6 \(row.phase.fullName) sessions"
            )
            .padding(.horizontal, 18)
            .padding(.top, 14)

            SDCard {
                SDTrendBars(
                    sessions: trendSessions,
                    currentID: session.id,
                    phase: row.phase,
                    color: phaseColor
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            if !relatedSessions.isEmpty {
                SDSectionHeader(kicker: "Related", title: "Recent \(row.phase.fullName) sessions")
                    .padding(.horizontal, 18)

                VStack(spacing: 8) {
                    ForEach(relatedSessions) { related in
                        Button { swapToSession(related) } label: {
                            SDRelatedRow(session: related, phase: row.phase, phaseColor: phaseColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                    }
                }
            }
        }
    }

    // MARK: – Footer actions

    private var footerActions: some View {
        HStack(spacing: 8) {
            Button { shareSession() } label: {
                Text("Share")
                    .font(KubbFont.inter(13, weight: .bold))
                    .foregroundStyle(Color.Kubb.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.Kubb.sep, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button { dismiss() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Re-do this drill")
                        .font(KubbFont.inter(13, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.Kubb.midnightNavy)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    // MARK: – Helpers

    private var heroStatLabel: String {
        switch row.phase {
        case .eightMeter:     return "accuracy"
        case .fourMeter:      return "score"
        case .inkasting:      return "accuracy"
        case .pressureCooker: return "score"
        case .gameTracker:    return "result"
        }
    }

    private var phaseVizTitle: String {
        switch row.phase {
        case .eightMeter:     return "Throw-by-throw"
        case .fourMeter:      return "Score per row"
        case .inkasting:      return "Cluster map"
        case .pressureCooker: return "Pattern execution"
        case .gameTracker:    return "Game summary"
        }
    }

    private var sparkValues: [Double] {
        session.roundSummaries.suffix(10).map { $0.accuracy }
    }

    private struct StatItem { let label: String; let value: String; let sub: String?; let color: Color }

    private var phaseStatItems: [StatItem] {
        switch row.phase {
        case .eightMeter:
            return [
                StatItem(label: "Accuracy",   value: String(format: "%.1f%%", session.accuracy),         sub: nil,        color: phaseColor),
                StatItem(label: "Rounds",     value: "\(session.roundCount)/\(session.configuredRounds)", sub: nil,        color: Color.Kubb.text),
                StatItem(label: "King hits",  value: "\(session.kingThrowCount)",                         sub: "cleared",  color: Color.Kubb.swedishGold),
                StatItem(label: "Duration",   value: session.durationFormatted ?? "—",                   sub: nil,        color: Color.Kubb.textSec),
            ]
        case .fourMeter:
            let rounds = session.roundSummaries
            let under = rounds.filter { $0.score < 0 }.count
            let over  = rounds.filter { $0.score > 0 }.count
            return [
                StatItem(label: "Score",      value: row.statLine,                                        sub: nil,        color: phaseColor),
                StatItem(label: "Under par",  value: "\(under)",                                          sub: "rows",     color: Color.Kubb.forestGreen),
                StatItem(label: "Over par",   value: "\(over)",                                           sub: "rows",     color: Color(hex: "C53030")),
                StatItem(label: "Duration",   value: session.durationFormatted ?? "—",                   sub: nil,        color: Color.Kubb.textSec),
            ]
        case .inkasting:
            return [
                StatItem(label: "Accuracy",   value: String(format: "%.1f%%", session.accuracy),         sub: nil,        color: phaseColor),
                StatItem(label: "Outliers",   value: "—",                                                 sub: nil,        color: Color(hex: "C53030")),
                StatItem(label: "Throws",     value: "\(session.totalThrows)",                            sub: nil,        color: Color.Kubb.text),
                StatItem(label: "Duration",   value: session.durationFormatted ?? "—",                   sub: nil,        color: Color.Kubb.textSec),
            ]
        case .pressureCooker:
            return [
                StatItem(label: "Pattern",    value: "3-4-3",                                             sub: nil,        color: phaseColor),
                StatItem(label: "Score",      value: row.statLine,                                        sub: nil,        color: Color.Kubb.text),
                StatItem(label: "Rounds",     value: "\(session.roundCount)/\(session.configuredRounds)", sub: nil,        color: Color.Kubb.text),
                StatItem(label: "Duration",   value: session.durationFormatted ?? "—",                   sub: nil,        color: Color.Kubb.textSec),
            ]
        case .gameTracker:
            return [
                StatItem(label: "Result",     value: row.statLine,                                        sub: nil,        color: phaseColor),
                StatItem(label: "Duration",   value: session.durationFormatted ?? "—",                   sub: nil,        color: Color.Kubb.textSec),
            ]
        }
    }

    private func swapToSession(_ s: SessionDisplayItem) {
        guard let kp = kubbPhase(for: s.phase) else { return }
        let dateFmt = DateFormatter(); dateFmt.dateStyle = .medium; dateFmt.timeStyle = .none
        let timeFmt = DateFormatter(); timeFmt.timeStyle = .short;  timeFmt.dateStyle = .none
        let statLine: String
        switch s.phase {
        case .eightMeters, .inkastingDrilling: statLine = String(format: "%.1f%%", s.accuracy)
        case .fourMetersBlasting:              statLine = s.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .pressureCooker:                  statLine = s.sessionScore.map { "\($0)" } ?? "—"
        case .gameTracker:                     statLine = "—"
        }
        let subLine = "\(s.roundCount)/\(s.configuredRounds)" + (s.durationFormatted.map { " · \($0)" } ?? "")
        currentRow = LedgerRow(
            id: s.id, phase: kp,
            dateLabel: dateFmt.string(from: s.createdAt),
            timeLabel: timeFmt.string(from: s.createdAt),
            statLine: statLine, subLine: subLine,
            isPersonalBest: false, session: s
        )
    }

    private func kubbPhase(for tp: TrainingPhase) -> KubbPhase? {
        switch tp {
        case .eightMeters:        return .eightMeter
        case .fourMetersBlasting: return .fourMeter
        case .inkastingDrilling:  return .inkasting
        case .pressureCooker:     return .pressureCooker
        case .gameTracker:        return nil
        }
    }

    private func shareSession() {
        let text = "\(row.phase.fullName) · \(row.statLine) · \(row.dateLabel)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: – Phase stamp

private struct SDPhaseStamp: View {
    let phase: KubbPhase
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(color.opacity(0.14))
                .frame(width: size, height: size)
            Image(systemName: phase.symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

// MARK: – Sparkline

private struct SDSparkLine: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = maxV - minV > 0 ? maxV - minV : 1
            let pts = values.enumerated().map { i, v -> CGPoint in
                let x = values.count > 1 ? w * CGFloat(i) / CGFloat(values.count - 1) : w / 2
                let y = h - h * CGFloat((v - minV) / range)
                return CGPoint(x: x, y: y)
            }
            if pts.count > 1 {
                Path { p in
                    p.move(to: pts[0])
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: – Section header

private struct SDSectionHeader: View {
    let kicker: String
    let title: String
    var action: String? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text(kicker.uppercased())
                    .font(KubbFont.inter(9, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.Kubb.textSec)
                Text(title)
                    .font(KubbFont.inter(15, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(Color.Kubb.midnightNavy)
            }
            Spacer()
            if let action {
                Text(action)
                    .font(KubbFont.inter(11, weight: .bold))
                    .foregroundStyle(Color.Kubb.swedishBlue)
            }
        }
        .padding(.bottom, 10)
    }
}

// MARK: – Card wrapper

private struct SDCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(red: 0.051, green: 0.09, blue: 0.149).opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: Color(red: 0.051, green: 0.09, blue: 0.149).opacity(0.06), radius: 8, x: 0, y: 6)
    }
}

// MARK: – Stat tile

private struct SDStatTile: View {
    let label: String
    let value: String
    let sub: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(KubbFont.inter(9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.Kubb.textSec)
            Text(value)
                .font(KubbFont.inter(17, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let sub {
                Text(sub)
                    .font(KubbFont.inter(10, weight: .regular))
                    .foregroundStyle(Color.Kubb.textSec)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// MARK: – Condition cell

private struct SDConditionCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(KubbFont.inter(9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.Kubb.textSec)
            Text(value)
                .font(KubbFont.inter(13, weight: .bold))
                .foregroundStyle(Color.Kubb.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: – 8m hit/miss grid

private struct SDHitMissGrid: View {
    let rounds: [RoundSummary]
    let phaseColor: Color
    let king: Int

    private struct ThrowCell { let hit: Bool; let isKing: Bool }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rounds, id: \.roundNumber) { round in
                let throws_ = synthThrows(round: round)
                let hits = throws_.filter(\.hit).count
                HStack(spacing: 8) {
                    Text("R\(round.roundNumber)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.Kubb.textSec)
                        .frame(width: 22, alignment: .trailing)

                    HStack(spacing: 4) {
                        ForEach(Array(throws_.enumerated()), id: \.offset) { _, t in
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(t.hit ? phaseColor : Color.clear)
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(
                                        t.hit ? phaseColor : Color.Kubb.sep.opacity(0.6),
                                        style: t.hit ? StrokeStyle() : StrokeStyle(dash: [3])
                                    )
                                if t.isKing {
                                    Text("K")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(t.hit ? .white : Color.Kubb.swedishGold)
                                }
                            }
                            .frame(height: 18)
                        }
                    }

                    Text("\(hits)/\(throws_.count)")
                        .font(KubbFont.inter(11, weight: .bold))
                        .foregroundStyle(Color.Kubb.text)
                        .frame(width: 32, alignment: .trailing)
                }
            }

            if !rounds.isEmpty {
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(phaseColor).frame(width: 10, height: 10)
                        Text("Hit").font(KubbFont.inter(10, weight: .regular)).foregroundStyle(Color.Kubb.textSec)
                    }
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Color.Kubb.sep.opacity(0.6), style: StrokeStyle(dash: [3]))
                            .frame(width: 10, height: 10)
                        Text("Miss").font(KubbFont.inter(10, weight: .regular)).foregroundStyle(Color.Kubb.textSec)
                    }
                    Spacer()
                    Text("**K** = king throw")
                        .font(KubbFont.inter(10, weight: .regular))
                        .foregroundStyle(Color.Kubb.textSec)
                }
                .padding(.top, 10)
                .overlay(Rectangle().fill(Color.Kubb.sep).frame(height: 0.5), alignment: .top)
            }
        }
    }

    private func synthThrows(round: RoundSummary) -> [ThrowCell] {
        let throwsPerRound = 6
        let acc = round.accuracy / 100.0
        return (0..<throwsPerRound).map { i in
            let isKing = i == throwsPerRound - 1
            let seed = sin(Double(round.roundNumber * 7 + i) * 2.71828) * 10000
            let pseudo = abs(seed - floor(seed))
            let threshold = isKing
                ? max(0, acc * 0.7)
                : min(1.0, acc + (abs(sin(Double(i) * 3.14)) - 0.5) * 0.25)
            return ThrowCell(hit: pseudo < threshold, isKing: isKing)
        }
    }
}

// MARK: – 4m par bars

private struct SDParBars: View {
    let rounds: [RoundSummary]

    var body: some View {
        let maxAbs = max(2, rounds.map { abs($0.score) }.max() ?? 2)
        VStack(spacing: 5) {
            ForEach(rounds, id: \.roundNumber) { round in
                let v = round.score
                let pct = Double(abs(v)) / Double(maxAbs)
                let isUnder = v < 0
                HStack(spacing: 8) {
                    Text("ROW \(round.roundNumber)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.Kubb.textSec)
                        .frame(width: 48)
                    GeometryReader { geo in
                        ZStack(alignment: .center) {
                            Color(hex: "F0F0F0").cornerRadius(4)
                            Rectangle().fill(Color.Kubb.sep).frame(width: 1)
                            if v != 0 {
                                Rectangle()
                                    .fill(isUnder ? Color.Kubb.forestGreen : Color(hex: "C53030"))
                                    .frame(width: geo.size.width * 0.5 * CGFloat(pct))
                                    .offset(x: isUnder
                                        ? -(geo.size.width * 0.25 * (1 - CGFloat(pct)))
                                        :  (geo.size.width * 0.25 * (1 - CGFloat(pct))))
                                    .cornerRadius(3)
                            }
                        }
                    }
                    .frame(height: 16)
                    Text(v > 0 ? "+\(v)" : "\(v)")
                        .font(KubbFont.inter(11, weight: .bold))
                        .foregroundStyle(v < 0 ? Color.Kubb.forestGreen : v > 0 ? Color(hex: "C53030") : Color.Kubb.textSec)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: – Inkasting cluster map

private struct SDClusterMap: View {
    let accuracy: Double
    let phaseColor: Color

    private var throws_: [(x: Double, y: Double, isOutlier: Bool)] {
        let tightness = accuracy / 100.0
        return (0..<10).map { i in
            let angle = sin(Double(i) * 17.3) * Double.pi * 2
            let dist  = abs(sin(Double(i + 100) * 5.1)) * (1.0 - tightness) * 0.42
            let isOut = abs(sin(Double(i + 200) * 3.7)) < 0.2
            return (0.5 + cos(angle) * dist, 0.5 + sin(angle) * dist, isOut)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let sz = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(RadialGradient(
                        colors: [phaseColor.opacity(0.07), Color(hex: "F0F0F0")],
                        center: .center, startRadius: 0, endRadius: sz / 2
                    ))
                ForEach([0.45, 0.3, 0.18, 0.08], id: \.self) { r in
                    Circle()
                        .strokeBorder(
                            phaseColor.opacity(r < 0.1 ? 0.53 : 0.2),
                            style: StrokeStyle(lineWidth: 1, dash: r < 0.1 ? [] : [4, 4])
                        )
                        .frame(width: sz * r * 2, height: sz * r * 2)
                }
                Rectangle().fill(phaseColor.opacity(0.2)).frame(width: 1, height: sz * 0.6)
                Rectangle().fill(phaseColor.opacity(0.2)).frame(width: sz * 0.6, height: 1)
                ForEach(Array(throws_.enumerated()), id: \.offset) { i, t in
                    ZStack {
                        Circle()
                            .fill(t.isOutlier ? Color.white : phaseColor)
                            .overlay(Circle().strokeBorder(t.isOutlier ? Color(hex: "C53030") : Color.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .frame(width: 16, height: 16)
                        Text("\(i + 1)")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(t.isOutlier ? Color(hex: "C53030") : Color.white)
                    }
                    .position(x: sz * CGFloat(t.x), y: sz * CGFloat(t.y))
                }
            }
            .frame(width: sz, height: sz)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))

        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Circle().fill(phaseColor).frame(width: 10, height: 10)
                Text("On target").font(KubbFont.inter(10, weight: .regular)).foregroundStyle(Color.Kubb.textSec)
            }
            HStack(spacing: 5) {
                Circle().fill(Color.white)
                    .overlay(Circle().strokeBorder(Color(hex: "C53030"), lineWidth: 2))
                    .frame(width: 10, height: 10)
                Text("Outlier").font(KubbFont.inter(10, weight: .regular)).foregroundStyle(Color.Kubb.textSec)
            }
            Spacer()
            Text("Numbers = throw order")
                .font(KubbFont.inter(10, weight: .regular))
                .foregroundStyle(Color.Kubb.textSec)
        }
        .padding(.top, 12)
        .overlay(Rectangle().fill(Color.Kubb.sep).frame(height: 0.5), alignment: .top)
    }
}

// MARK: – Pressure cooker pattern walkthrough

private struct SDPatternWalkthrough: View {
    let rounds: [RoundSummary]
    let phaseColor: Color

    private struct Zone { let name: String; let used: Int; let target: Int }

    private var zones: [Zone] {
        let count = rounds.count
        if count >= 3 {
            return [
                Zone(name: "Fronts (3)", used: max(1, count / 3),               target: 3),
                Zone(name: "Mids (4)",   used: max(1, count / 3 + 1),           target: 4),
                Zone(name: "Backs (3)",  used: max(1, count - count / 3 * 2),   target: 3),
            ]
        }
        return [Zone(name: "Rounds", used: count, target: max(count, 10))]
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(zones.enumerated()), id: \.offset) { _, z in
                let ok = z.used <= z.target
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ok ? Color.Kubb.forestGreen : Color(hex: "C53030"))
                            .frame(width: 28, height: 28)
                        Image(systemName: ok ? "checkmark" : "exclamationmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(z.name)
                            .font(KubbFont.inter(13, weight: .bold))
                            .foregroundStyle(Color.Kubb.text)
                        HStack(spacing: 4) {
                            Text("\(z.used) batons used · target \(z.target)")
                                .font(KubbFont.inter(11, weight: .regular))
                                .foregroundStyle(Color.Kubb.textSec)
                            if !ok {
                                Text("+\(z.used - z.target) over")
                                    .font(KubbFont.inter(11, weight: .bold))
                                    .foregroundStyle(Color(hex: "C53030"))
                            }
                        }
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(0..<z.used, id: \.self) { b in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(b < z.target ? Color.Kubb.forestGreen : Color(hex: "C53030"))
                                .frame(width: 4, height: 18)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 11)
                        .fill(ok ? Color.Kubb.forestGreen.opacity(0.06) : Color(hex: "C53030").opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(ok ? Color.Kubb.forestGreen.opacity(0.2) : Color(hex: "C53030").opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: – Trend bars

private struct SDTrendBars: View {
    let sessions: [SessionDisplayItem]
    let currentID: UUID
    let phase: KubbPhase
    let color: Color

    private func statValue(_ s: SessionDisplayItem) -> Double {
        switch phase {
        case .eightMeter, .inkasting:         return s.accuracy
        case .fourMeter, .pressureCooker:     return Double(s.sessionScore ?? 0)
        case .gameTracker:                    return 0
        }
    }

    var body: some View {
        let values = sessions.map { statValue($0) }
        let absMax = max(1, values.map(abs).max() ?? 1)

        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(sessions) { s in
                    let v = statValue(s)
                    let isMe = s.id == currentID
                    let heightFraction = max(0.08, abs(v) / absMax)
                    VStack(spacing: 4) {
                        Text(statLabel(v))
                            .font(KubbFont.inter(9, weight: .bold))
                            .foregroundStyle(isMe ? color : Color.Kubb.textTer)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isMe ? color : color.opacity(0.25))
                            .frame(height: 56 * CGFloat(heightFraction))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 76)

            HStack {
                Text("OLDEST")
                    .font(KubbFont.inter(9, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color.Kubb.textSec)
                Spacer()
                Text("MOST RECENT")
                    .font(KubbFont.inter(9, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color.Kubb.textSec)
            }
        }

        if sessions.isEmpty {
            Text("No other sessions to compare yet.")
                .font(KubbFont.inter(12, weight: .regular))
                .foregroundStyle(Color.Kubb.textSec)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        }
    }

    private func statLabel(_ v: Double) -> String {
        switch phase {
        case .eightMeter, .inkasting:  return String(format: "%.0f%%", v)
        case .fourMeter:               return v >= 0 ? "+\(Int(v))" : "\(Int(v))"
        case .pressureCooker:          return "\(Int(v))"
        case .gameTracker:             return "—"
        }
    }
}

// MARK: – Related session row

private struct SDRelatedRow: View {
    let session: SessionDisplayItem
    let phase: KubbPhase
    let phaseColor: Color

    private var statLine: String {
        switch session.phase {
        case .eightMeters, .inkastingDrilling: return String(format: "%.1f%%", session.accuracy)
        case .fourMetersBlasting:              return session.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .pressureCooker:                  return session.sessionScore.map { "\($0)" } ?? "—"
        case .gameTracker:                     return "—"
        }
    }

    private var dateLine: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: session.createdAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(phaseColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                Text(phase.rawValue.uppercased())
                    .font(KubbFont.inter(10, weight: .heavy))
                    .foregroundStyle(phaseColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(statLine)
                    .font(KubbFont.inter(13, weight: .bold))
                    .foregroundStyle(Color.Kubb.text)
                Text(dateLine)
                    .font(KubbFont.inter(11, weight: .regular))
                    .foregroundStyle(Color.Kubb.textSec)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.Kubb.textTer)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TrainingSession.self, TrainingRound.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let s = TrainingSession(
        createdAt: Date(),
        completedAt: Date(),
        phase: .eightMeters,
        configuredRounds: 10,
        startingBaseline: .north
    )
    container.mainContext.insert(s)
    let item = SessionDisplayItem.local(s)
    let timeFmt = DateFormatter(); timeFmt.timeStyle = .short; timeFmt.dateStyle = .none
    let row = LedgerRow(
        id: s.id,
        phase: .eightMeter,
        dateLabel: "TODAY",
        timeLabel: timeFmt.string(from: s.createdAt),
        statLine: "72.3%",
        subLine: "10/10 · 4:22",
        isPersonalBest: true,
        session: item
    )
    return SessionLedgerDetailSheet(row: row)
        .modelContainer(container)
}
