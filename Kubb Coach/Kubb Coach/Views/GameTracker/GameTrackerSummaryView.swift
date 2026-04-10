//
//  GameTrackerSummaryView.swift
//  Kubb Coach
//
//  Post-game summary: result, stats, and turn history for a completed game.
//

import SwiftUI
import SwiftData

struct GameTrackerSummaryView: View {
    let session: GameSession
    @Environment(\.dismiss) private var dismiss

    private var sorted: [GameTurn] { session.sortedTurns }

    // Stats computed from all user turns (both sides for phantom; user's side for competitive)
    private var userTurns: [GameTurn] { session.userTurns }

    private var displayWinnerName: String {
        guard let winner = session.winnerSide else { return "Game Abandoned" }
        return session.name(for: winner)
    }

    private var resultEmoji: String {
        guard let winner = session.winnerSide else { return "" }
        if session.gameMode == .phantom { return "" }
        return winner == session.userGameSide ? "" : ""
    }

    private var endReasonText: String {
        switch GameEndReason(rawValue: session.endReason ?? "") {
        case .kingKnocked: return "King knocked"
        case .earlyKing: return "King knocked early"
        case .abandoned: return "Game abandoned"
        case nil: return ""
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                resultHeader
                statsGrid
                turnHistorySection
            }
            .padding()
            .padding(.bottom, 60)
        }
        .navigationTitle("Game Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        VStack(spacing: 12) {
            if session.winnerSide != nil {
                Text(resultEmoji)
                    .font(.system(size: 52))
            }

            Text(displayWinnerName + (session.winnerSide != nil ? " Wins" : ""))
                .titleStyle(tracking: 0.3)
                .multilineTextAlignment(.center)

            if !endReasonText.isEmpty {
                Text(endReasonText)
                    .descriptionStyle()
            }

            // Mode pill
            Text(session.gameMode.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(KubbColors.swedishBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(KubbColors.swedishBlue.opacity(0.1)))

            Text(session.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .elevatedCard()
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .headlineStyle()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCell(
                    label: "Total Turns",
                    value: "\(userTurns.count)",
                    icon: "arrow.clockwise"
                )

                statCell(
                    label: "Avg Progress",
                    value: formattedAvg,
                    icon: "chart.bar.fill",
                    valueColor: avgColor
                )

                statCell(
                    label: "Best Turn",
                    value: bestTurnLabel,
                    icon: "star.fill",
                    valueColor: KubbColors.forestGreen
                )

                statCell(
                    label: "Worst Turn",
                    value: worstTurnLabel,
                    icon: "arrow.down.circle.fill",
                    valueColor: KubbColors.miss
                )

                statCell(
                    label: "Advantage Lines",
                    value: "\(session.advantageLineTurns.count)",
                    icon: "exclamationmark.triangle.fill",
                    valueColor: session.advantageLineTurns.isEmpty ? .primary : KubbColors.phase4m
                )

                statCell(
                    label: "King Shots",
                    value: "\(session.kingOpportunityTurns.count)",
                    icon: "crown.fill",
                    valueColor: KubbColors.swedishGold
                )
            }
        }
    }

    private func statCell(
        label: String,
        value: String,
        icon: String,
        valueColor: Color = .primary
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(valueColor.opacity(0.8))

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(valueColor)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .dataCard()
    }

    // MARK: - Turn History

    private var turnHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turn History")
                .headlineStyle()

            if sorted.isEmpty {
                Text("No turns recorded.")
                    .descriptionStyle()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(sorted, id: \.id) { turn in
                    turnRow(turn)
                }
            }
        }
    }

    private func turnRow(_ turn: GameTurn) -> some View {
        let side = turn.attackingGameSide
        let sideName = session.name(for: side)
        let isUserTurn: Bool = {
            if session.gameMode == .phantom { return true }
            return side == session.userGameSide
        }()

        return HStack(spacing: 12) {
            Text("\(turn.turnNumber)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 20, alignment: .trailing)

            Text(sideName)
                .font(.subheadline)
                .foregroundStyle(isUserTurn ? KubbColors.swedishBlue : .secondary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            Spacer()

            if turn.wasEarlyKing {
                Label("Early King", systemImage: "crown.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(KubbColors.miss)
            } else {
                Text(formattedProgress(turn.progress))
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(progressColor(turn.progress))
                    .frame(width: 44, alignment: .trailing)
            }

            if turn.kingThrown && !turn.wasEarlyKing {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(KubbColors.swedishGold)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isUserTurn
                      ? KubbColors.swedishBlue.opacity(0.04)
                      : Color.clear)
        )
    }

    // MARK: - Computed helpers

    private var formattedAvg: String {
        guard !userTurns.isEmpty else { return "—" }
        let avg = session.averageUserProgress
        return String(format: avg >= 0 ? "+%.1f" : "%.1f", avg)
    }

    private var avgColor: Color {
        guard !userTurns.isEmpty else { return .secondary }
        return session.averageUserProgress >= 0 ? KubbColors.forestGreen : KubbColors.miss
    }

    private var bestTurnLabel: String {
        guard let best = session.bestUserTurn else { return "—" }
        return formattedProgress(best.progress)
    }

    private var worstTurnLabel: String {
        guard let worst = session.worstUserTurn else { return "—" }
        return formattedProgress(worst.progress)
    }

    private func formattedProgress(_ n: Int) -> String {
        n > 0 ? "+\(n)" : "\(n)"
    }

    private func progressColor(_ n: Int) -> Color {
        if n < 0 { return KubbColors.miss }
        if n == 0 { return .secondary }
        return KubbColors.forestGreen
    }
}
