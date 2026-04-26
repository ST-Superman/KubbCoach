//
//  GameHistoryListView.swift
//  Kubb Coach
//
//  Chronological list of all completed game sessions.
//

import SwiftUI
import SwiftData

struct GameHistoryListView: View {
    // Fetch all game sessions; filter completed in-memory to avoid optional-predicate issues.
    @Query(sort: \GameSession.createdAt, order: .reverse) private var allGames: [GameSession]
    private var games: [GameSession] { allGames.filter { $0.completedAt != nil } }

    var body: some View {
        Group {
            if games.isEmpty {
                ContentUnavailableView {
                    Label("No Games Yet", systemImage: "flag.2.crossed")
                } description: {
                    Text("Completed games will appear here. Start tracking from the home screen.")
                }
            } else {
                List {
                    ForEach(games) { game in
                        NavigationLink(value: game) {
                            gameRow(game)
                        }
                        .listRowBackground(Color.adaptiveBackground)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Game History")
        .navigationBarTitleDisplayMode(.inline)
        .background(DesignGradients.stats.ignoresSafeArea())
        .navigationDestination(for: GameSession.self) { session in
            GameTrackerSummaryView(session: session, isPostGame: false)
        }
    }

    private func gameRow(_ session: GameSession) -> some View {
        HStack(spacing: 14) {
            // Mode icon
            ZStack {
                Circle()
                    .fill(modeColor(session).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: session.gameMode.icon)
                    .font(.headline)
                    .foregroundStyle(modeColor(session))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.gameMode.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if let winner = session.winnerSide {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(session.name(for: winner) + " won")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("· Abandoned")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Text(session.createdAt, style: .date)
                    Text("·")
                    Text("\(session.turns.count) turn\(session.turns.count == 1 ? "" : "s")")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            resultBadge(session)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func resultBadge(_ session: GameSession) -> some View {
        if session.gameMode == .competitive, let won = session.userWon {
            Text(won ? "W" : "L")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(won ? Color.Kubb.forestGreen : Color.Kubb.phasePC))
        }
    }

    private func modeColor(_ session: GameSession) -> Color {
        session.gameMode == .competitive ? Color.Kubb.swedishBlue : Color.Kubb.forestGreen
    }
}
