//
//  BlastingRoundCompletionView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import SwiftData

struct BlastingRoundCompletionView: View {
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession
    let round: TrainingRound
    let sessionManager: TrainingSessionManager
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var navigateToSessionComplete = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Completion Icon with color based on score
            Image(systemName: scoreIcon)
                .font(.system(size: 80))
                .foregroundStyle(scoreColor)

            // Title
            Text("Round \(round.roundNumber) Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Round Score - Prominent Display
            VStack(spacing: 16) {
                Text("Round Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(scoreText)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(scoreColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("(Par \(round.par))")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        if round.remainingKubbs > 0 {
                            Text("+\(round.remainingKubbs * 2) penalty")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                }
            }

            // Round Details
            VStack(spacing: 12) {
                Text("Round Details")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                StatRow(label: "Throws Used", value: "\(round.throwRecords.count)")
                StatRow(label: "Kubbs Cleared", value: "\(round.totalKubbsKnockedDown)/\(round.targetKubbCount ?? 0)")

                Divider()

                // Session cumulative score
                HStack {
                    Text("Session Total")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(sessionScoreText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(sessionScoreColor)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)

            Spacer()

            // Next Round or Complete Button
            if round.roundNumber < 9 {
                Button {
                    sessionManager.startNextRound()
                    dismiss()
                } label: {
                    Text("NEXT ROUND")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    navigateToSessionComplete = true
                } label: {
                    Text("VIEW RESULTS")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToSessionComplete) {
            BlastingSessionCompleteView(
                session: session,
                sessionManager: sessionManager,
                selectedTab: $selectedTab,
                navigationPath: $navigationPath
            )
        }
    }

    // MARK: - Computed Properties

    private var scoreText: String {
        let score = round.score
        if score > 0 {
            return "+\(score)"
        } else {
            return "\(score)"
        }
    }

    private var scoreColor: Color {
        let score = round.score
        if score < 0 {
            return .green
        } else if score == 0 {
            return .yellow
        } else {
            return .red
        }
    }

    private var scoreIcon: String {
        let score = round.score
        if score < 0 {
            return "star.fill"
        } else if score == 0 {
            return "checkmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }

    private var sessionScoreText: String {
        guard let total = session.totalSessionScore else { return "0" }
        if total > 0 {
            return "+\(total)"
        } else {
            return "\(total)"
        }
    }

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
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: TrainingSession.self, TrainingRound.self, ThrowRecord.self)
    @Previewable @State var session = TrainingSession(phase: .fourMetersBlasting, sessionType: .blasting, configuredRounds: 9, startingBaseline: .north)
    @Previewable @State var round: TrainingRound = {
        let r = TrainingRound(roundNumber: 1, targetBaseline: .north)
        r.throwRecords = [
            ThrowRecord(throwNumber: 1, result: .hit, targetType: .baselineKubb)
        ]
        r.throwRecords[0].kubbsKnockedDown = 2
        return r
    }()
    @Previewable @State var selectedTab: AppTab = .home
    @Previewable @State var navigationPath = NavigationPath()

    round.session = session
    session.rounds = [round]

    return NavigationStack {
        BlastingRoundCompletionView(
            session: session,
            round: round,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
    }
}
