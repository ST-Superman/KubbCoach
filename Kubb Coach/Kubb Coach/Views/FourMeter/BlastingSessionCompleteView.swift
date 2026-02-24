//
//  BlastingSessionCompleteView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import SwiftData

struct BlastingSessionCompleteView: View {
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession
    let sessionManager: TrainingSessionManager
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Success Icon with color based on session score
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(sessionScoreIcon)

                // Title
                Text("Session Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Total Session Score - Prominent
                if let totalScore = session.totalSessionScore {
                    VStack(spacing: 12) {
                        Text("Total Score")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Text(totalScore > 0 ? "+\(totalScore)" : "\(totalScore)")
                                .font(.system(size: 70, weight: .bold))
                                .foregroundStyle(sessionScoreColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("(Par 0)")
                                    .font(.body)
                                    .foregroundStyle(.secondary)

                                if let avgScore = session.averageRoundScore {
                                    Text(String(format: "%+.1f avg", avgScore))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }

                // Session Stats
                VStack(spacing: 16) {
                    StatRow(label: "Total Throws", value: "\(session.totalThrows)")

                    if let avgScore = session.averageRoundScore {
                        StatRow(label: "Avg Round", value: String(format: "%+.1f", avgScore))
                    }

                    if let duration = session.durationFormatted {
                        Divider()
                        StatRow(label: "Duration", value: duration)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                // Best and Worst Rounds
                HStack(spacing: 16) {
                    if let bestRound = session.rounds.min(by: { $0.score < $1.score }) {
                        VStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                            Text("Best Round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Round \(bestRound.roundNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(bestRound.score > 0 ? "+\(bestRound.score)" : "\(bestRound.score)")")
                                .font(.body)
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    if let worstRound = session.rounds.max(by: { $0.score < $1.score }) {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.title2)
                            Text("Worst Round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Round \(worstRound.roundNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(worstRound.score > 0 ? "+\(worstRound.score)" : "\(worstRound.score)")")
                                .font(.body)
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

                // Per-Round Score Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Round Scores")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    VStack(spacing: 8) {
                        ForEach(session.rounds.sorted(by: { $0.roundNumber < $1.roundNumber })) { round in
                            RoundScoreRow(round: round)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                // Done Button
                Button {
                    // Complete the session
                    sessionManager.completeSession()

                    // Return to home root
                    navigationPath.removeLast(navigationPath.count)
                } label: {
                    Text("DONE")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Computed Properties

    private var sessionScoreColor: Color {
        guard let total = session.totalSessionScore else { return .secondary }
        if total < 0 {
            return .green
        } else if total == 0 {
            return .yellow
        } else {
            return .red
        }
    }

    private var sessionScoreIcon: Color {
        guard let total = session.totalSessionScore else { return .yellow }
        if total < 0 {
            return .green
        } else {
            return .yellow
        }
    }
}

// MARK: - RoundScoreRow Component

struct RoundScoreRow: View {
    let round: TrainingRound

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text("Round \(round.roundNumber)")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("(Par \(round.par))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(round.score > 0 ? "+\(round.score)" : "\(round.score)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor)

                Image(systemName: scoreIcon)
                    .font(.caption)
                    .foregroundStyle(scoreColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var scoreColor: Color {
        if round.score < 0 {
            return .green
        } else if round.score == 0 {
            return .yellow
        } else {
            return .red
        }
    }

    private var scoreIcon: String {
        if round.score < 0 {
            return "arrow.down.circle.fill"
        } else if round.score == 0 {
            return "equal.circle.fill"
        } else {
            return "arrow.up.circle.fill"
        }
    }
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: TrainingSession.self, TrainingRound.self, ThrowRecord.self)
    @Previewable @State var session: TrainingSession = {
        let s = TrainingSession(phase: .fourMetersBlasting, sessionType: .blasting, configuredRounds: 9, startingBaseline: .north)
        s.completedAt = Date()

        // Create 9 rounds with various scores
        for i in 1...9 {
            let round = TrainingRound(roundNumber: i, targetBaseline: .north)
            let throwCount = Int.random(in: 2...6)

            for j in 1...throwCount {
                let throwRecord = ThrowRecord(throwNumber: j, result: .hit, targetType: .baselineKubb)
                throwRecord.kubbsKnockedDown = Int.random(in: 0...3)
                round.throwRecords.append(throwRecord)
            }

            round.session = s
            s.rounds.append(round)
        }

        return s
    }()

    @Previewable @State var selectedTab: AppTab = .home
    @Previewable @State var navigationPath = NavigationPath()

    return NavigationStack {
        BlastingSessionCompleteView(
            session: session,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
    }
}
