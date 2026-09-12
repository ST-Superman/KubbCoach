// MatchesHubView.swift
// The entitled Virtual Matches surface, shaped like the Kubb Platform /matches
// page: two tabs — CURRENT (live matches split into "Your Turn" / "Waiting for
// Opponent", mirroring turn-sections.tsx) and NEW (create a match + "Practice vs
// Kubb Coach" bots). Completed matches are NOT shown here — they live in the
// Journey's match history. Rows mirror match-row.tsx (status badge, SIM pill,
// opponent, score).

import SwiftUI
import SwiftData

private enum HubTab: String, CaseIterable, Identifiable {
    case current = "Current"
    case new = "New"
    var id: String { rawValue }
}

struct MatchesHubView: View {
    @Bindable var service: VirtualMatchService
    @Binding var path: [MatchRoute]
    @Environment(\.modelContext) private var modelContext

    // Finished-match count drives clone-bot gating (unlocks at 5).
    @Query(sort: \VirtualMatchRecord.finishedAt, order: .reverse)
    private var records: [VirtualMatchRecord]

    @State private var tab: HubTab = .current
    @State private var botRaceTo = 1

    private let raceToChoices = [1, 2, 3]

    private var activeMatches: [MatchSummaryRow] {
        service.myMatches.filter { $0.status == .created || $0.status == .live }
    }
    private var yourTurn: [MatchSummaryRow] {
        activeMatches.filter { $0.turn == "you" }.sorted { $0.createdAt < $1.createdAt }
    }
    private var waiting: [MatchSummaryRow] {
        activeMatches.filter { $0.turn == "opponent" }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    switch tab {
                    case .current: currentContent
                    case .new: newContent
                    }

                    if let err = service.lastError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(Color.Kubb.miss)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Virtual Matches")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        await service.listMyMatches()
        VirtualMatchProgressionService.backfill(rows: service.myMatches, context: modelContext)
        await service.listBotProfiles()
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(HubTab.allCases) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = t }
                } label: {
                    HStack(spacing: 6) {
                        Text(t.rawValue)
                        if t == .current, !activeMatches.isEmpty {
                            Text("\(activeMatches.count)")
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .foregroundStyle(tab == t ? .white : Color.Kubb.textSec)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(tab == t ? Color.Kubb.matchAccent : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(tab == t ? .white : Color.Kubb.textSec)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: - Current tab

    @ViewBuilder
    private var currentContent: some View {
        if activeMatches.isEmpty {
            if service.isBusy && service.myMatches.isEmpty {
                ProgressView().padding(.top, 40)
            } else {
                currentEmptyState
            }
        } else {
            if !yourTurn.isEmpty { matchSection("YOUR TURN", rows: yourTurn) }
            if !waiting.isEmpty { matchSection("WAITING FOR OPPONENT", rows: waiting) }
        }
    }

    private var currentEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.disc.sports")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
            Text("No matches in play")
                .font(.headline)
            Text("Start a match or practice against Kubb Coach.")
                .font(.footnote)
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
            Button("Go to New") { withAnimation { tab = .new } }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Kubb.matchAccent)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func matchSection(_ title: String, rows: [MatchSummaryRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow(title).padding(.horizontal, 20)
            SettingsCard {
                ForEach(rows) { row in
                    Button {
                        path.append(.play(matchId: row.matchId))
                    } label: {
                        matchRow(row)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func matchRow(_ row: MatchSummaryRow) -> some View {
        HStack(spacing: 10) {
            statusBadge(row)
            if row.isSimulated == true { simPill }
            Text(row.opponent ?? "Opponent")
                .font(KubbFont.inter(15, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(row.scoreLine)
                .font(KubbFont.fraunces(18, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
            SettingsChevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func statusBadge(_ row: MatchSummaryRow) -> some View {
        let (text, color): (String, Color) = row.status == .created
            ? ("LAG", Color.Kubb.swedishGold)
            : ("LIVE", Color.Kubb.matchAccent)
        return Text(text)
            .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color, in: Capsule())
    }

    private var simPill: some View {
        Text("SIM")
            .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(0.8)
            .foregroundStyle(Color.Kubb.textSec)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.Kubb.textSec.opacity(0.15), in: Capsule())
    }

    // MARK: - New tab

    private var newContent: some View {
        VStack(spacing: 22) {
            // Card A — managed / account match setup (pushes the full setup screen).
            Button {
                path.append(.newMatch)
            } label: {
                newCard(
                    icon: "person.2.fill",
                    title: "New virtual match",
                    body: "Play someone you keep score for. You'll enter both sides' throws."
                ) { SettingsChevron() }
            }
            .buttonStyle(.plain)

            // Card B — Practice vs Kubb Coach (bots).
            practiceCard
        }
        .padding(.horizontal, 16)
    }

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PRACTICE VS KUBB COACH")
                    .font(KubbType.monoXS).tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.Kubb.matchAccent)
                Text("Play a bot that throws its own turns — you just score your side. Bot matches count toward your record.")
                    .font(.footnote)
                    .foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Race-to chips
            HStack(spacing: 8) {
                ForEach(raceToChoices, id: \.self) { n in
                    Button { botRaceTo = n } label: {
                        Text("Race to \(n)")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .background(botRaceTo == n ? Color.Kubb.matchAccent : Color.Kubb.paper,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(botRaceTo == n ? .white : Color.Kubb.text)
                    }
                    .buttonStyle(.plain)
                }
            }

            if service.botProfiles.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(service.botProfiles) { bot in
                        botTile(bot)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private func botTile(_ bot: BotProfile) -> some View {
        let locked = bot.isClone && records.count < 5
        let note = bot.isClone
            ? (locked ? "\(records.count)/5 matches" : "Learns from your play")
            : "Kubb Coach"
        return Button {
            guard !locked else { return }
            Task {
                if let id = await service.createBotMatch(slug: bot.slug, raceTo: botRaceTo) {
                    path = [.play(matchId: id)]
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: bot.isClone ? "person.crop.circle.badge.questionmark" : "figure.disc.sports")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(locked ? Color.Kubb.textSec : Color.Kubb.matchAccent)
                Text(bot.shortName)
                    .font(KubbFont.inter(14, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                    .lineLimit(1)
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(Color.Kubb.textSec)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            .padding(12)
            .background(Color.Kubb.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(locked ? Color.Kubb.sep : Color.Kubb.matchAccent.opacity(0.3),
                                  style: StrokeStyle(lineWidth: 1, dash: locked ? [4] : []))
            )
            .opacity(locked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(locked || service.isBusy)
    }

    private func newCard<Trailing: View>(
        icon: String, title: String, body: String, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.Kubb.matchAccent)
                .frame(width: 40, height: 40)
                .background(Color.Kubb.matchAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Color.Kubb.text)
                Text(body).font(.subheadline).foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(16)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }
}
