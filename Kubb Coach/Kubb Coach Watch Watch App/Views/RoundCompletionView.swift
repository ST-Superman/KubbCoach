//
//  RoundCompletionView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct RoundCompletionView: View {
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession
    let round: TrainingRound
    let sessionManager: TrainingSessionManager
    @Binding var navigationPath: NavigationPath

    @State private var navigateToSessionComplete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Completion Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(KubbColors.forestGreen)

                // Title
                Text("Round \(round.roundNumber) Complete!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Round Stats
                VStack(spacing: 2) {
                    StatRow(label: "Hits", value: "\(round.hits)")
                    StatRow(label: "Misses", value: "\(round.misses)")
                    StatRow(label: "Accuracy", value: String(format: "%.0f%%", round.accuracy))
                }
                .padding(6)
                .background(Color(.darkGray).opacity(0.3))
                .cornerRadius(8)

                Spacer(minLength: 4)

                // Next Round or Complete Button
                if round.roundNumber < session.configuredRounds {
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
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: TrainingSession.self, TrainingRound.self, ThrowRecord.self)
    @Previewable @State var session = TrainingSession(phase: .eightMeters, sessionType: .standard, configuredRounds: 10, startingBaseline: .north)
    @Previewable @State var round: TrainingRound = {
        let r = TrainingRound(roundNumber: 1, targetBaseline: .north)
        r.throwRecords = [
            ThrowRecord(throwNumber: 1, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 2, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 3, result: .miss, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 4, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 5, result: .miss, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 6, result: .hit, targetType: .baselineKubb)
        ]
        return r
    }()
    @Previewable @State var navPath = NavigationPath()

    NavigationStack(path: $navPath) {
        RoundCompletionView(
            session: session,
            round: round,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            navigationPath: $navPath
        )
    }
}
