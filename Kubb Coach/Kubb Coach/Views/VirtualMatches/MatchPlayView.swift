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
    case lag, turn
    var id: Int { hashValue }
}

struct MatchPlayView: View {
    @Bindable var service: VirtualMatchService
    let matchId: String
    @Binding var path: [MatchRoute]

    @State private var sheet: PlaySheet?
    @State private var lagA = ""
    @State private var lagB = ""
    @State private var knownDecidedCount = 0
    @State private var interstitial: MatchGameSummary?
    @State private var showAbandon = false
    @State private var showForfeit = false

    private var match: MatchState? {
        guard let m = service.currentMatch, m.matchId == matchId else { return nil }
        return m
    }

    private var activeSide: Side? {
        guard let m = match, m.status == .live else { return nil }
        return m.currentState?.nextSide
    }

    /// Games that actually have a winner. A freshly spawned game sits in `games`
    /// with `winner == nil`, so this — not the raw games count — is what tells us
    /// a game was just won.
    private var decidedGames: [MatchGameSummary] {
        match?.games.filter { $0.winner != nil } ?? []
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
        // Close the lag sheet automatically once both lags are in and play starts.
        .onChange(of: match?.status) { _, status in
            if status == .live, sheet == .lag { sheet = nil }
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
    }

    private var matchTitle: String {
        guard let match else { return "Match" }
        return "\(firstName(match.name(for: .A))) vs \(firstName(match.name(for: .B)))"
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { Task { await service.undoLast() } } label: {
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
                    .font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
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
            primaryButton(title: "Enter lag", icon: "scope") { sheet = .lag }
        } else if let a = activeSide {
            primaryButton(title: "Enter turn · \(firstName(match.name(for: a)))", icon: "figure.disc.sports") {
                sheet = .turn
            }
        }
    }

    private func primaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(Color.Kubb.swedishBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    attackerName: match.name(for: a),
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
                    lagRow(match, .A, selection: $lagA)
                    lagRow(match, .B, selection: $lagB)
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
                            Color.Kubb.swedishBlue.opacity(selection.wrappedValue.isEmpty ? 0.4 : 1),
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
                    .background(Color.Kubb.swedishBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .background(Color.Kubb.swedishBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
