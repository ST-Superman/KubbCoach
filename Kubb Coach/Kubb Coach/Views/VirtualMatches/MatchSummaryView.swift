// MatchSummaryView.swift
// Result screen for a finished match: winner banner, final games score, and the
// per-game strip. Rendered inline by `MatchPlayView` once `match_state.status`
// is `finished`. (Deep per-side throwing metrics from `match_stats` are a C1
// polish follow-up; this shows the outcome the scorekeeper needs.)

import SwiftUI

struct MatchSummaryView: View {
    let match: MatchState
    let onDone: () -> Void

    private var winnerName: String? {
        match.winnerSide.map { match.name(for: $0) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                banner
                scoreCard
                if !match.games.isEmpty { gameStrip }
                doneButton
            }
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
    }

    // MARK: - Banner

    private var banner: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.Kubb.swedishGold)
                .padding(.top, 12)
            Text(winnerName.map { "\($0) wins" } ?? "Match complete")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)
            if match.byForfeit {
                Text("By forfeit")
                    .font(.footnote)
                    .foregroundStyle(Color.Kubb.textSec)
            }
        }
    }

    // MARK: - Score

    private var scoreCard: some View {
        HStack(spacing: 16) {
            side(.A)
            Text("\(match.gamesWon.A) – \(match.gamesWon.B)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            side(.B)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func side(_ s: Side) -> some View {
        VStack(spacing: 4) {
            Text(match.name(for: s))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if match.winnerSide == s {
                Text("Winner")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.Kubb.swedishGold)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Per-game strip

    private var gameStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsEyebrow("GAMES").padding(.horizontal, 20)
            SettingsCard {
                ForEach(match.games) { game in
                    SettingsRow(
                        icon: "flag.checkered",
                        tint: Color.Kubb.swedishBlue,
                        label: "Game \(game.gameNumber)",
                        detail: game.winner.map { match.name(for: $0) } ?? "—"
                    ) {
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Done

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Back to matches")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.Kubb.swedishBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
    }
}
