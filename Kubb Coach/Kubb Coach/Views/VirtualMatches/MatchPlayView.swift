// MatchPlayView.swift
// The live match screen for single-device managed (scorekeeper) play, shaped to
// mirror the Kubb Platform's mobile match client (kubb-platform
// `src/components/match-client.tsx`): a score header, the always-visible pitch
// board, a "who's up" line, and a primary action button that opens a SHEET for
// lag entry (`status == created`) or turn entry (`status == live`). Every
// mutation commits the full returned `match_state`; undo uses `undo_target`; a
// game-won interstitial fires as the decided-game count ticks up.

import SwiftUI

private enum PlaySheet: Identifiable {
    case lag, turn, log
    var id: Int { hashValue }
}

struct MatchPlayView: View {
    @Bindable var service: VirtualMatchService
    let matchId: String
    @Binding var path: [MatchRoute]
    @Environment(\.modelContext) private var modelContext

    @State private var sheet: PlaySheet?
    @State private var lagA = ""
    @State private var lagB = ""
    @State private var knownDecidedCount = 0
    @State private var interstitial: MatchGameSummary?
    @State private var showAbandon = false
    @State private var showForfeit = false
    @State private var showUndo = false
    @State private var confirmRewindSeq: Int?

    // Bot ("Practice vs Kubb Coach") state — nil for human/managed matches.
    @State private var botCtx: BotMatchContext?
    @State private var lastBotDriveKey: String?

    private var match: MatchState? {
        guard let m = service.currentMatch, m.matchId == matchId else { return nil }
        return m
    }

    /// Non-nil "gameId:seq" when a live match is waiting on the bot's turn.
    private var botTurnSignal: String? {
        guard let botCtx, let m = match, m.status == .live,
              let st = m.currentState, st.nextSide == botCtx.botSide,
              let gid = m.currentGameId, let seq = m.nextSeq else { return nil }
        return "\(gid):\(seq)"
    }

    /// Whether the currently-active side is the bot (turn form is suppressed then).
    private var isBotTurn: Bool {
        guard let botCtx, let a = activeSide else { return false }
        return a == botCtx.botSide
    }

    /// Roll the bot's turn and submit it, once per (game, seq). Mirrors the web
    /// client's drive loop (match-client.tsx:193-236).
    private func driveBotIfNeeded() async {
        guard let botCtx, let key = botTurnSignal, key != lastBotDriveKey,
              let state = service.currentMatch?.currentState else { return }
        lastBotDriveKey = key
        let draft = BotEngine.generateBotTurn(botCtx.stats, state, botCtx.botSide)
        try? await Task.sleep(nanoseconds: 900_000_000)   // brief "throwing…" beat
        await service.submitTurn(draft)
    }

    private var activeSide: Side? {
        guard let m = match, m.status == .live else { return nil }
        return m.currentState?.nextSide
    }

    /// Whether the local user may act for `side`. The bot never (it auto-plays); an
    /// account side only when it's the signed-in user's; a managed/nil-owned side
    /// always (single-device scorekeeper enters both). Mirrors the platform's
    /// `canAct` (match-client.tsx). For an account match this restricts the user to
    /// their own side; the opponent scores theirs on their device.
    private func canAct(_ side: Side) -> Bool {
        guard let match else { return false }
        if botCtx?.botSide == side { return false }
        guard let p = match.participant(side) else { return false }
        if let uid = p.userId { return uid.lowercased() == service.myUserId }
        return true
    }

    /// A side the local user may NOT act for (the account opponent), if any.
    private func waitingOpponentName(_ match: MatchState) -> String {
        for side in [Side.A, Side.B] where !canAct(side) {
            return firstName(match.name(for: side))
        }
        return "your opponent"
    }

    /// True during the lag phase when there's still a side the user may lag.
    private func canEnterAnyLag(_ match: MatchState) -> Bool {
        [Side.A, Side.B].contains { canAct($0) && match.lag.value(for: $0) == nil }
    }

    /// A real account-vs-account match: an opponent side is owned by a *different*
    /// account (not me, not a managed/nil player, not a bot). These are the matches
    /// that need live Realtime sync (the opponent acts on their own device); managed
    /// and bot matches are single-device.
    private var isAccountMatch: Bool {
        guard let match, botCtx == nil else { return false }
        return [Side.A, Side.B].contains { side in
            guard let uid = match.participant(side)?.userId?.lowercased() else { return false }
            return uid != service.myUserId
        }
    }

    /// Games that actually have a winner. A freshly spawned game sits in `games`
    /// with `winner == nil`, so this — not the raw games count — is what tells us
    /// a game was just won.
    private var decidedGames: [MatchGameSummary] {
        match?.games.filter { $0.winner != nil } ?? []
    }

    /// Persist the finished match into local progression (XP + milestones), once.
    /// Idempotent by matchId, so calling on both open and status-change is safe.
    private func recordIfFinished() {
        guard let match, match.status == .finished else { return }
        VirtualMatchProgressionService.recordFinishedMatch(match, context: modelContext)
    }

    var body: some View {
        Group {
            if let match {
                switch match.status {
                case .finished:
                    MatchSummaryView(match: match) { path = [] }
                case .abandoned:
                    closedState(title: "Match abandoned", icon: "xmark.circle.fill", tint: Color.Kubb.textSec)
                default:
                    liveContent(match)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle(matchTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task {
            if match == nil { await service.refreshMatch(id: matchId) }
            knownDecidedCount = decidedGames.count
            recordIfFinished()   // catch an already-finished match on open
            botCtx = await service.botMatchContext(matchId: matchId)
            await driveBotIfNeeded()   // bot may be first (won the lag)
            // Live account matches: subscribe for the opponent's moves.
            if isAccountMatch, match?.status != .finished {
                await service.subscribeToMatch(matchId)
            }
        }
        .onDisappear { Task { await service.unsubscribe() } }
        .onChange(of: botTurnSignal) { _, sig in
            if sig != nil { Task { await driveBotIfNeeded() } }
        }
        .onChange(of: decidedGames.count) { _, newCount in
            guard let match = service.currentMatch else { return }
            // Celebrate only when a NEW game gets a winner, and not on the final
            // game (the match summary takes over there).
            if newCount > knownDecidedCount, match.status != .finished {
                interstitial = decidedGames.last
            }
            knownDecidedCount = newCount
        }
        // Close the lag sheet automatically once both lags are in and play starts;
        // record progression the moment a match finishes.
        .onChange(of: match?.status) { _, status in
            if status == .live, sheet == .lag { sheet = nil }
            if status == .finished {
                recordIfFinished()
                Task { await service.unsubscribe() }
            }
        }
        .sheet(item: $sheet) { which in sheetContent(which) }
        .sheet(item: $interstitial) { summary in gameWonInterstitial(summary) }
        .confirmationDialog("Abandon match?", isPresented: $showAbandon, titleVisibility: .visible) {
            Button("Abandon match", role: .destructive) { Task { await service.abandon() } }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("The match ends with no result.")
        }
        .confirmationDialog("Forfeit match?", isPresented: $showForfeit, titleVisibility: .visible) {
            Button("Forfeit to opponent", role: .destructive) { Task { await service.forfeit() } }
            Button("Keep playing", role: .cancel) {}
        }
        .confirmationDialog("Undo last turn?", isPresented: $showUndo, titleVisibility: .visible) {
            Button("Undo last turn", role: .destructive) { Task { await service.undoLast() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will rewind the match to before your last turn was entered, and you'll be asked to record your turn again.")
        }
    }

    private var matchTitle: String {
        guard let match else { return "Match" }
        return "\(firstName(match.name(for: .A))) vs \(firstName(match.name(for: .B)))"
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showUndo = true } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(match?.undoTarget == nil || service.isBusy)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) { showForfeit = true } label: {
                    Label("Forfeit", systemImage: "flag.fill")
                }
                Button(role: .destructive) { showAbandon = true } label: {
                    Label("Abandon", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .disabled(match == nil)
        }
    }

    // MARK: - Live content

    @ViewBuilder
    private func liveContent(_ match: MatchState) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                scoreHeader(match)

                if let state = match.currentState {
                    PitchBoardView(
                        state: state,
                        nameA: match.name(for: .A),
                        nameB: match.name(for: .B),
                        done: false
                    )
                    .padding(.horizontal, 16)
                }

                whoseTurnLine(match)

                if let err = service.lastError {
                    Text(err)
                        .font(.footnote).foregroundStyle(Color.Kubb.miss)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }

                actionButton(match)

                if !(match.currentTurns.isEmpty) {
                    Button {
                        confirmRewindSeq = nil
                        sheet = .log
                    } label: {
                        Text("View turn log")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.Kubb.matchAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private func scoreHeader(_ match: MatchState) -> some View {
        VStack(spacing: 6) {
            Text("RACE TO \(match.raceTo) · \(statusEyebrow(match))")
                .font(.system(.caption2, design: .monospaced)).tracking(1.5)
                .foregroundStyle(Color.Kubb.textSec)
            HStack(spacing: 16) {
                sideName(match, .A)
                Text("\(match.gamesWon.A) – \(match.gamesWon.B)")
                    .font(KubbFont.fraunces(30, weight: .semibold)).monospacedDigit()
                sideName(match, .B)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func sideName(_ match: MatchState, _ side: Side) -> some View {
        HStack(spacing: 6) {
            Circle().fill(MatchSideColor.of(side)).frame(width: 9, height: 9)
            Text(firstName(match.name(for: side)))
                .font(.subheadline.weight(.semibold)).lineLimit(1)
        }
    }

    private func statusEyebrow(_ match: MatchState) -> String {
        switch match.status {
        case .created:   return "LAG PHASE"
        case .finished:  return "FINAL"
        case .abandoned: return "ABANDONED"
        case .live:      return "GAME \(Swift.max(1, match.games.count))"
        }
    }

    @ViewBuilder
    private func whoseTurnLine(_ match: MatchState) -> some View {
        let text: String? = {
            switch match.status {
            case .created: return "Enter the lag to begin"
            case .live:
                if let a = activeSide, let cap = match.currentState?.roundCap {
                    return "\(firstName(match.name(for: a))) to throw · \(cap) batons"
                }
                return nil
            default: return nil
            }
        }()
        if let text {
            Text(text)
                .font(.system(.caption, design: .monospaced)).tracking(0.5)
                .foregroundStyle(Color.Kubb.textSec)
        }
    }

    @ViewBuilder
    private func actionButton(_ match: MatchState) -> some View {
        if match.status == .created {
            if canEnterAnyLag(match) {
                primaryButton(title: "Enter lag", icon: "scope") { sheet = .lag }
            } else {
                waitingBanner("Waiting for \(waitingOpponentName(match))’s lag")
            }
        } else if isBotTurn {
            botThrowingBanner
        } else if let a = activeSide {
            if canAct(a) {
                primaryButton(title: "Enter turn · \(firstName(match.name(for: a)))", icon: "figure.disc.sports") {
                    sheet = .turn
                }
            } else {
                waitingBanner("Waiting for \(firstName(match.name(for: a)))")
            }
        }
    }

    private func waitingBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .foregroundStyle(Color.Kubb.textSec)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
        }
        .frame(maxWidth: .infinity).frame(height: 52)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var botThrowingBanner: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Color.Kubb.matchAccent)
            Text("\(botCtx?.displayName ?? "Kubb Coach") is throwing…")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
        }
        .frame(maxWidth: .infinity).frame(height: 52)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func primaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(Color.Kubb.matchAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ which: PlaySheet) -> some View {
        switch which {
        case .lag:
            lagSheet
        case .turn:
            if let match, let state = match.currentState, let a = activeSide {
                TurnFormView(
                    state: state,
                    side: a,
                    nameA: match.name(for: .A),
                    nameB: match.name(for: .B),
                    isBusy: service.isBusy
                ) { draft in
                    Task {
                        await service.submitTurn(draft)
                        if service.lastError == nil { sheet = nil }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        case .log:
            turnLogSheet
        }
    }

    // MARK: - Turn log (per-turn rewind)

    private var turnLogSheet: some View {
        let turns = match?.currentTurns ?? []
        let gameId = match?.currentGameId
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("TURN LOG")
                    .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1.2)
                    .foregroundStyle(Color.Kubb.textSec)

                if turns.isEmpty {
                    Text("No turns yet this game.")
                        .font(.footnote).foregroundStyle(Color.Kubb.textSec)
                }

                ForEach(turns.reversed()) { turn in
                    turnLogRow(turn, gameId: gameId)
                }
            }
            .padding(20)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func turnLogRow(_ turn: TurnRow, gameId: String?) -> some View {
        let laterCount = (match?.currentTurns.filter { !$0.voided && $0.seq > turn.seq }.count) ?? 0
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text("#\(turn.seq)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.Kubb.textSec)
                    .frame(width: 26, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(firstName(match?.name(for: turn.side)).uppercased())\(turn.voided ? " · VOIDED" : "")")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(turn.voided ? Color.Kubb.textSec : MatchSideColor.of(turn.side))
                    Text(KubbRules.turnText(turn))
                        .font(.caption)
                        .foregroundStyle(Color.Kubb.textSec)
                        .strikethrough(turn.voided)
                }
                Spacer(minLength: 0)
                if !turn.voided, confirmRewindSeq == nil, gameId != nil {
                    Button {
                        confirmRewindSeq = turn.seq
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.Kubb.matchAccent)
                            .frame(width: 32, height: 32)
                            .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rewind to before turn \(turn.seq)")
                }
            }

            if confirmRewindSeq == turn.seq, let gameId {
                HStack(spacing: 10) {
                    Text("Rewind to before #\(turn.seq)?\(laterCount > 0 ? " Also voids \(laterCount) later turn(s)." : "")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.Kubb.miss)
                    Spacer(minLength: 0)
                    Button("Rewind") {
                        Task {
                            await service.rewind(toSeq: turn.seq, gameId: gameId)
                            confirmRewindSeq = nil
                            if service.lastError == nil { sheet = nil }
                        }
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(Color.Kubb.miss)
                    Button("Keep") { confirmRewindSeq = nil }
                        .font(.caption.weight(.bold)).foregroundStyle(Color.Kubb.textSec)
                }
            }
            Divider()
        }
    }

    private var lagSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("LAG — TOSS AT THE KING")
                    .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1.2)
                    .foregroundStyle(Color.Kubb.textSec)
                Text("Lower is better — how close each toss lands to the king decides who throws first. A tie re-lags.")
                    .font(.footnote).foregroundStyle(Color.Kubb.textSec)

                if let match {
                    ForEach([Side.A, Side.B].filter { canAct($0) }, id: \.self) { side in
                        lagRow(match, side, selection: side == .A ? $lagA : $lagB)
                    }
                }

                if let err = service.lastError {
                    Text(err).font(.footnote).foregroundStyle(Color.Kubb.miss)
                }
            }
            .padding(20)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func lagRow(_ match: MatchState, _ side: Side, selection: Binding<String>) -> some View {
        if let stored = match.lag.value(for: side) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.Kubb.forestGreen)
                Text("\(firstName(match.name(for: side))) locked · \(KubbRules.lagLabel(stored))")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(match.name(for: side))
                    .font(.system(.caption2, design: .monospaced).weight(.bold)).tracking(1)
                    .foregroundStyle(Color.Kubb.textSec)
                Picker("Lag", selection: selection) {
                    ForEach(KubbRules.lagOptions) { opt in Text(opt.label).tag(opt.value) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).frame(height: 48)
                .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.Kubb.sep))

                Button {
                    Task { await service.submitLag(side: side, value: selection.wrappedValue) }
                } label: {
                    Text("Enter lag")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(
                            Color.Kubb.matchAccent.opacity(selection.wrappedValue.isEmpty ? 0.4 : 1),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .foregroundStyle(.white)
                }
                .disabled(selection.wrappedValue.isEmpty || service.isBusy)
            }
            .padding(12)
            .background(Color.Kubb.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Interstitial + closed states

    private func gameWonInterstitial(_ summary: MatchGameSummary) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.Kubb.swedishGold)
                .padding(.top, 36)
            Text("Game \(summary.gameNumber) complete").font(.title3.weight(.bold))
            if let winner = summary.winner, let match {
                Text("\(match.name(for: winner)) takes the game.")
                    .font(.subheadline).foregroundStyle(Color.Kubb.textSec)
            }
            Spacer()
            Button { interstitial = nil } label: {
                Text("Next game")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.Kubb.matchAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func closedState(title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44, weight: .semibold)).foregroundStyle(tint)
            Text(title).font(.title3.weight(.bold))
            Button { path = [] } label: {
                Text("Back to matches")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.Kubb.matchAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
