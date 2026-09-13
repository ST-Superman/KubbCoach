// MatchesHubView.swift
// The entitled Virtual Matches surface (design_handoff, Screen 3), shaped like the
// Kubb Platform /matches page: two tabs — CURRENT and NEW. Current tiers what needs
// attention: a filled incoming-challenge card, prominent "Your turn" rows (leading
// accent edge + game-progress + lag-first), demoted "Waiting" rows, a collapsed
// "Challenges sent" line, and a "View finished matches" link. New offers a managed/
// challenge setup card and "Practice vs a bot" (with an always-visible clone tile).

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
    @State private var outgoingExpanded = false

    private let raceToChoices = [1, 2, 3]

    private var activeMatches: [MatchSummaryRow] {
        service.myMatches.filter { $0.status == .created || $0.status == .live }
    }
    /// Your-turn matches, lag (to-do) first, then oldest-first.
    private var yourTurn: [MatchSummaryRow] {
        activeMatches.filter { $0.turn == "you" }.sorted { a, b in
            if (a.status == .created) != (b.status == .created) { return a.status == .created }
            return a.createdAt < b.createdAt
        }
    }
    private var waiting: [MatchSummaryRow] {
        activeMatches.filter { $0.turn == "opponent" }.sorted { $0.createdAt < $1.createdAt }
    }
    private var incoming: [Challenge] { service.challenges.filter { $0.direction == .incoming } }
    private var outgoing: [Challenge] { service.challenges.filter { $0.direction == .outgoing } }

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
        await service.listChallenges()
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
                        if t == .current, service.attentionCount > 0 {
                            Text("\(service.attentionCount)")
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
        VStack(spacing: 20) {
            if activeMatches.isEmpty && service.challenges.isEmpty {
                if service.isBusy && service.myMatches.isEmpty {
                    ProgressView().padding(.top, 40)
                } else {
                    currentEmptyState
                }
            } else {
                if !incoming.isEmpty { incomingSection }
                if !yourTurn.isEmpty { yourTurnSection }
                if !waiting.isEmpty { waitingSection }
                if !outgoing.isEmpty { outgoingSection }
            }
            if !records.isEmpty { viewFinishedLink }
        }
    }

    private var currentEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.disc.sports")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
            Text("No matches in play")
                .font(.headline)
            Text("Start a match or practice against a bot.")
                .font(.footnote)
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
            Button("Go to New") { withAnimation { tab = .new } }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Kubb.matchAccentInk)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var viewFinishedLink: some View {
        Button { path.append(.history) } label: {
            Text("View finished matches →")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.Kubb.matchAccentInk)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Incoming challenges (filled cards)

    private var incomingSection: some View {
        VStack(spacing: 12) {
            ForEach(incoming) { incomingCard($0) }
        }
    }

    private func incomingCard(_ c: Challenge) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "flag.2.crossed").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(c.otherName) challenged you")
                    .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text("RACE TO \(c.raceTo)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 8)
            Button("Decline") { Task { await service.declineChallenge(id: c.id) } }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
            Button {
                Task { if let mid = await service.acceptChallenge(id: c.id) { path.append(.play(matchId: mid)) } }
            } label: {
                Text("Accept")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "0A6670"))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(hex: "0E7C86"), Color(hex: "0A6670")], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: Color.Kubb.matchAccent.opacity(0.22), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .disabled(service.isBusy)
    }

    // MARK: - Your turn

    private var yourTurnSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR TURN · \(yourTurn.count)")
                .font(KubbType.monoXS).tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.matchAccentInk)
                .padding(.horizontal, 20)
            SettingsCard {
                ForEach(yourTurn) { row in
                    Button { path.append(.play(matchId: row.matchId)) } label: { yourTurnRow(row) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func yourTurnRow(_ row: MatchSummaryRow) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.Kubb.matchAccent).frame(width: 3)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if row.isSimulated == true { botPill }
                    Text(row.opponent ?? "Opponent")
                        .font(KubbFont.inter(15, weight: .semibold))
                        .foregroundStyle(Color.Kubb.text).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.scoreLine)
                        .font(KubbFont.fraunces(20, weight: .medium)).foregroundStyle(Color.Kubb.text)
                    SettingsChevron()
                }
                HStack(spacing: 8) {
                    miniProgress(row)
                    Text(row.status == .created ? "TOSS AT THE KING TO BEGIN" : "GAME \(row.gamesWon.A + row.gamesWon.B + 1)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(0.8)
                        .foregroundStyle(Color.Kubb.textSec)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private func miniProgress(_ row: MatchSummaryRow) -> some View {
        let mine = row.mySide ?? .A
        let mineWon = row.gamesWon[mine]
        let oppWon = row.gamesWon[mine.opponent]
        let slots = Swift.max(row.raceTo, mineWon + oppWon)
        return HStack(spacing: 4) {
            ForEach(0..<slots, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < mineWon ? Color.Kubb.matchAccent
                          : (i < mineWon + oppWon ? Color.Kubb.textSec.opacity(0.5) : Color.Kubb.sep))
                    .frame(width: 14, height: 4)
            }
        }
    }

    private var botPill: some View {
        Text("BOT")
            .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(0.8)
            .foregroundStyle(Color.Kubb.textSec)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.Kubb.textSec.opacity(0.15), in: Capsule())
    }

    // MARK: - Waiting for opponent (demoted)

    private var waitingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WAITING FOR OPPONENT")
                .font(KubbType.monoXS).tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec.opacity(0.6))
                .padding(.horizontal, 20)
            VStack(spacing: 8) {
                ForEach(waiting) { row in
                    Button { path.append(.play(matchId: row.matchId)) } label: { waitingRow(row) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func waitingRow(_ row: MatchSummaryRow) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass").font(.system(size: 13)).foregroundStyle(Color.Kubb.textSec)
            Text(row.opponent ?? "Opponent")
                .font(KubbFont.inter(14, weight: .medium)).foregroundStyle(Color.Kubb.textSec).lineLimit(1)
            if row.isSimulated == true { botPill }
            Spacer(minLength: 8)
            Text(row.scoreLine)
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Color.Kubb.textSec)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(minHeight: 48)
        .background(Color.Kubb.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.Kubb.sep))
        .contentShape(Rectangle())
    }

    // MARK: - Challenges sent (collapsed)

    private var outgoingSection: some View {
        VStack(spacing: 8) {
            if outgoing.count == 1 || outgoingExpanded {
                ForEach(outgoing) { outgoingRow($0) }
            } else {
                Button { withAnimation { outgoingExpanded = true } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane").font(.system(size: 13)).foregroundStyle(Color.Kubb.textSec)
                        Text("\(outgoing.count) challenges sent")
                            .font(KubbFont.inter(13, weight: .medium)).foregroundStyle(Color.Kubb.textSec)
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption).foregroundStyle(Color.Kubb.textSec)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.Kubb.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.Kubb.sep))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func outgoingRow(_ c: Challenge) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "paperplane").font(.system(size: 13)).foregroundStyle(Color.Kubb.textSec)
            Text("Challenge sent · \(firstName(c.otherName))")
                .font(KubbFont.inter(13, weight: .medium)).foregroundStyle(Color.Kubb.textSec).lineLimit(1)
            Spacer(minLength: 8)
            Button("Cancel") { Task { await service.cancelChallenge(id: c.id) } }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold)).foregroundStyle(Color.Kubb.miss)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(Color.Kubb.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.Kubb.sep))
        .disabled(service.isBusy)
    }

    // MARK: - New tab

    private var newContent: some View {
        VStack(spacing: 22) {
            Button { path.append(.newMatch) } label: {
                newCard(
                    icon: "person.2.fill",
                    title: "New virtual match",
                    body: "Keep score for a local opponent, or challenge another Kubb Platform account to play live."
                ) { SettingsChevron() }
            }
            .buttonStyle(.plain)

            practiceCard
        }
        .padding(.horizontal, 16)
    }

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PRACTICE VS A BOT")
                    .font(KubbType.monoXS).tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.Kubb.matchAccentInk)
                Text("Play a bot that throws its own turns — you just score your side. Bot matches count toward your record.")
                    .font(.footnote)
                    .foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
                    ForEach(service.botProfiles.filter { !$0.isClone }) { bot in
                        botTile(bot)
                    }
                }
                if let clone = service.botProfiles.first(where: { $0.isClone }) {
                    cloneTile(clone)
                }
            }
        }
        .padding(16)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private func startBot(_ slug: String) {
        Task {
            if let id = await service.createBotMatch(slug: slug, raceTo: botRaceTo) {
                path = [.play(matchId: id)]
            }
        }
    }

    private func botTile(_ bot: BotProfile) -> some View {
        Button { startBot(bot.slug) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "figure.disc.sports")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.Kubb.matchAccentInk)
                Text(bot.shortName)
                    .font(KubbFont.inter(14, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text).lineLimit(1)
                Text("Kubb Coach")
                    .font(.caption2).foregroundStyle(Color.Kubb.textSec)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            .padding(12)
            .background(Color.Kubb.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.Kubb.matchAccent.opacity(0.3)))
        }
        .buttonStyle(.plain)
        .disabled(service.isBusy)
    }

    /// Clone tile — always shown at full opacity (spans both columns), with a
    /// progress bar toward the 5-match unlock. Locked tap gives a haptic, no nav.
    private func cloneTile(_ clone: BotProfile) -> some View {
        let done = records.count
        let locked = done < 5
        return Button {
            if locked { HapticFeedbackService.shared.buttonTap() }
            else { startBot(clone.slug) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.Kubb.matchAccentInk)
                    Text("Your clone").font(KubbFont.inter(14, weight: .semibold)).foregroundStyle(Color.Kubb.text)
                    Spacer()
                    Text("\(Swift.min(done, 5)) / 5")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.Kubb.matchAccentInk)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.Kubb.sep).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(Color.Kubb.matchAccent)
                            .frame(width: geo.size.width * Swift.min(1, Double(done) / 5), height: 6)
                    }
                }
                .frame(height: 6)
                Text(locked ? "Unlocks at 5 finished matches · plays like you" : "Learns from your play")
                    .font(.caption2).foregroundStyle(Color.Kubb.textSec)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.Kubb.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.Kubb.matchAccent.opacity(0.3)))
        }
        .buttonStyle(.plain)
        .disabled(service.isBusy)
    }

    private func newCard<Trailing: View>(
        icon: String, title: String, body: String, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.Kubb.matchAccentInk)
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
