// JourneyTimelineView.swift
// Full-screen session history with phase/range filters, sticky month headers,
// and a vertical-rail day-group timeline. Reached by tapping the Journey heatmap card.

import SwiftUI
import SwiftData

// MARK: – Filter enums

enum TimelinePhaseFilter: String, Hashable, CaseIterable {
    case all, eightMeter, fourMeter, inkasting, pressure, gameTracker, pbOnly

    var label: String {
        switch self {
        case .all:         return "All"
        case .eightMeter:  return "8 Meters"
        case .fourMeter:   return "Blasting"
        case .inkasting:   return "Inkasting"
        case .pressure:    return "Pressure"
        case .gameTracker: return "Games"
        case .pbOnly:      return "★ PBs"
        }
    }

    var color: Color {
        switch self {
        case .all:         return Color.Kubb.midnightNavy
        case .eightMeter:  return Color.Kubb.swedishBlue
        case .fourMeter:   return Color.Kubb.phase4m
        case .inkasting:   return Color.Kubb.forestGreen
        case .pressure:    return Color.Kubb.phasePC
        case .gameTracker: return Color.Kubb.swedishGold
        case .pbOnly:      return Color.Kubb.swedishGold
        }
    }
}

enum TimelineRangeFilter: String, Hashable, CaseIterable {
    case last30, last90, all

    var label: String {
        switch self {
        case .last30: return "30d"
        case .last90: return "90d"
        case .all:    return "All"
        }
    }
}

// MARK: – Scroll offset preference key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: – Unified timeline item

enum JourneyTimelineItem: Identifiable {
    case training(SessionDisplayItem)
    case game(GameSession)
    case pc(PressureCookerSession)

    var id: UUID {
        switch self {
        case .training(let s): return s.id
        case .game(let g):     return g.id
        case .pc(let p):       return p.id
        }
    }

    var createdAt: Date {
        switch self {
        case .training(let s): return s.createdAt
        case .game(let g):     return g.createdAt
        case .pc(let p):       return p.createdAt
        }
    }

    var completedAt: Date? {
        switch self {
        case .training(let s): return s.completedAt
        case .game(let g):     return g.completedAt
        case .pc(let p):       return p.completedAt
        }
    }

    /// KubbPhase used for grouping and stat lenses.
    var kubbPhase: KubbPhase {
        switch self {
        case .training(let s):
            switch s.phase {
            case .eightMeters:        return .eightMeter
            case .fourMetersBlasting: return .fourMeter
            case .inkastingDrilling:  return .inkasting
            case .pressureCooker:     return .pressureCooker
            case .gameTracker:        return .gameTracker
            }
        case .game:                   return .gameTracker
        case .pc:                     return .pressureCooker
        }
    }
}

// MARK: – Main view

struct JourneyTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TrainingSession> { $0.completedAt != nil || $0.deviceType == "Watch" },
        sort: \TrainingSession.createdAt, order: .reverse
    ) private var rawSessions: [TrainingSession]

    @Query(
        filter: #Predicate<GameSession> { $0.completedAt != nil },
        sort: \GameSession.createdAt, order: .reverse
    ) private var rawGameSessions: [GameSession]

    @Query(
        filter: #Predicate<PressureCookerSession> { $0.completedAt != nil },
        sort: \PressureCookerSession.createdAt, order: .reverse
    ) private var rawPCSessions: [PressureCookerSession]

    @State private var phaseFilter: TimelinePhaseFilter = .all
    @State private var rangeFilter: TimelineRangeFilter = .all
    @State private var scrolled = false
    @State private var scrollBaselineY: CGFloat? = nil
    @State private var selectedItem: JourneyTimelineItem? = nil
    @State private var sessionPendingDelete: TrainingSession? = nil

    // MARK: – Data helpers

    private var sessions: [SessionDisplayItem] {
        rawSessions.map { .local($0) }
    }

    /// All session activity unified into JourneyTimelineItem rows.
    private var items: [JourneyTimelineItem] {
        var out: [JourneyTimelineItem] = sessions.map { .training($0) }
        for g in rawGameSessions where g.endReason != GameEndReason.abandoned.rawValue {
            out.append(.game(g))
        }
        for p in rawPCSessions {
            out.append(.pc(p))
        }
        return out.sorted { $0.createdAt > $1.createdAt }
    }

    /// One-per-phase personal-best session IDs (best stat across all time, training sessions only).
    /// Game and PC sessions don't have a fixed per-session PB lens here yet — covered by `.pbOnly` chip via this set only.
    private var pbSessionIDs: Set<UUID> {
        var ids = Set<UUID>()
        let allLocal = sessions.filter { $0.completedAt != nil && $0.roundCount >= $0.configuredRounds }

        // 8m / ink → highest accuracy
        for phase in [TrainingPhase.eightMeters, .inkastingDrilling] {
            if let best = allLocal.filter({ $0.phase == phase }).max(by: { $0.accuracy < $1.accuracy }) {
                ids.insert(best.id)
            }
        }
        // 4m → lowest (best) score
        if let best = allLocal
            .filter({ $0.phase == .fourMetersBlasting && $0.sessionScore != nil })
            .min(by: { ($0.sessionScore ?? 0) < ($1.sessionScore ?? 0) }) {
            ids.insert(best.id)
        }
        // pc (legacy training-phase) → highest score
        if let best = allLocal
            .filter({ $0.phase == .pressureCooker && $0.sessionScore != nil })
            .max(by: { ($0.sessionScore ?? 0) < ($1.sessionScore ?? 0) }) {
            ids.insert(best.id)
        }
        // pc standalone → highest totalScore
        if let best = rawPCSessions.filter({ $0.completedAt != nil }).max(by: { $0.totalScore < $1.totalScore }) {
            ids.insert(best.id)
        }
        return ids
    }

    /// Items after applying the current range filter only (used for chip counts).
    private var rangeFilteredItems: [JourneyTimelineItem] {
        applyRange(to: items)
    }

    /// Items after applying both range and phase filters.
    private var filteredItems: [JourneyTimelineItem] {
        let byRange = applyRange(to: items)
        return applyPhase(to: byRange)
    }

    private func applyRange(to input: [JourneyTimelineItem]) -> [JourneyTimelineItem] {
        let now = Date()
        switch rangeFilter {
        case .last30: return input.filter { now.timeIntervalSince($0.createdAt) <= 30 * 86_400 }
        case .last90: return input.filter { now.timeIntervalSince($0.createdAt) <= 90 * 86_400 }
        case .all:    return input
        }
    }

    private func applyPhase(to input: [JourneyTimelineItem]) -> [JourneyTimelineItem] {
        switch phaseFilter {
        case .all:         return input
        case .eightMeter:  return input.filter { $0.kubbPhase == .eightMeter }
        case .fourMeter:   return input.filter { $0.kubbPhase == .fourMeter }
        case .inkasting:   return input.filter { $0.kubbPhase == .inkasting }
        case .pressure:    return input.filter { $0.kubbPhase == .pressureCooker }
        case .gameTracker: return input.filter { $0.kubbPhase == .gameTracker }
        case .pbOnly:      return input.filter { pbSessionIDs.contains($0.id) }
        }
    }

    private func chipCount(for filter: TimelinePhaseFilter) -> Int {
        switch filter {
        case .all:         return rangeFilteredItems.count
        case .eightMeter:  return rangeFilteredItems.filter { $0.kubbPhase == .eightMeter }.count
        case .fourMeter:   return rangeFilteredItems.filter { $0.kubbPhase == .fourMeter }.count
        case .inkasting:   return rangeFilteredItems.filter { $0.kubbPhase == .inkasting }.count
        case .pressure:    return rangeFilteredItems.filter { $0.kubbPhase == .pressureCooker }.count
        case .gameTracker: return rangeFilteredItems.filter { $0.kubbPhase == .gameTracker }.count
        case .pbOnly:      return rangeFilteredItems.filter { pbSessionIDs.contains($0.id) }.count
        }
    }

    // MARK: – Summary stats (from filtered dataset)

    private var pbCount: Int { filteredItems.filter { pbSessionIDs.contains($0.id) }.count }
    private var distinctPhaseCount: Int { Set(filteredItems.map(\.kubbPhase)).count }
    private var totalMinutes: Int {
        Int(filteredItems.compactMap { item -> TimeInterval? in
            guard let completed = item.completedAt else { return nil }
            return completed.timeIntervalSince(item.createdAt)
        }.reduce(0, +) / 60)
    }

    // MARK: – Day/month grouping

    struct DayGroup: Identifiable {
        let date: Date
        let items: [JourneyTimelineItem]
        var id: Date { date }
        var isToday: Bool { Calendar.current.isDateInToday(date) }
    }

    struct MonthGroup: Identifiable {
        let year: Int
        let month: Int
        let dayGroups: [DayGroup]
        var id: String { "\(year)-\(month)" }

        var headerText: String {
            var comps = DateComponents()
            comps.year = year; comps.month = month; comps.day = 1
            let date = Calendar.current.date(from: comps) ?? Date()
            let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: date).uppercased()
        }
    }

    private var monthGroups: [MonthGroup] {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: filteredItems) { cal.startOfDay(for: $0.createdAt) }
        let dayGroups = byDay.map { date, items in
            DayGroup(date: date, items: items.sorted { $0.createdAt > $1.createdAt })
        }.sorted { $0.date > $1.date }

        let byMonth = Dictionary(grouping: dayGroups) { day -> String in
            let c = cal.dateComponents([.year, .month], from: day.date)
            return "\(c.year!)-\(c.month!)"
        }
        return byMonth.compactMap { key, days -> MonthGroup? in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return MonthGroup(year: parts[0], month: parts[1],
                              dayGroups: days.sorted { $0.date > $1.date })
        }
        .sorted { lhs, rhs in
            lhs.year != rhs.year ? lhs.year > rhs.year : lhs.month > rhs.month
        }
    }

    // MARK: – Body

    var body: some View {
        ZStack(alignment: .top) {
            Color.Kubb.timelineBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                // Invisible anchor at scroll-top for offset detection
                Color.clear
                    .frame(height: 0)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { scrollBaselineY = geo.frame(in: .global).minY }
                                .preference(key: ScrollOffsetPreferenceKey.self,
                                            value: geo.frame(in: .global).minY)
                        }
                    )

                VStack(spacing: 0) {
                    // §1 Volume mini chart
                    VolumeMiniBar(dates: items.map(\.createdAt))
                        .padding(.horizontal, KubbSpacing.xl)
                        .padding(.top, KubbSpacing.m)

                    // §2 Range segmented + session/PB summary
                    HStack(alignment: .center, spacing: KubbSpacing.s2) {
                        RangeSegmentedControl(selected: $rangeFilter)
                        Spacer()
                        summaryText
                    }
                    .padding(.horizontal, KubbSpacing.xl)
                    .padding(.top, KubbSpacing.m2)
                    .padding(.bottom, KubbSpacing.s)

                    // §3 Phase filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: KubbSpacing.xs2) {
                            ForEach(TimelinePhaseFilter.allCases, id: \.self) { filter in
                                TimelineFilterChip(
                                    label: filter.label,
                                    color: filter.color,
                                    count: chipCount(for: filter),
                                    isActive: phaseFilter == filter,
                                    onTap: { withAnimation(.easeInOut(duration: 0.15)) { phaseFilter = filter } }
                                )
                            }
                        }
                        .padding(.horizontal, KubbSpacing.xl)
                        .padding(.vertical, 2)
                    }
                    .padding(.bottom, KubbSpacing.m2)

                    // §4 Summary stat strip
                    statStrip
                        .padding(.horizontal, KubbSpacing.xl)
                        .padding(.bottom, KubbSpacing.xs)

                    // §5 Timeline (or empty state)
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        timelineList
                    }
                }
            }
            // Reserve space for the fixed nav header so sticky section headers
            // pin at the correct offset (96pt from top).
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 96)
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { y in
                guard let baseline = scrollBaselineY else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrolled = y < baseline - 8
                }
            }

            // Fixed nav header overlay
            navHeader
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedItem) { item in
            switch item {
            case .training(let s):
                if let row = ledgerRow(for: s) {
                    SessionLedgerDetailSheet(row: row)
                }
            case .game(let g):
                GameTrackerSummaryView(session: g, isPostGame: false)
            case .pc(let p):
                PCLedgerDetailSheet(session: p)
            }
        }
        .sheet(item: $sessionPendingDelete) { session in
            DeleteSessionConfirmSheet(
                impact: impactSummary(for: session),
                onConfirm: { performDelete(session) }
            )
        }
    }

    // MARK: – Nav header

    private var navHeader: some View {
        ZStack(alignment: .bottom) {
            // Blurred background (fades in once scrolled)
            ZStack {
                Color.Kubb.timelineHeaderBlur
                Rectangle().fill(.ultraThinMaterial)
            }
            .ignoresSafeArea(edges: .top)
            .opacity(scrolled ? 1 : 0)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.Kubb.sep)
                    .frame(height: 0.5)
                    .opacity(scrolled ? 1 : 0)
            }

            // Header content
            HStack(spacing: KubbSpacing.s) {
                // Back button
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.Kubb.swedishBlue)
                        .frame(width: 36, height: 36)
                        .background(Color.Kubb.card)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
                }

                // Title block
                VStack(alignment: .leading, spacing: 1) {
                    Text("TRAINING VOLUME")
                        .font(KubbFont.inter(10, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(Color.Kubb.textSec)
                    Text("Timeline")
                        .font(KubbFont.inter(20, weight: .heavy))
                        .tracking(-0.4)
                        .foregroundStyle(Color.Kubb.midnightNavy)
                }

                Spacer()

                // Search button (stub — out of scope)
                Button { } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                        .frame(width: 36, height: 36)
                        .background(Color.Kubb.card)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
                }
            }
            .padding(.top, 52)
            .padding(.bottom, KubbSpacing.s2)
            .padding(.leading, KubbSpacing.l)
            .padding(.trailing, KubbSpacing.xl)
        }
        .frame(height: 96 + 44) // extra for status bar behind ignoresSafeArea
        .ignoresSafeArea(edges: .top)
    }

    // MARK: – Summary text (range header)

    private var summaryText: some View {
        HStack(spacing: 4) {
            Text("\(filteredItems.count) sessions")
                .font(KubbFont.inter(12, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
            if pbCount > 0 {
                Text("· \(pbCount) PB")
                    .font(KubbFont.inter(12, weight: .bold))
                    .foregroundStyle(Color.Kubb.pbInk)
            }
        }
    }

    // MARK: – Stat strip

    private var statStrip: some View {
        HStack(spacing: KubbSpacing.s) {
            StatStripCell(label: "Sessions", value: "\(filteredItems.count)",
                          color: Color.Kubb.swedishBlue, icon: nil)
            StatStripCell(label: "Minutes", value: "\(totalMinutes)",
                          color: Color.Kubb.darkForest, icon: nil)
            StatStripCell(label: "Phases", value: "\(distinctPhaseCount)",
                          color: Color.Kubb.midnightNavy, icon: nil)
            StatStripCell(label: "PBs", value: "\(pbCount)",
                          color: Color.Kubb.swedishGold, icon: "trophy.fill")
        }
    }

    // MARK: – Recap pin
    // The most-recent training session, only if completed within the last 24h
    // and not filtered out by the current phase filter. Powers TimelineRecapCard.
    private var pinnedRecapSession: TrainingSession? {
        let now = Date()
        let cutoff = now.addingTimeInterval(-24 * 3600)
        return rawSessions.first { session in
            guard let completed = session.completedAt, completed > cutoff else { return false }
            // Honour phase filter so it disappears when the user filters away.
            switch phaseFilter {
            case .all, .pbOnly:
                return true
            case .eightMeter:
                return session.phase == .eightMeters
            case .fourMeter:
                return session.phase == .fourMetersBlasting
            case .inkasting:
                return session.phase == .inkastingDrilling
            case .pressure, .gameTracker:
                return false
            }
        }
    }

    // MARK: – Timeline list with sticky month headers

    private var timelineList: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
            if let recap = pinnedRecapSession {
                VStack(alignment: .leading, spacing: KubbSpacing.s) {
                    Text("JUST NOW")
                        .font(KubbFont.mono(9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.Kubb.textSec)
                        .padding(.horizontal, KubbSpacing.l)

                    TimelineRecapCard(session: recap) {
                        selectedItem = .training(.local(recap))
                    }
                    .padding(.horizontal, KubbSpacing.l)
                }
                .padding(.bottom, KubbSpacing.m2)
            }

            let groups = monthGroups
            ForEach(groups) { month in
                Section {
                    let lastDayIdx = month.dayGroups.count - 1
                    let isLastMonth = month.id == groups.last?.id
                    ForEach(Array(month.dayGroups.enumerated()), id: \.element.id) { idx, day in
                        let isLastDay = idx == lastDayIdx && isLastMonth
                        dayGroupRow(day: day, isLast: isLastDay)
                    }
                } header: {
                    monthSectionHeader(text: month.headerText)
                }
            }

            // §7 End-of-list footer
            Text("End of timeline · \(filteredItems.count) sessions")
                .font(KubbFont.inter(11, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(Color.Kubb.textSec)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, KubbSpacing.xl)
                .padding(.vertical, KubbSpacing.m)
                .padding(.bottom, 100)
        }
        .padding(.top, KubbSpacing.s2)
    }

    // MARK: – Month sticky header

    private func monthSectionHeader(text: String) -> some View {
        Text(text)
            .font(KubbFont.inter(11, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(Color.Kubb.textSec)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, KubbSpacing.xl)
            .padding(.vertical, KubbSpacing.xs2)
            .background(
                ZStack {
                    Color.Kubb.timelineMonthHeaderBlur
                    Rectangle().fill(.ultraThinMaterial).opacity(0.5)
                }
            )
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.Kubb.sep).frame(height: 0.5)
            }
    }

    // MARK: – Day group row

    private func dayGroupRow(day: DayGroup, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: KubbSpacing.s2) {
            TimelineDayRail(date: day.date, isToday: day.isToday, hasConnector: !isLast)

            VStack(spacing: KubbSpacing.s) {
                ForEach(day.items, id: \.id) { item in
                    timelineCard(for: item)
                }
            }
            .padding(.bottom, KubbSpacing.xs2)
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.top, KubbSpacing.m2)
    }

    @ViewBuilder
    private func timelineCard(for item: JourneyTimelineItem) -> some View {
        switch item {
        case .training(let s):
            TimelineSessionCard(
                session: s,
                isPersonalBest: pbSessionIDs.contains(s.id),
                onTap: { selectedItem = item },
                onDelete: s.localSession.map { local in { sessionPendingDelete = local } }
            )
        case .game(let g):
            TimelineGameCard(game: g, onTap: { selectedItem = item })
        case .pc(let p):
            TimelinePCCard(
                session: p,
                isPersonalBest: pbSessionIDs.contains(p.id),
                onTap: { selectedItem = item }
            )
        }
    }

    // MARK: – Empty state

    private var emptyStateView: some View {
        VStack(spacing: KubbSpacing.l) {
            ZStack {
                Circle()
                    .fill(Color.Kubb.sep.opacity(0.25))
                    .frame(width: 56, height: 56)
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
            }

            VStack(spacing: KubbSpacing.xs) {
                Text("No sessions match \u{201C}\(phaseFilter.label)\u{201D}")
                    .font(KubbFont.inter(16, weight: .bold))
                    .foregroundStyle(Color.Kubb.text)
                    .multilineTextAlignment(.center)
                Text("Try a different filter, or expand the date range.")
                    .font(KubbFont.inter(12, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phaseFilter = .all
                    rangeFilter = .all
                }
            } label: {
                Text("Clear filter")
                    .font(KubbFont.inter(12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, KubbSpacing.l)
                    .padding(.vertical, KubbSpacing.s)
                    .background(Color.Kubb.swedishBlue)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, KubbSpacing.xl2)
        .padding(.vertical, KubbSpacing.xxxl)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xxl))
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.xxl)
                .strokeBorder(Color.Kubb.sep, style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
        .padding(.horizontal, KubbSpacing.xl2)
        .padding(.vertical, KubbSpacing.giant)
    }

    // MARK: – Build LedgerRow for training session sheet

    private func ledgerRow(for session: SessionDisplayItem) -> LedgerRow? {
        guard let kp = kubbPhase(for: session.phase) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let d = cal.startOfDay(for: session.createdAt)
        let diff = cal.dateComponents([.day], from: d, to: today).day ?? 0
        let dateLabel: String
        switch diff {
        case 0:  dateLabel = "TODAY"
        case 1:  dateLabel = "YSTD"
        default:
            let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
            dateLabel = fmt.string(from: session.createdAt).uppercased()
        }
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "h:mma"
        let statLine: String
        switch session.phase {
        case .eightMeters:
            statLine = String(format: "%.1f%%", session.accuracy)
        case .inkastingDrilling:
            statLine = session.averageClusterRadius(context: modelContext)
                .map { String(format: "%.2fm", $0) } ?? "—"
        case .fourMetersBlasting:
            statLine = session.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .pressureCooker:
            statLine = session.sessionScore.map { "\($0)" } ?? "—"
        default:
            statLine = "—"
        }
        let subLine = "\(session.roundCount)/\(session.configuredRounds)"
            + (session.durationFormatted.map { " · \($0)" } ?? "")

        return LedgerRow(
            id: session.id,
            phase: kp,
            dateLabel: dateLabel,
            timeLabel: timeFmt.string(from: session.createdAt),
            statLine: statLine,
            subLine: subLine,
            isPersonalBest: pbSessionIDs.contains(session.id),
            session: session
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

    // MARK: – Delete session

    private func impactSummary(for session: TrainingSession) -> DeleteImpactSummary {
        let throwCount = session.totalThrows

        let phaseLabel: String
        switch session.safePhase {
        case .eightMeters:        phaseLabel = "8m"
        case .fourMetersBlasting: phaseLabel = "4m"
        case .inkastingDrilling:  phaseLabel = "Ink"
        default:                  phaseLabel = "training"
        }

        let before = StreakCalculator.currentStreak(from: sessions, gameSessions: rawGameSessions, pcSessions: rawPCSessions)
        let filtered = sessions.filter { $0.localSession?.id != session.id }
        let after = StreakCalculator.currentStreak(from: filtered, gameSessions: rawGameSessions, pcSessions: rawPCSessions)

        let sessionId = session.id
        let allPBs = (try? modelContext.fetch(FetchDescriptor<PersonalBest>())) ?? []
        let holdsPB = allPBs.contains { $0.sessionId == sessionId }

        return DeleteImpactSummary(
            throwCount: throwCount,
            phaseLabel: phaseLabel,
            willBreakStreak: after < before && before > 0,
            currentStreakLength: before,
            holdsPB: holdsPB
        )
    }

    private func performDelete(_ session: TrainingSession) {
        let targetId = session.id
        let pbDescriptor = FetchDescriptor<PersonalBest>(predicate: #Predicate { $0.sessionId == targetId })
        if let orphaned = try? modelContext.fetch(pbDescriptor) {
            orphaned.forEach { modelContext.delete($0) }
        }
        modelContext.delete(session)
        try? modelContext.save()
    }
}

// MARK: – Range segmented control

private struct RangeSegmentedControl: View {
    @Binding var selected: TimelineRangeFilter

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimelineRangeFilter.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = option }
                } label: {
                    Text(option.label)
                        .font(KubbFont.inter(12, weight: .semibold))
                        .foregroundStyle(selected == option ? Color.Kubb.text : Color.Kubb.textSec)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Group {
                                if selected == option {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.Kubb.card)
                                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.Kubb.sep.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: – Timeline card variants for game and PC sessions

private struct TimelineGameCard: View {
    let game: GameSession
    let onTap: () -> Void

    private var phaseColor: Color { Color.Kubb.phase(.gameTracker) }

    private var heroStat: String {
        switch game.gameMode {
        case .competitive:
            if let won = game.userWon { return won ? "WIN" : "LOSS" }
            return "—"
        case .phantom:
            return "PHANTOM"
        }
    }

    private var timeString: String {
        let fmt = DateFormatter(); fmt.dateFormat = "h:mma"
        return fmt.string(from: game.createdAt).lowercased()
    }

    private var durationText: String? {
        guard let completed = game.completedAt else { return nil }
        let secs = Int(completed.timeIntervalSince(game.createdAt))
        return secs >= 60 ? "\(secs / 60)m" : "\(secs)s"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                phaseColor.frame(width: 3)
                VStack(alignment: .leading, spacing: KubbSpacing.s) {
                    HStack(spacing: KubbSpacing.s) {
                        HStack(spacing: 4) {
                            Image(systemName: KubbPhase.gameTracker.symbol)
                                .font(.system(size: 10, weight: .bold))
                            Text(KubbPhase.gameTracker.fullName)
                                .font(KubbFont.inter(11, weight: .bold))
                        }
                        .padding(.horizontal, KubbSpacing.s)
                        .padding(.vertical, 4)
                        .background(phaseColor.opacity(0.12))
                        .foregroundStyle(phaseColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Spacer()

                        Text(timeString)
                            .font(KubbFont.inter(11, weight: .regular))
                            .foregroundStyle(Color.Kubb.textSec)
                    }

                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(heroStat)
                                .font(KubbFont.inter(26, weight: .heavy))
                                .tracking(-0.5)
                                .foregroundStyle(phaseColor)
                                .lineLimit(1)
                            Text(game.gameMode == .phantom ? "phantom game" : "result")
                                .font(KubbFont.inter(11, weight: .medium))
                                .foregroundStyle(Color.Kubb.textSec)
                        }
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(game.turns.count) turn\(game.turns.count == 1 ? "" : "s")")
                                .font(KubbFont.inter(11, weight: .medium))
                        }
                        .foregroundStyle(Color.Kubb.textSec)

                        if let dur = durationText {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(dur)
                                    .font(KubbFont.inter(11, weight: .medium))
                            }
                            .foregroundStyle(Color.Kubb.textSec)
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Text("Detail")
                                .font(KubbFont.inter(11, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                    .padding(.top, KubbSpacing.s2)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.Kubb.sep).frame(height: 0.5)
                    }
                }
                .padding(KubbSpacing.m2)
            }
        }
        .buttonStyle(.plain)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.04), radius: 2, x: 0, y: 1)
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.06), radius: 8, x: 0, y: 3)
    }
}

private struct TimelinePCCard: View {
    let session: PressureCookerSession
    let isPersonalBest: Bool
    let onTap: () -> Void

    private var phaseColor: Color { Color.Kubb.phase(.pressureCooker) }

    private var gameType: PressureCookerGameType {
        PressureCookerGameType(rawValue: session.gameType) ?? .threeForThree
    }

    private var timeString: String {
        let fmt = DateFormatter(); fmt.dateFormat = "h:mma"
        return fmt.string(from: session.createdAt).lowercased()
    }

    private var durationText: String? {
        guard let completed = session.completedAt else { return nil }
        let secs = Int(completed.timeIntervalSince(session.createdAt))
        return secs >= 60 ? "\(secs / 60)m" : "\(secs)s"
    }

    private var gamePhase: KubbPhase {
        gameType == .threeForThree ? .pressureCooker343 : .pressureCookerInTheRed
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                phaseColor.frame(width: 3)
                VStack(alignment: .leading, spacing: KubbSpacing.s) {
                    HStack(spacing: KubbSpacing.s) {
                        HStack(spacing: 4) {
                            gamePhase.glyph(size: 12, weight: .bold)
                            Text(gameType.displayName)
                                .font(KubbFont.inter(11, weight: .bold))
                        }
                        .padding(.horizontal, KubbSpacing.s)
                        .padding(.vertical, 4)
                        .background(phaseColor.opacity(0.12))
                        .foregroundStyle(phaseColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        if isPersonalBest {
                            HStack(spacing: 3) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text("PB")
                                    .font(KubbFont.inter(10, weight: .heavy))
                            }
                            .foregroundStyle(Color.Kubb.pbInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.Kubb.swedishGold.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }

                        Spacer()

                        Text(timeString)
                            .font(KubbFont.inter(11, weight: .regular))
                            .foregroundStyle(Color.Kubb.textSec)
                    }

                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(session.totalScore)")
                                .font(KubbFont.inter(26, weight: .heavy))
                                .tracking(-0.5)
                                .foregroundStyle(phaseColor)
                                .lineLimit(1)
                            Text("points")
                                .font(KubbFont.inter(11, weight: .medium))
                                .foregroundStyle(Color.Kubb.textSec)
                        }
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .semibold))
                            Text("\(session.framesCompleted) frame\(session.framesCompleted == 1 ? "" : "s")")
                                .font(KubbFont.inter(11, weight: .medium))
                        }
                        .foregroundStyle(Color.Kubb.textSec)

                        if let dur = durationText {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(dur)
                                    .font(KubbFont.inter(11, weight: .medium))
                            }
                            .foregroundStyle(Color.Kubb.textSec)
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Text("Detail")
                                .font(KubbFont.inter(11, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                    .padding(.top, KubbSpacing.s2)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.Kubb.sep).frame(height: 0.5)
                    }
                }
                .padding(KubbSpacing.m2)
            }
        }
        .buttonStyle(.plain)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.04), radius: 2, x: 0, y: 1)
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.06), radius: 8, x: 0, y: 3)
    }
}

// MARK: – Summary stat strip cell

private struct StatStripCell: View {
    let label: String
    let value: String
    let color: Color
    let icon: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label.uppercased())
                    .font(KubbFont.inter(9, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.Kubb.textSec)
            }
            Text(value)
                .font(KubbFont.inter(18, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, KubbSpacing.s2)
        .padding(.vertical, KubbSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.04), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TrainingSession.self, TrainingRound.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let phases: [TrainingPhase] = [.eightMeters, .fourMetersBlasting, .inkastingDrilling, .eightMeters]
    for (i, phase) in phases.enumerated() {
        let s = TrainingSession(
            createdAt: Calendar.current.date(byAdding: .day, value: -i * 2, to: Date())!,
            completedAt: Calendar.current.date(byAdding: .day, value: -i * 2, to: Date()),
            phase: phase,
            configuredRounds: 10,
            startingBaseline: .north
        )
        ctx.insert(s)
    }
    return JourneyTimelineView()
        .modelContainer(container)
}
