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

    @State private var showSessionComplete = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: scoreIcon)
                .font(.system(size: 80))
                .foregroundStyle(KubbColors.scoreColor(round.score))

            Text("Round \(round.roundNumber) Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                Text("Round Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(scoreText)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(KubbColors.scoreColor(round.score))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("(Par \(round.par))")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        if round.remainingKubbs > 0 {
                            Text("+\(round.remainingKubbs * 2) penalty")
                                .font(.caption)
                                .foregroundStyle(KubbColors.miss.opacity(0.8))
                        }
                    }
                }
            }

            VStack(spacing: 12) {
                Text("Round Details")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                StatRow(label: "Throws Used", value: "\(round.throwRecords.count)")
                StatRow(label: "Kubbs Cleared", value: "\(round.totalKubbsKnockedDown)/\(round.targetKubbCount ?? 0)")

                Divider()

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

            if round.roundNumber < 9 {
                Button {
                    sessionManager.startNextRound()
                    dismiss()
                } label: {
                    Text("NEXT ROUND")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KubbColors.swedishBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    // Complete session BEFORE showing results so milestones are ready
                    Task { @MainActor in
                        await sessionManager.completeSession()
                        showSessionComplete = true
                    }
                } label: {
                    Text("VIEW RESULTS")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KubbColors.forestGreen)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .padding(.bottom, 120) // Extra padding for tab bar
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showSessionComplete) {
            BlastingSessionCompleteView(
                session: session,
                sessionManager: sessionManager,
                selectedTab: $selectedTab,
                navigationPath: $navigationPath
            )
        }
    }

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
