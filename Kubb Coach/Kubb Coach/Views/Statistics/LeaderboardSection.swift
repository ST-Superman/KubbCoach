// LeaderboardSection.swift
// Global leaderboard view — lives inside the Records tab's "Leaderboard" segment.
// Backed by SupabaseLeaderboardService (anonymous auth, RLS-enforced writes).

import SwiftUI
import SwiftData

struct LeaderboardSection: View {
    let sessions: [TrainingSession]

    @State private var selectedMode: LeaderboardMode = .eightMeter
    @State private var selectedMetric: LeaderboardMetric = .accuracy
    @State private var selectedWindow: RecencyWindow = .thirty
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var showNamePrompt = false
    @State private var reportingEntry: LeaderboardEntry?
    @State private var showReportConfirm = false
    @State private var reportSubmitted = false

    @AppStorage("leaderboardDisplayName") private var displayName = ""

    @Environment(\.colorScheme) private var colorScheme

    private let service: LeaderboardServiceProtocol = SupabaseLeaderboardService()

    private var modeColor: Color { selectedMode.color }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                    .padding(.horizontal, KubbSpacing.xl)
                    .padding(.top, KubbSpacing.l)
                    .padding(.bottom, KubbSpacing.m)

                controlsHeader
                    .padding(.horizontal, KubbSpacing.l)
                    .padding(.bottom, KubbSpacing.m)

                if isLoading {
                    loadingView
                } else if entries.isEmpty {
                    emptyView
                } else {
                    heroCard
                        .padding(.horizontal, KubbSpacing.l)
                        .padding(.bottom, KubbSpacing.m)

                    boardCard
                        .padding(.horizontal, KubbSpacing.l)
                }

                Spacer(minLength: 40)
            }
        }
        .task(id: "\(selectedMode.rawValue)|\(selectedMetric.rawValue)|\(selectedWindow.rawValue)") {
            await loadEntries()
        }
        .task(id: displayName) {
            guard !displayName.isEmpty else { return }
            await service.submitStats(sessions: sessions, displayName: displayName)
        }
        .onAppear {
            if displayName.isEmpty { showNamePrompt = true }
        }
        .sheet(isPresented: $showNamePrompt) {
            LeaderboardNameSheet(displayName: $displayName)
        }
        .confirmationDialog(
            "Report \"\(reportingEntry?.displayName ?? "")\"?",
            isPresented: $showReportConfirm,
            titleVisibility: .visible
        ) {
            Button("Report offensive name", role: .destructive) {
                guard let entry = reportingEntry else { return }
                Task { await submitReport(entry: entry) }
            }
            Button("Cancel", role: .cancel) { reportingEntry = nil }
        } message: {
            Text("This name will be reviewed and may be hidden from the leaderboard.")
        }
        .alert("Report submitted", isPresented: $reportSubmitted) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks for flagging this. We'll review it and take action if needed.")
        }
        .onChange(of: selectedMode) { _, newMode in
            selectedMetric = newMode.defaultMetric
        }
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GLOBAL LEADERBOARD")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)
            Text("Leaderboard")
                .font(KubbFont.fraunces(30, weight: .medium))
                .tracking(-1)
                .foregroundStyle(Color.Kubb.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Controls

    private var controlsHeader: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.m) {
            modeTabsRow
            controlLine
        }
    }

    private var modeTabsRow: some View {
        HStack(spacing: KubbSpacing.s) {
            ForEach(LeaderboardMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(KubbFont.inter(13.5, weight: .bold))
                        .foregroundStyle(selectedMode == mode ? .white : Color.Kubb.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(selectedMode == mode ? mode.color : Color.Kubb.paper2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
            }
        }
    }

    /// One line: metric picker on the left, recency-window chips on the right.
    private var controlLine: some View {
        HStack(spacing: KubbSpacing.m) {
            metricMenu
            Spacer(minLength: KubbSpacing.s)
            windowChips
        }
    }

    private var metricMenu: some View {
        Menu {
            ForEach(selectedMode.metrics, id: \.self) { metric in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedMetric = metric }
                } label: {
                    if selectedMetric == metric {
                        Label(metric.displayName, systemImage: "checkmark")
                    } else {
                        Text(metric.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedMetric.displayName)
                    .font(KubbFont.inter(13, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.Kubb.textTer)
            }
        }
        .accessibilityLabel("Metric")
        .accessibilityValue(selectedMetric.displayName)
    }

    private var windowChips: some View {
        HStack(spacing: KubbSpacing.s) {
            ForEach(RecencyWindow.allCases, id: \.self) { window in
                let selected = selectedWindow == window
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedWindow = window }
                } label: {
                    Text(window.rawValue.uppercased())
                        .font(KubbFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(selected ? Color.Kubb.paper : Color.Kubb.textTer)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selected ? Color.Kubb.text : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.Kubb.sep, lineWidth: selected ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: - Entry list

    // MARK: - Your standing hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR STANDING · \(selectedMetric.displayName.uppercased()) · \(selectedWindow.rawValue.uppercased())")
                .font(KubbFont.mono(9, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Color.Kubb.textSec)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(userRank.map { ordinal($0) } ?? "—")
                    .font(KubbFont.fraunces(56, weight: .medium, italic: true))
                    .tracking(-2.2)
                    .foregroundStyle(Color.Kubb.text)
                    .monospacedDigit()
                Text("of \(entries.count) player\(entries.count == 1 ? "" : "s")")
                    .font(KubbFont.inter(13))
                    .foregroundStyle(Color.Kubb.textSec)
            }

            Rectangle()
                .fill(Color.Kubb.sep)
                .frame(height: 0.5)

            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(modeColor)
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
                Text(chaseText)
                    .font(KubbFont.inter(13, weight: .medium))
                    .foregroundStyle(Color.Kubb.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl, style: .continuous))
        .kubbCardShadow()
    }

    /// The current user's entry (locally injected), if present in this window.
    private var userEntry: LeaderboardEntry? {
        entries.first(where: { $0.isCurrentUser })
    }

    private var userRank: Int? { userEntry?.rank }

    private func ordinal(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// One coach-voice sentence describing the user's standing in this window.
    private var chaseText: String {
        guard let user = userEntry else {
            return "No \(selectedMode.rawValue) sessions in this window yet."
        }
        guard user.rank > 1 else {
            return "You lead the board."
        }
        if let above = entries.first(where: { $0.rank == user.rank - 1 }) {
            let gap = selectedMetric.format(abs(user.value - above.value))
            return "\(gap) behind \(above.displayName) — next up."
        }
        return "You're on the board."
    }

    // MARK: - The board

    /// Rows to render: the full list (≤12) or a folded 1–3 · gap · you±2 view
    /// when the user sits deep in the board (rank > 6).
    private var visibleRows: [BoardRow] {
        guard let rank = userRank, rank > 6 else {
            return entries.prefix(12).map { .entry($0) }
        }
        let top = entries.filter { $0.rank <= 3 }
        let around = entries.filter { $0.rank >= rank - 2 && $0.rank <= rank + 2 }
        return top.map { .entry($0) } + [.fold] + around.map { .entry($0) }
    }

    private var boardCard: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(visibleRows.enumerated()), id: \.offset) { index, row in
                switch row {
                case .fold:
                    Text("· · ·")
                        .font(KubbFont.mono(10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.Kubb.textTer)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                case .entry(let entry):
                    LeaderboardRowView(
                        entry: entry,
                        metric: selectedMetric,
                        modeColor: modeColor,
                        colorScheme: colorScheme
                    )
                    .contextMenu {
                        if !entry.isCurrentUser {
                            Button(role: .destructive) {
                                reportingEntry = entry
                                showReportConfirm = true
                            } label: {
                                Label("Report offensive name", systemImage: "flag")
                            }
                        }
                    }
                }

                if index < visibleRows.count - 1 {
                    Rectangle()
                        .fill(Color.Kubb.sep)
                        .frame(height: 0.5)
                        .padding(.leading, 60)
                }
            }
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
    }

    // MARK: - Loading / empty states

    private var loadingView: some View {
        VStack(spacing: KubbSpacing.m) {
            ProgressView()
                .tint(modeColor)
            Text("Loading leaderboard…")
                .font(KubbType.bodyS)
                .foregroundStyle(Color.Kubb.textTer)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: KubbSpacing.s) {
            Text("The board is quiet.")
                .font(KubbFont.fraunces(22, weight: .regular, italic: true))
                .foregroundStyle(Color.Kubb.text)
            Text("No \(selectedMode.rawValue) entries in this window yet. Complete a session to put a number here.")
                .font(KubbFont.inter(13))
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, KubbSpacing.xl)
    }

    // MARK: - Data loading

    private func submitReport(entry: LeaderboardEntry) async {
        _ = await service.reportEntry(displayName: entry.displayName, mode: selectedMode.rawValue)
        reportingEntry = nil
        reportSubmitted = true
    }

    private func loadEntries() async {
        isLoading = true
        var fetched = await service.fetchEntries(
            mode: selectedMode,
            metric: selectedMetric,
            window: selectedWindow
        )

        // Compute user's local value and inject at the correct rank.
        // Remove any Supabase entry for the current user first — the locally
        // computed value is always fresher and reflects the current metric logic.
        fetched.removeAll { $0.isCurrentUser }

        if let userValue = localUserValue() {
            let userEntry = LeaderboardEntry(
                id: UUID(),
                rank: 0,          // placeholder — corrected below
                displayName: displayName.isEmpty ? "You" : displayName,
                value: userValue,
                secondaryValue: localUserSecondaryValue(),
                isCurrentUser: true
            )
            fetched.append(userEntry)

            // Re-sort and assign final ranks (preserve secondaryValue)
            if selectedMetric.sortAscending {
                fetched.sort { $0.value < $1.value }
            } else {
                fetched.sort { $0.value > $1.value }
            }
            fetched = fetched.enumerated().map { idx, e in
                LeaderboardEntry(id: e.id, rank: idx + 1, displayName: e.displayName,
                                 value: e.value, secondaryValue: e.secondaryValue,
                                 isCurrentUser: e.isCurrentUser)
            }
        }

        entries = fetched
        isLoading = false
    }

    // Compute the current user's metric value from local sessions in the recency window
    private func localUserValue() -> Double? {
        let cutoff = selectedWindow.startDate
        let phase = selectedMode.trainingPhase
        let recent = sessions.filter {
            $0.completedAt != nil &&
            !($0.isTutorialSession) &&
            $0.phase == phase &&
            ($0.completedAt ?? .distantPast) >= cutoff
        }
        guard !recent.isEmpty else { return nil }

        switch selectedMetric {
        case .accuracy:
            return recent.map { $0.accuracy }.max()

        case .longestStreak:
            let best = recent.map { session -> Int in
                let allThrows = session.rounds
                    .sorted { $0.roundNumber < $1.roundNumber }
                    .flatMap { round in round.throwRecords.sorted { $0.throwNumber < $1.throwNumber } }
                var bestStreak = 0, current = 0
                for t in allThrows {
                    if t.result == .hit {
                        current += 1
                        bestStreak = max(bestStreak, current)
                    } else {
                        current = 0
                    }
                }
                return bestStreak
            }.max() ?? 0
            return best > 0 ? Double(best) : nil

        case .throwsLogged:
            return Double(recent.reduce(0) { $0 + $1.totalThrows })

        case .avgScoreVsPar:
            let scored = recent.compactMap { $0.totalSessionScore }
            guard !scored.isEmpty else { return nil }
            return Double(scored.reduce(0, +)) / Double(scored.count)

        case .avgClusterRadius:
            return nil

        case .tightestCluster:
            let radii = recent.compactMap { session -> Double? in
                let analyses = session.rounds.compactMap { $0.inkastingAnalysis }
                guard !analyses.isEmpty else { return nil }
                return analyses.map { $0.clusterRadiusMeters }.reduce(0.0, +) / Double(analyses.count)
            }
            return radii.min()

        case .spreadRatio:
            let ratios = recent.compactMap { session -> Double? in
                let analyses = session.rounds.compactMap { $0.inkastingAnalysis }
                guard !analyses.isEmpty else { return nil }
                let avgCluster = analyses.map { $0.clusterRadiusMeters }.reduce(0.0, +) / Double(analyses.count)
                guard avgCluster > 0 else { return nil }
                let avgSpread = analyses.map { $0.totalSpreadRadius }.reduce(0.0, +) / Double(analyses.count)
                return avgSpread / avgCluster
            }
            return ratios.min()

        case .inkastCount:
            return Double(recent.reduce(0) { $0 + $1.totalInkastKubbs })

        case .bestScore:
            let scores = recent.compactMap { $0.totalSessionScore }
            guard !scores.isEmpty else { return nil }
            return Double(scores.min()!)

        case .underParPercent:
            let totalRounds = recent.reduce(0) { $0 + $1.rounds.count }
            guard totalRounds > 0 else { return nil }
            let underPar = recent.reduce(0) { $0 + $1.underParRoundsCount }
            return Double(underPar) / Double(totalRounds) * 100

        case .sessionCount:
            return Double(recent.count)
        }
    }

    // Returns the supplemental value for the current user (shown in parentheses alongside the primary).
    private func localUserSecondaryValue() -> Double? {
        let cutoff = selectedWindow.startDate
        let phase = selectedMode.trainingPhase
        let recent = sessions.filter {
            $0.completedAt != nil &&
            !($0.isTutorialSession) &&
            $0.phase == phase &&
            ($0.completedAt ?? .distantPast) >= cutoff
        }
        guard !recent.isEmpty else { return nil }

        switch selectedMetric {
        case .accuracy:
            return recent.reduce(0.0) { $0 + $1.accuracy } / Double(recent.count)
        case .bestScore:
            let scores = recent.compactMap { $0.totalSessionScore }
            guard !scores.isEmpty else { return nil }
            return Double(scores.reduce(0, +)) / Double(scores.count)
        default:
            return nil
        }
    }

}

// MARK: - Board row model

private enum BoardRow {
    case entry(LeaderboardEntry)
    case fold
}

// MARK: - LeaderboardRowView

private struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let metric: LeaderboardMetric
    let modeColor: Color
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            rankLabel
            avatarCircle
            nameLabel
            Spacer()
            valueLabel
        }
        .padding(.horizontal, KubbSpacing.l)
        .frame(height: 52)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Rank ink: gold for 1st, silver-grey for 2nd, bronze for 3rd, muted after.
    private var rankInk: Color {
        switch entry.rank {
        case 1:  return Color.Kubb.pbInk
        case 2:  return Color.Kubb.textSec
        case 3:  return Color.Kubb.bronze
        default: return Color.Kubb.textTer
        }
    }

    private var rankLabel: some View {
        Text(String(format: "%02d", entry.rank))
            .font(KubbFont.mono(12, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(rankInk)
            .frame(minWidth: 28, alignment: .center)
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(entry.isCurrentUser ? modeColor.opacity(0.15) : Color.Kubb.paper2)
                .frame(width: 30, height: 30)
            Text(entry.initials)
                .font(KubbFont.mono(10, weight: .semibold))
                .foregroundStyle(entry.isCurrentUser ? modeColor : Color.Kubb.textSec)
        }
    }

    private var nameLabel: some View {
        let base = Text(entry.displayName).foregroundStyle(Color.Kubb.text)
        let full = entry.isCurrentUser
            ? base + Text("  (You)").foregroundStyle(modeColor)
            : base
        return full.font(KubbFont.inter(13.5, weight: .bold))
    }

    private var valueLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(metric.format(entry.value))
                .font(KubbFont.fraunces(16, weight: .medium, italic: true))
                .monospacedDigit()
                .foregroundStyle(modeColor)
            if let avg = entry.secondaryValue, let label = metric.formatSecondary(avg) {
                Text(label)
                    .font(KubbFont.inter(10.5, weight: .regular))
                    .foregroundStyle(Color.Kubb.textTer)
            }
        }
    }

    private var rowBackground: Color {
        entry.isCurrentUser
            ? modeColor.opacity(colorScheme == .dark ? 0.10 : 0.07)
            : Color.clear
    }

    private var accessibilityLabel: String {
        let name = entry.isCurrentUser ? "\(entry.displayName), You" : entry.displayName
        return "Rank \(entry.rank), \(name), \(metric.format(entry.value))"
    }
}

// MARK: - Display name prompt sheet

struct LeaderboardNameSheet: View {
    @Binding var displayName: String
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: KubbSpacing.xl) {
                VStack(spacing: KubbSpacing.m) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.Kubb.swedishGold)

                    Text("Join the Leaderboard")
                        .font(KubbType.titleL)
                        .foregroundStyle(Color.Kubb.text)

                    Text("Pick a display name.\nThis is how you'll appear to other players.")
                        .font(KubbType.bodyS)
                        .foregroundStyle(Color.Kubb.textSec)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, KubbSpacing.xl)

                VStack(alignment: .trailing, spacing: 4) {
                    TextField("e.g. Lars N.", text: $draft)
                        .font(KubbFont.inter(16, weight: .semibold))
                        .padding(KubbSpacing.m)
                        .background(Color.Kubb.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m))
                        .focused($focused)
                        .onSubmit { commitIfValid() }
                        .onChange(of: draft) { _, newValue in
                            if newValue.count > 30 { draft = String(newValue.prefix(30)) }
                        }
                    let charCount = draft.trimmingCharacters(in: .whitespaces).count
                    Text("\(charCount)/30")
                        .font(.caption2)
                        .foregroundStyle(charCount > 25 ? Color.orange : Color.Kubb.textTer)
                }
                .padding(.horizontal, KubbSpacing.l)

                Button(action: commitIfValid) {
                    Text("Start competing")
                        .font(KubbFont.inter(15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KubbSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: KubbRadius.l)
                                .fill(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                      ? Color.Kubb.textTer
                                      : Color.Kubb.swedishBlue)
                        )
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, KubbSpacing.l)

                Spacer()
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe later") { dismiss() }
                        .font(KubbType.bodyS)
                        .foregroundStyle(Color.Kubb.textSec)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }

    private func commitIfValid() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 30 else { return }
        displayName = trimmed
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScrollView {
            LeaderboardSection(sessions: [])
        }
        .background(Color.Kubb.paper)
        .navigationTitle("Records")
    }
}
