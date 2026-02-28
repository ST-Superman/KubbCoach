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
            VStack(spacing: 6) {
                // Completion Icon with color based on score
                Image(systemName: scoreIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(KubbColors.scoreColor(round.score))
                    .padding(.top, 4)

                // Title
                Text("Round \(round.roundNumber) Complete!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Round Score - Prominent Display
                VStack(spacing: 3) {
                    Text("Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(scoreText)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(KubbColors.scoreColor(round.score))

                        Text("(Par \(round.par))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Score explanation
                    if round.remainingKubbs > 0 {
                        Text("+\(round.remainingKubbs * 2) penalty")
                            .font(.caption2)
                            .foregroundStyle(KubbColors.miss.opacity(0.8))
                    }
                }
                .padding(.vertical, 4)

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
                            .foregroundStyle(KubbColors.scoreColor(session.totalSessionScore ?? 0))
                    }
                }
                .padding(6)
                .background(Color(.darkGray).opacity(0.3))
                .cornerRadius(8)

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
                            .cornerRadius(18)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
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
                            .cornerRadius(18)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
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
