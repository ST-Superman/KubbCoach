//
//  BlastingSessionCompleteView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

#if os(iOS)
import UIKit
#endif
import SwiftUI
import SwiftData

struct BlastingSessionCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: TrainingSession
    let sessionManager: TrainingSessionManager
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var showingMilestone: MilestoneDefinition?
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                CelebrationView(accuracy: celebrationAccuracy)
                    .frame(height: 180)
                    .padding(.bottom, 20)

                if !session.newPersonalBests.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(fetchPersonalBests(ids: session.newPersonalBests), id: \.id) { pb in
                            PersonalBestBadge(personalBest: pb)
                        }
                    }
                }

                if let totalScore = session.totalSessionScore {
                    VStack(spacing: 12) {
                        Text("Total Score")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Text(totalScore > 0 ? "+\(totalScore)" : "\(totalScore)")
                                .font(.system(size: 70, weight: .bold))
                                .foregroundStyle(KubbColors.scoreColor(totalScore))

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

                HStack(spacing: 16) {
                    if let bestRound = session.rounds.min(by: { $0.score < $1.score }) {
                        VStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(KubbColors.forestGreen)
                                .font(.title2)
                            Text("Best Round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Round \(bestRound.roundNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(bestRound.score > 0 ? "+\(bestRound.score)" : "\(bestRound.score)")")
                                .font(.body)
                                .foregroundStyle(KubbColors.forestGreen)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    if let worstRound = session.rounds.max(by: { $0.score < $1.score }) {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(KubbColors.miss)
                                .font(.title2)
                            Text("Worst Round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Round \(worstRound.roundNumber)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(worstRound.score > 0 ? "+\(worstRound.score)" : "\(worstRound.score)")")
                                .font(.body)
                                .foregroundStyle(KubbColors.miss)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

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

                HStack(spacing: 16) {
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("SHARE")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KubbColors.swedishBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        sessionManager.completeSession()
                        navigationPath.removeLast(navigationPath.count)
                    } label: {
                        Text("DONE")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(KubbColors.forestGreen)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(session: session)
        }
        .overlay {
            if let milestone = showingMilestone {
                MilestoneAchievementOverlay(milestone: milestone) {
                    let milestoneService = MilestoneService(modelContext: modelContext)
                    milestoneService.markAsSeen(milestoneId: milestone.id)
                    let remaining = milestoneService.getUnseenMilestones()
                    showingMilestone = remaining.first
                }
            }
        }
        .onAppear {
            let milestoneService = MilestoneService(modelContext: modelContext)
            let unseen = milestoneService.getUnseenMilestones()
            showingMilestone = unseen.first
        }
    }

    private var celebrationAccuracy: Double {
        guard let total = session.totalSessionScore else { return 50 }
        if total <= -10 {
            return 95
        } else if total <= -5 {
            return 85
        } else if total <= 0 {
            return 70
        } else {
            return 50
        }
    }

    private func fetchPersonalBests(ids: [UUID]) -> [PersonalBest] {
        let descriptor = FetchDescriptor<PersonalBest>(
            predicate: #Predicate { pb in
                ids.contains(pb.id)
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
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
                    .foregroundStyle(KubbColors.scoreColor(round.score))

                Image(systemName: scoreIcon)
                    .font(.caption)
                    .foregroundStyle(KubbColors.scoreColor(round.score))
            }
        }
        .padding(.vertical, 4)
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
