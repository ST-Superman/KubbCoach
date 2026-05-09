// JourneyTimelineView.swift
// Full-screen session history with phase/range filters, sticky month headers,
// and a vertical-rail day-group timeline. Reached by tapping the Journey heatmap card.

import SwiftUI
import SwiftData

// MARK: – Filter enums

enum TimelinePhaseFilter: String, Hashable, CaseIterable {
    case all, eightMeter, fourMeter, inkasting, pressure, pbOnly

    var label: String {
        switch self {
        case .all:        return "All"
        case .eightMeter: return "8 Meters"
        case .fourMeter:  return "Blasting"
        case .inkasting:  return "Inkasting"
        case .pressure:   return "Pressure"
        case .pbOnly:     return "★ PBs"
        }
    }

    var color: Color {
        switch self {
        case .all:        return KubbColors.midnightNavy
        case .eightMeter: return Color.Kubb.swedishBlue
        case .fourMeter:  return Color.Kubb.phase4m
        case .inkasting:  return Color.Kubb.forestGreen
        case .pressure:   return Color.Kubb.phasePC
        case .pbOnly:     return Color.Kubb.swedishGold
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

// MARK: – Main view

struct JourneyTimelineView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<TrainingSession> { $0.completedAt != nil || $0.deviceType == "Watch" },
        sort: \TrainingSession.createdAt, order: .reverse
    ) private var rawSessions: [TrainingSession]

    @State private var phaseFilter: TimelinePhaseFilter = .all
    @State private var rangeFilter: TimelineRangeFilter = .all
    @State private var scrolled = false
    @State private var scrollBaselineY: CGFloat? = nil
    @State private var selectedSession: LedgerRow? = nil

    // MARK: – Data helpers

    private var sessions: [SessionDisplayItem] {
        rawSessions.map { .local($0) }
    }

    /// One-per-phase personal-best session IDs (best stat across all time).
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
        // pc → highest score
        if let best = allLocal
            .filter({ $0.phase == .pressureCooker && $0.sessionScore != nil })
            .max(by: { ($0.sessionScore ?? 0) < ($1.sessionScore ?? 0) }) {
            ids.insert(best.id)
        }
        return ids
    }

    /// Sessions after applying the current range filter only (used for chip counts).
    private var rangeFilteredSessions: [SessionDisplayItem] {
        applyRange(to: sessions)
    }

    /// Sessions after applying both range and phase filters.
    private var filteredSessions: [SessionDisplayItem] {
        let byRange = applyRange(to: sessions)
        return applyPhase(to: byRange)
    }

    private func applyRange(to input: [SessionDisplayItem]) -> [SessionDisplayItem] {
        let now = Date()
        switch rangeFilter {
        case .last30: return input.filter { now.timeIntervalSince($0.createdAt) <= 30 * 86_400 }
        case .last90: return input.filter { now.timeIntervalSince($0.createdAt) <= 90 * 86_400 }
        case .all:    return input
        }
    }

    private func applyPhase(to input: [SessionDisplayItem]) -> [SessionDisplayItem] {
        switch phaseFilter {
        case .all:        return input
        case .eightMeter: return input.filter { $0.phase == .eightMeters }
        case .fourMeter:  return input.filter { $0.phase == .fourMetersBlasting }
        case .inkasting:  return input.filter { $0.phase == .inkastingDrilling }
        case .pressure:   return input.filter { $0.phase == .pressureCooker }
        case .pbOnly:     return input.filter { pbSessionIDs.contains($0.id) }
        }
    }

    private func chipCount(for filter: TimelinePhaseFilter) -> Int {
        switch filter {
        case .all:        return rangeFilteredSessions.count
        case .eightMeter: return rangeFilteredSessions.filter { $0.phase == .eightMeters }.count
        case .fourMeter:  return rangeFilteredSessions.filter { $0.phase == .fourMetersBlasting }.count
        case .inkasting:  return rangeFilteredSessions.filter { $0.phase == .inkastingDrilling }.count
        case .pressure:   return rangeFilteredSessions.filter { $0.phase == .pressureCooker }.count
        case .pbOnly:     return rangeFilteredSessions.filter { pbSessionIDs.contains($0.id) }.count
        }
    }

    // MARK: – Summary stats (from filtered dataset)

    private var pbCount: Int { filteredSessions.filter { pbSessionIDs.contains($0.id) }.count }
    private var distinctPhaseCount: Int { Set(filteredSessions.map(\.phase)).count }
    private var totalMinutes: Int {
        Int(filteredSessions.compactMap { s -> TimeInterval? in
            guard let completed = s.completedAt else { return nil }
            return completed.timeIntervalSince(s.createdAt)
        }.reduce(0, +) / 60)
    }

    // MARK: – Day/month grouping

    struct DayGroup: Identifiable {
        let date: Date
        let sessions: [SessionDisplayItem]
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
        let byDay = Dictionary(grouping: filteredSessions) { cal.startOfDay(for: $0.createdAt) }
        let dayGroups = byDay.map { date, items in
            DayGroup(date: date, sessions: items.sorted { $0.createdAt > $1.createdAt })
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
            KubbColors.timelineBg.ignoresSafeArea()

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
                    VolumeMiniBar(sessions: sessions)
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
                    if filteredSessions.isEmpty {
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
        .sheet(item: $selectedSession) { row in
            SessionLedgerDetailSheet(row: row)
        }
    }

    // MARK: – Nav header

    private var navHeader: some View {
        ZStack(alignment: .bottom) {
            // Blurred background (fades in once scrolled)
            ZStack {
                KubbColors.timelineHeaderBlur
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
                        .background(Color.white)
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
                        .foregroundStyle(KubbColors.midnightNavy)
                }

                Spacer()

                // Search button (stub — out of scope)
                Button { } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
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
            Text("\(filteredSessions.count) sessions")
                .font(KubbFont.inter(12, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
            if pbCount > 0 {
                Text("· \(pbCount) PB")
                    .font(KubbFont.inter(12, weight: .bold))
                    .foregroundStyle(KubbColors.pbInk)
            }
        }
    }

    // MARK: – Stat strip

    private var statStrip: some View {
        HStack(spacing: KubbSpacing.s) {
            StatStripCell(label: "Sessions", value: "\(filteredSessions.count)",
                          color: Color.Kubb.swedishBlue, icon: nil)
            StatStripCell(label: "Minutes", value: "\(totalMinutes)",
                          color: KubbColors.forestGreen, icon: nil)
            StatStripCell(label: "Phases", value: "\(distinctPhaseCount)",
                          color: KubbColors.midnightNavy, icon: nil)
            StatStripCell(label: "PBs", value: "\(pbCount)",
                          color: Color.Kubb.swedishGold, icon: "trophy.fill")
        }
    }

    // MARK: – Timeline list with sticky month headers

    private var timelineList: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
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
            Text("End of timeline · \(filteredSessions.count) sessions")
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
                    KubbColors.timelineMonthHeaderBlur
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
                ForEach(day.sessions, id: \.id) { session in
                    TimelineSessionCard(
                        session: session,
                        isPersonalBest: pbSessionIDs.contains(session.id),
                        onTap: { openDetail(for: session) }
                    )
                }
            }
            .padding(.bottom, KubbSpacing.xs2)
        }
        .padding(.horizontal, KubbSpacing.l)
        .padding(.top, KubbSpacing.m2)
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

    // MARK: – Open session detail

    private func openDetail(for session: SessionDisplayItem) {
        guard let kp = kubbPhase(for: session.phase) else { return }
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
        case .eightMeters, .inkastingDrilling:
            statLine = String(format: "%.1f%%", session.accuracy)
        case .fourMetersBlasting:
            statLine = session.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .pressureCooker:
            statLine = session.sessionScore.map { "\($0)" } ?? "—"
        default:
            statLine = "—"
        }
        let subLine = "\(session.roundCount)/\(session.configuredRounds)"
            + (session.durationFormatted.map { " · \($0)" } ?? "")

        selectedSession = LedgerRow(
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
