//
//  SessionCompleteView.swift
//  Kubb Coach Watch Watch App
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct SessionCompleteView: View {
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession
    let sessionManager: TrainingSessionManager
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Success Icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.yellow)

                // Title
                Text("Session Complete!")
                    .font(.title3)
                    .fontWeight(.bold)

                // Final Stats
                VStack(spacing: 12) {
                    StatRow(label: "Total Throws", value: "\(session.totalThrows)")
                    StatRow(label: "Hits", value: "\(session.totalHits)")
                    StatRow(label: "Misses", value: "\(session.totalMisses)")
                    StatRow(label: "Accuracy", value: String(format: "%.1f%%", session.accuracy))

                    if session.kingThrowCount > 0 {
                        Divider()
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                            Text("King Throws")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(session.kingThrowCount)")
                                .font(.callout)
                                .fontWeight(.semibold)
                        }
                    }

                    if let duration = session.durationFormatted {
                        Divider()
                        StatRow(label: "Duration", value: duration)
                    }
                }
                .padding()
                .background(Color(.darkGray).opacity(0.3))
                .cornerRadius(12)

                // Best Round
                if let bestRound = session.rounds.max(by: { $0.accuracy < $1.accuracy }) {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Best Round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Round \(bestRound.roundNumber)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text(String(format: "%.1f%% accuracy", bestRound.accuracy))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.darkGray).opacity(0.3))
                    .cornerRadius(12)
                }

                // Done Button
                Button {
                    sessionManager.completeSession()
                    // Clear navigation path to return to root (RoundConfigurationView)
                    navigationPath.removeLast(navigationPath.count)
                } label: {
                    Text("DONE")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .cornerRadius(25)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .focusable()
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: TrainingSession.self, TrainingRound.self, ThrowRecord.self)
    @Previewable @State var session: TrainingSession = {
        let s = TrainingSession(configuredRounds: 10, startingBaseline: .north)
        s.completedAt = Date()

        let round1 = TrainingRound(roundNumber: 1, targetBaseline: .north)
        round1.throwRecords = [
            ThrowRecord(throwNumber: 1, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 2, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 3, result: .miss, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 4, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 5, result: .hit, targetType: .baselineKubb),
            ThrowRecord(throwNumber: 6, result: .hit, targetType: .king)
        ]

        s.rounds = [round1]
        return s
    }()

    @Previewable @State var navPath = NavigationPath()

    NavigationStack(path: $navPath) {
        SessionCompleteView(
            session: session,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            navigationPath: $navPath
        )
    }
}
