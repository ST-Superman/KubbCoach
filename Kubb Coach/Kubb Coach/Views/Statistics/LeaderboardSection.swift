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

    @AppStorage("leaderboardDisplayName") private var displayName = ""

    private let service: LeaderboardServiceProtocol = SupabaseLeaderboardService()

    private var modeColor: Color { selectedMode.color }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                controlsHeader
                    .padding(.horizontal, KubbSpacing.l)
                    .padding(.top, KubbSpacing.l)
                    .padding(.bottom, KubbSpacing.m)

                Divider()
                    .foregroundStyle(Color.Kubb.sep)

                if isLoading {
                    loadingView
                } else if entries.isEmpty {
                    emptyView
                } else {
                    entryList
                }

                Spacer(minLength: 150)
            }
        }
        .overlay(alignment: .bottom) {
            if let userEntry = entries.first(where: { $0.isCurrentUser }) {
                pinnedYouRow(entry: userEntry)
                    .padding(.horizontal, KubbSpacing.l)
                    .padding(.vertical, KubbSpacing.m)
                    .padding(.bottom, 56)
                    .background(Color.Kubb.paper.ignoresSafeArea(edges: .bottom))
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
        .onChange(of: selectedMode) { _, newMode in
            selectedMetric = newMode.defaultMetric
        }
    }

    // MARK: - Controls header

    private var controlsHeader: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.m) {
            modeTabsRow
            metricChipsRow
            recencyWindowRow
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

    private var metricChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KubbSpacing.s) {
                ForEach(selectedMode.metrics, id: \.self) { metric in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedMetric = metric
                        }
                    } label: {
                        Text(metric.displayName)
                            .font(KubbFont.inter(12.5, weight: .semibold))
                            .foregroundStyle(selectedMetric == metric ? .white : Color.Kubb.textTer)
                            .padding(.horizontal, KubbSpacing.m)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selectedMetric == metric ? modeColor : Color.Kubb.paper2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedMetric == metric ? .isSelected : [])
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var recencyWindowRow: some View {
        HStack {
            Text("RANKED ON RECENT FORM")
                .font(KubbFont.mono(9, weight: .bold))
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textTer)

            Spacer()

            Picker("Window", selection: $selectedWindow) {
                ForEach(RecencyWindow.allCases, id: \.self) { window in
                    Text(window.rawValue).tag(window)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 88)
        }
    }

    // MARK: - Entry list

    private var entryList: some View {
        LazyVStack(spacing: 0) {
            ForEach(entries) { entry in
                LeaderboardRowView(entry: entry, metric: selectedMetric, modeColor: modeColor)

                if entry.rank < entries.count {
                    Divider()
                        .padding(.leading, 60)
                        .foregroundStyle(Color.Kubb.sep)
                }
            }
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
        .padding(.horizontal, KubbSpacing.l)
        .padding(.top, KubbSpacing.m)
    }

    // MARK: - Pinned "You" row

    private func pinnedYouRow(entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            // Rank label
            Text(entry.rankLabel)
                .font(entry.isMedal ? .system(size: 16) : KubbFont.mono(13, weight: .bold))
                .foregroundStyle(.white)
                .frame(minWidth: 28, alignment: .center)

            // Avatar
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 30, height: 30)
                Text(entry.initials)
                    .font(KubbFont.mono(10, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("\(entry.displayName) (You)")
                .font(KubbFont.inter(13.5, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(selectedMetric.format(entry.value))
                    .font(KubbFont.fraunces(16, weight: .medium, italic: true))
                    .foregroundStyle(.white)
                if let avg = entry.secondaryValue, let label = selectedMetric.formatSecondary(avg) {
                    Text(label)
                        .font(KubbFont.inter(11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding(.horizontal, KubbSpacing.l)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: KubbRadius.l)
                .fill(modeColor)
        )
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
        ContentUnavailableView {
            Label("No data yet", systemImage: "chart.bar.xaxis")
        } description: {
            Text("No entries for this window yet.\nComplete sessions to appear on the board.")
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Data loading

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

// MARK: - LeaderboardRowView

private struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let metric: LeaderboardMetric
    let modeColor: Color

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

    private var rankLabel: some View {
        Text(entry.rankLabel)
            .font(entry.isMedal ? .system(size: 16) : KubbFont.mono(13, weight: .bold))
            .foregroundStyle(Color.Kubb.textTer)
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
        Text(entry.isCurrentUser ? "\(entry.displayName) (You)" : entry.displayName)
            .font(KubbFont.inter(13.5, weight: .bold))
            .foregroundStyle(Color.Kubb.text)
    }

    private var valueLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(metric.format(entry.value))
                .font(KubbFont.fraunces(16, weight: .medium, italic: true))
                .foregroundStyle(modeColor)
            if let avg = entry.secondaryValue, let label = metric.formatSecondary(avg) {
                Text(label)
                    .font(KubbFont.inter(11, weight: .regular))
                    .foregroundStyle(Color.Kubb.textTer)
            }
        }
    }

    private var rowBackground: some View {
        entry.isCurrentUser
            ? AnyView(modeColor.opacity(0.08))
            : AnyView(Color.clear)
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

                TextField("e.g. Lars N.", text: $draft)
                    .font(KubbFont.inter(16, weight: .semibold))
                    .padding(KubbSpacing.m)
                    .background(Color.Kubb.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m))
                    .focused($focused)
                    .onSubmit { commitIfValid() }
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
        guard !trimmed.isEmpty else { return }
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
