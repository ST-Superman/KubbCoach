// SessionLedgerDetailSheet.swift
// V2 "Tabbed compact" session detail — full-bleed gradient hero, sticky 3-tab bar (Overview / Rounds / Compare).

import SwiftUI
import SwiftData

// MARK: – Main view

struct SessionLedgerDetailSheet: View {
    @State private var currentRow: LedgerRow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TrainingSession> { $0.completedAt != nil || $0.deviceType == "Watch" },
        sort: \TrainingSession.createdAt, order: .reverse
    ) private var allLocalSessions: [TrainingSession]

    @State private var activeTab = "overview"
    @State private var noteText = ""
    @FocusState private var noteFocused: Bool

    private static let notesMaxLength = 500

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

    // MARK: – Conditions cell helpers

    private var locationDisplay: String {
        session.locationName ?? "—"
    }

    private var sessionTimeRangeDisplay: String? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let start = formatter.string(from: session.createdAt)
        if let end = session.completedAt {
            return "\(start) – \(formatter.string(from: end))"
        }
        return start
    }

    private var windDisplay: String {
        guard let speed = session.windSpeedMph else { return "—" }
        let rounded = Int(speed.rounded())
        if let direction = session.windDirection, !direction.isEmpty {
            return "\(rounded) mph \(direction)"
        }
        return "\(rounded) mph"
    }

    private var weatherDisplay: String {
        guard let condition = session.weatherCondition else { return "—" }
        if let precip = session.precipitation24hMm, precip > 0.5 {
            return "\(condition) · Recent rain"
        }
        return condition
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
            .background(Color.Kubb.timelineBg)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { noteText = session.localSession?.notes ?? "" }
        .onDisappear { persistNotesIfChanged() }
    }

    private func persistNotesIfChanged() {
        guard let local = session.localSession else { return }
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String? = trimmed.isEmpty ? nil : trimmed
        guard local.notes != newValue else { return }
        local.notes = newValue
        try? modelContext.save()
    }

    // MARK: – Hero block

    private var heroBlock: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                // Back button · context line · PB badge
                HStack(spacing: 8) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
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
                            .font(KubbFont.fraunces(68, weight: .medium))
                            .tracking(-3)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .monospacedDigit()

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

                // Chip row — ROUNDS + DURATION
                HStack(spacing: 8) {
                    PAChip(label: "ROUNDS", value: "\(session.roundCount)/\(session.configuredRounds)")
                    PAChip(label: "DURATION", value: session.durationFormatted ?? "—")
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 52)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(
                LinearGradient(
                    colors: [phaseColor, phaseColor.shaded(by: -0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )

            // Decorative radial gold glow — top-right corner, purely decorative
            Circle()
                .fill(RadialGradient(
                    colors: [Color.Kubb.swedishGold.opacity(0.30), .clear],
                    center: .center, startRadius: 0, endRadius: 90
                ))
                .frame(width: 180, height: 180)
                .offset(x: 40, y: -40)
                .allowsHitTesting(false)
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
            Color.Kubb.timelineBg.opacity(0.92)
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
            SDSectionHeader(num: "01", title: "Where & how", sub: "Conditions", accent: phaseColor)
                .padding(.horizontal, 18)
            SDCard {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    SDConditionCell(
                        label: "Location",
                        value: locationDisplay,
                        subtitle: sessionTimeRangeDisplay
                    )
                    SDConditionCell(label: "Wind", value: windDisplay)
                    SDConditionCell(label: "Weather Conditions", value: weatherDisplay)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("02")
                    .font(KubbFont.mono(9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(phaseColor)
                Text("Notes")
                    .font(KubbFont.inter(13, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.Kubb.text)
                Spacer()
                Text("\(noteText.count) / \(Self.notesMaxLength)")
                    .font(KubbFont.mono(10, weight: .regular))
                    .foregroundStyle(noteText.count >= Self.notesMaxLength ? Color(hex: "C53030") : Color.Kubb.textTer)
            }
            .padding(.horizontal, 18)

            SDCard {
                ZStack(alignment: .topLeading) {
                    if noteText.isEmpty {
                        Text("Add notes about wind, grip, mental cues, anything to remember…")
                            .font(KubbFont.inter(15, weight: .regular))
                            .foregroundStyle(Color.Kubb.textTer)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $noteText)
                        .focused($noteFocused)
                        .font(KubbFont.inter(15, weight: .regular))
                        .foregroundStyle(Color.Kubb.text)
                        .tint(Color.Kubb.swedishBlue)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: noteFocused ? 180 : 110)
                        .animation(.easeInOut(duration: 0.18), value: noteFocused)
                        .onChange(of: noteText) { _, newValue in
                            if newValue.count > Self.notesMaxLength {
                                noteText = String(newValue.prefix(Self.notesMaxLength))
                            }
                        }
                }
            }
            .padding(.horizontal, 18)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        persistNotesIfChanged()
                        noteFocused = false
                    }
                    .font(KubbFont.inter(14, weight: .bold))
                    .foregroundStyle(Color.Kubb.swedishBlue)
                }
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: – Rounds tab

    private var roundsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SDSectionHeader(num: "01", title: phaseVizTitle, sub: "Round breakdown", accent: phaseColor)
                .padding(.horizontal, 18)
                .padding(.top, 14)

            SDCard { phaseVizBody }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            // 8m: per-kubb stat strip (best/worst kubb + streak)
            if row.phase == .eightMeter {
                perKubbStrip
            }

            // 4m: stat strip (best/worst round + under par)
            if row.phase == .fourMeter {
                fourMeterStatStrip
            }

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
                        value: "\(session.kingThrowHits)/\(session.kingThrowCount)",
                        sub: session.kingThrowCount == 0 ? "no attempts" : nil,
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
            SDHitMissGrid(rounds: session.roundSummaries, phaseColor: phaseColor)
        case .fourMeter:
            SDParBars(rounds: session.roundSummaries)
        case .inkasting:
            SDClusterMap(
                analyses: session.localSession?.fetchInkastingAnalyses(context: modelContext) ?? [],
                phaseColor: phaseColor
            )
        case .pressureCooker, .pressureCooker343, .pressureCookerInTheRed:
            SDPatternWalkthrough(rounds: session.roundSummaries, phaseColor: phaseColor)
        case .gameTracker:
            EmptyView()
        }
    }

    // MARK: – Compare tab

    private var compareTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            SDSectionHeader(
                num: "01",
                title: "Last 6 \(row.phase.fullName) sessions",
                sub: "In context",
                accent: phaseColor
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
                SDSectionHeader(num: "02", title: "Recent \(row.phase.fullName) sessions", sub: "Related", accent: phaseColor)
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
                    .background(Color.Kubb.card)
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
        case .eightMeter:             return "accuracy"
        case .fourMeter:              return "score"
        case .inkasting:              return "cluster radius"
        case .pressureCooker,
             .pressureCooker343,
             .pressureCookerInTheRed: return "score"
        case .gameTracker:            return "result"
        }
    }

    private var phaseVizTitle: String {
        switch row.phase {
        case .eightMeter:             return "Throw-by-throw"
        case .fourMeter:              return "Score per row"
        case .inkasting:              return "Cluster map"
        case .pressureCooker,
             .pressureCooker343,
             .pressureCookerInTheRed: return "Pattern execution"
        case .gameTracker:            return "Game summary"
        }
    }

    private var sparkValues: [Double] {
        session.roundSummaries.suffix(10).map { $0.accuracy }
    }

    // MARK: – Stat strip helpers

    private func longestHitStreak(from ts: TrainingSession) -> Int {
        var maxStreak = 0, cur = 0
        for round in ts.rounds.sorted(by: { $0.roundNumber < $1.roundNumber }) {
            for t in round.throwRecords.sorted(by: { $0.throwNumber < $1.throwNumber })
            where t.targetType == .baselineKubb {
                if t.result == .hit { cur += 1; maxStreak = max(maxStreak, cur) }
                else { cur = 0 }
            }
        }
        return maxStreak
    }

    @ViewBuilder private var perKubbStrip: some View {
        if let ts = session.localSession {
            let kubbs = PhaseAnalysisData.perKubbStats(from: [ts])
                .filter { $0.label != "King" && $0.throwCount > 0 }
            if kubbs.count >= 2,
               let best = kubbs.max(by: { $0.rate < $1.rate }),
               let worst = kubbs.min(by: { $0.rate < $1.rate }) {
                let streak = longestHitStreak(from: ts)
                HStack(spacing: 8) {
                    StatStripTile(label: "BEST KUBB", value: "\(best.label) · \(best.rate)%", valueColor: phaseColor)
                    StatStripTile(label: "WORST KUBB", value: "\(worst.label) · \(worst.rate)%", valueColor: nil)
                    StatStripTile(label: "STREAK", value: "\(streak) hit\(streak == 1 ? "" : "s")", valueColor: nil)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder private var fourMeterStatStrip: some View {
        if !session.roundSummaries.isEmpty {
            let scores = session.roundSummaries.map { $0.score }
            if let bestScore = scores.min(), let worstScore = scores.max() {
                let underPar = scores.filter { $0 < 0 }.count
                let bestStr = bestScore > 0 ? "+\(bestScore)" : "\(bestScore)"
                let worstStr = worstScore > 0 ? "+\(worstScore)" : "\(worstScore)"
                HStack(spacing: 8) {
                    StatStripTile(label: "BEST ROUND", value: bestStr, valueColor: phaseColor)
                    StatStripTile(label: "WORST ROUND", value: worstStr, valueColor: nil)
                    StatStripTile(label: "UNDER PAR", value: "\(underPar)/\(scores.count)", valueColor: nil)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
    }

    private struct StatItem { let label: String; let value: String; let sub: String?; let color: Color }

    private var phaseStatItems: [StatItem] {
        switch row.phase {
        case .eightMeter:
            return [
                StatItem(label: "Accuracy",   value: String(format: "%.1f%%", session.accuracy),         sub: nil,        color: phaseColor),
                StatItem(label: "Rounds",     value: "\(session.roundCount)/\(session.configuredRounds)", sub: nil,        color: Color.Kubb.text),
                StatItem(label: "King hits",  value: "\(session.kingThrowHits)/\(session.kingThrowCount)", sub: session.kingThrowCount == 0 ? "no attempts" : "cleared", color: Color.Kubb.swedishGold),
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
            let radius = session.averageClusterRadius(context: modelContext)
            return [
                StatItem(label: "Cluster radius", value: radius.map { String(format: "%.2fm", $0) } ?? "—", sub: nil, color: phaseColor),
                StatItem(label: "Outliers",   value: "—",                                                 sub: nil,        color: Color(hex: "C53030")),
                StatItem(label: "Throws",     value: "\(session.totalThrows)",                            sub: nil,        color: Color.Kubb.text),
                StatItem(label: "Duration",   value: session.durationFormatted ?? "—",                   sub: nil,        color: Color.Kubb.textSec),
            ]
        case .pressureCooker, .pressureCooker343, .pressureCookerInTheRed:
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
        case .eightMeters:        statLine = String(format: "%.1f%%", s.accuracy)
        case .inkastingDrilling:
            statLine = s.averageClusterRadius(context: modelContext)
                .map { String(format: "%.2fm", $0) } ?? "—"
        case .fourMetersBlasting: statLine = s.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .pressureCooker:     statLine = s.sessionScore.map { "\($0)" } ?? "—"
        case .gameTracker:        statLine = "—"
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

    @MainActor
    private func shareSession() {
        let items: [Any] = shareActivityItems()
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        av.popoverPresentationController?.sourceView = presenter.view
        presenter.present(av, animated: true)
    }

    @MainActor
    private func shareActivityItems() -> [Any] {
        let fallbackText = "\(row.phase.fullName) · \(row.statLine) · \(row.dateLabel)"

        guard case .local(let trainingSession) = session else {
            return [fallbackText]
        }

        let descriptor = FetchDescriptor<PersonalBest>()
        let allBests = (try? modelContext.fetch(descriptor)) ?? []
        let pbs = allBests.filter { trainingSession.newPersonalBests.contains($0.id) }

        let data = trainingSession.shareCardData(context: modelContext, personalBests: pbs)
        if let image = ShareCardView(data: data).renderImage() {
            return [image]
        }
        return [fallbackText]
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
            phase.glyph(size: size * 0.55, weight: .bold)
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

struct SDSectionHeader: View {
    let num: String
    let title: String
    var sub: String = ""
    var accent: Color = Color.Kubb.textSec

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(num)
                .font(KubbFont.mono(9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(accent)
            Text(title)
                .font(KubbFont.inter(13, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(Color.Kubb.text)
            Spacer()
            if !sub.isEmpty {
                Text(sub)
                    .font(KubbFont.mono(9, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(Color.Kubb.textSec)
            }
        }
        .padding(.bottom, 10)
    }
}

// MARK: – Card wrapper

struct SDCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Kubb.card)
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
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// MARK: – Condition cell

struct SDConditionCell: View {
    let label: String
    let value: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(KubbFont.inter(9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.Kubb.textSec)
            Text(value)
                .font(KubbFont.inter(13, weight: .bold))
                .foregroundStyle(Color.Kubb.text)
            if let subtitle {
                Text(subtitle)
                    .font(KubbFont.inter(11, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: – 8m hit/miss grid

private struct SDHitMissGrid: View {
    let rounds: [RoundSummary]
    let phaseColor: Color

    private enum Cell {
        case thrown(hit: Bool, isKing: Bool)
        case empty
    }

    private static let cellsPerRow = 6

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rounds, id: \.roundNumber) { round in
                let cells = cells(for: round)
                let hits = round.throwBreakdowns.filter(\.isHit).count
                let attempts = round.throwBreakdowns.count
                HStack(spacing: 8) {
                    Text("R\(round.roundNumber)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.Kubb.textSec)
                        .frame(width: 22, alignment: .trailing)

                    HStack(spacing: 4) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                            cellView(cell)
                                .frame(height: 18)
                        }
                    }

                    Text("\(hits)/\(attempts)")
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

    @ViewBuilder
    private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .thrown(let hit, let isKing):
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(hit ? phaseColor : Color.clear)
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        hit ? phaseColor : Color.Kubb.sep.opacity(0.6),
                        style: hit ? StrokeStyle() : StrokeStyle(dash: [3])
                    )
                if isKing {
                    Text("K")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(hit ? .white : Color.Kubb.swedishGold)
                }
            }
        case .empty:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.Kubb.sep.opacity(0.12))
        }
    }

    /// Builds a fixed-width row: one cell per real throw, padded with
    /// muted placeholders out to `cellsPerRow` so every row aligns.
    private func cells(for round: RoundSummary) -> [Cell] {
        var cells = round.throwBreakdowns.map { Cell.thrown(hit: $0.isHit, isKing: $0.isKing) }
        if cells.count < Self.cellsPerRow {
            cells.append(contentsOf: Array(repeating: Cell.empty, count: Self.cellsPerRow - cells.count))
        }
        return cells
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
                            Color(.systemGray5).cornerRadius(4)
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
//
// Renders the single-session cluster map using real InkastingAnalysis data.
// Centers each throw on its analysis's clusterCenter (matching the per-analysis
// centering used by PhaseAnalysisView's PAInkastingClusterMap), then forwards
// to that same view so the two stay visually consistent.

private struct SDClusterMap: View {
    let analyses: [InkastingAnalysis]
    let phaseColor: Color

    private struct ClusterData {
        let throws_: [InkastingThrow]
        let targetRadiusNorm: Double
        let targetRadiusLabel: String
        let outlierCount: Int
    }

    private var cluster: ClusterData {
        var throws_: [InkastingThrow] = []
        var coreDeltaSqNorm: [Double] = []
        var coreMeanDistances: [Double] = []
        var radii: [Double] = []

        for a in analyses {
            let cx = a.clusterCenterX, cy = a.clusterCenterY
            let outlierSet = Set(a.outlierIndices)
            for (i, pt) in a.kubbPositions.enumerated() {
                let dx = pt.x - cx, dy = pt.y - cy
                let isOutlier = outlierSet.contains(i)
                throws_.append(InkastingThrow(xRel: dx, yRel: dy, isOutlier: isOutlier))
                if !isOutlier { coreDeltaSqNorm.append(dx * dx + dy * dy) }
            }
            if a.meanCoreDistance > 0 { coreMeanDistances.append(a.meanCoreDistance) }
            radii.append(a.clusterRadiusMeters)
        }

        let avgRadius = radii.isEmpty ? 0.0 : radii.reduce(0, +) / Double(radii.count)
        let rmsNorm = coreDeltaSqNorm.isEmpty ? 0.0
            : sqrt(coreDeltaSqNorm.reduce(0, +) / Double(coreDeltaSqNorm.count))
        let avgMeanCoreDist = coreMeanDistances.isEmpty ? 0.0
            : coreMeanDistances.reduce(0, +) / Double(coreMeanDistances.count)
        let targetRadiusNorm: Double
        if avgMeanCoreDist > 0 && rmsNorm > 0 {
            targetRadiusNorm = avgRadius * (rmsNorm / avgMeanCoreDist)
        } else {
            targetRadiusNorm = 0.04
        }

        let outlierCount = throws_.filter { $0.isOutlier }.count
        let label = analyses.isEmpty ? "—" : String(format: "%.2fm", avgRadius)
        return ClusterData(
            throws_: throws_,
            targetRadiusNorm: targetRadiusNorm,
            targetRadiusLabel: label,
            outlierCount: outlierCount
        )
    }

    var body: some View {
        let data = cluster
        if data.throws_.isEmpty {
            // No analyses to render — show a friendly empty state instead of
            // a synthesized blob.
            VStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Color.Kubb.textTer)
                Text("No cluster data for this session")
                    .font(KubbFont.inter(11, weight: .regular))
                    .foregroundStyle(Color.Kubb.textSec)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(4/3, contentMode: .fit)
            .background(Color.Kubb.fieldMap)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m))
        } else {
            PAInkastingClusterMap(
                throwPoints: data.throws_,
                targetRadiusNorm: data.targetRadiusNorm,
                targetRadiusLabel: data.targetRadiusLabel,
                outlierCount: data.outlierCount,
                phaseColor: phaseColor
            )
        }
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
        case .eightMeter, .inkasting:
            return s.accuracy
        case .fourMeter,
             .pressureCooker,
             .pressureCooker343,
             .pressureCookerInTheRed:
            return Double(s.sessionScore ?? 0)
        case .gameTracker:
            return 0
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
        case .eightMeter, .inkasting:
            return String(format: "%.0f%%", v)
        case .fourMeter:
            return v >= 0 ? "+\(Int(v))" : "\(Int(v))"
        case .pressureCooker,
             .pressureCooker343,
             .pressureCookerInTheRed:
            return "\(Int(v))"
        case .gameTracker:
            return "—"
        }
    }
}

// MARK: – Related session row

private struct SDRelatedRow: View {
    let session: SessionDisplayItem
    let phase: KubbPhase
    let phaseColor: Color

    @Environment(\.modelContext) private var modelContext

    private var statLine: String {
        switch session.phase {
        case .eightMeters:        return String(format: "%.1f%%", session.accuracy)
        case .inkastingDrilling:
            return session.averageClusterRadius(context: modelContext)
                .map { String(format: "%.2fm", $0) } ?? "—"
        case .fourMetersBlasting: return session.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .pressureCooker:     return session.sessionScore.map { "\($0)" } ?? "—"
        case .gameTracker:        return "—"
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
        .background(Color.Kubb.card)
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
