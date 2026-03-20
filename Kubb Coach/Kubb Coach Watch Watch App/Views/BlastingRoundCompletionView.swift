//
//  BlastingRoundCompletionView.swift
//  Kubb Coach Watch Watch App
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
    @Binding var navigationPath: NavigationPath

    @State private var navigateToSessionComplete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Completion Icon with color based on score
                Image(systemName: scoreIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(scoreColor)
                    .padding(.top, 4)

                // Title
                Text("Round \(round.roundNumber) Complete!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Round Score - Prominent Display
                VStack(spacing: 4) {
                    Text("Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(scoreText)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(scoreColor)

                        Text("(Par \(round.par))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Score explanation
                    if round.remainingKubbs > 0 {
                        Text("+\(round.remainingKubbs * 2) penalty")
                            .font(.caption2)
                            .foregroundStyle(KubbColors.miss.opacity(0.8))
                    }
                }
                .padding(.vertical, 6)

                // Round Details
                VStack(spacing: 2) {
                    StatRow(label: "Throws Used", value: "\(round.throwRecords.count)")
                    StatRow(label: "Kubbs Cleared", value: "\(round.totalKubbsKnockedDown)/\(round.targetKubbCount ?? 0)")

                    Divider()
                        .padding(.vertical, 2)

                    // Session cumulative score
                    HStack {
                        Text("Session Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(sessionScoreText)
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(sessionScoreColor)
                    }
                }
                .padding(6)
                .background(Color(.darkGray).opacity(0.3))
                .cornerRadius(8)

                // Edit Round button
                Button {
                    // Uncomplete the round so user can edit
                    round.completedAt = nil
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption2)
                        Text("Edit Round")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)

                // Next Round or Complete Button
                if round.roundNumber < 9 {
                    Button {
                        sessionManager.startNextRound()
                        dismiss()
                    } label: {
                        Text("NEXT ROUND")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(KubbColors.swedishBlue)
                            .foregroundStyle(.white)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        navigateToSessionComplete = true
                    } label: {
                        Text("VIEW RESULTS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(KubbColors.forestGreen)
                            .foregroundStyle(.white)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToSessionComplete) {
            SessionCompleteView(
                session: session,
                sessionManager: sessionManager,
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
        KubbColors.scoreColor(round.score)
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
        return KubbColors.scoreColor(total)
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
    @Previewable @State var navPath = NavigationPath()

    round.session = session
    session.rounds = [round]

    return NavigationStack(path: $navPath) {
        BlastingRoundCompletionView(
            session: session,
            round: round,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            navigationPath: $navPath
        )
    }
}
