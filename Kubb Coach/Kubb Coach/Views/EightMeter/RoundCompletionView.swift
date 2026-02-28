//
//  RoundCompletionView.swift
//  Kubb Coach
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
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var navigateToSessionComplete = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Completion Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(KubbColors.forestGreen)

            // Title
            Text("Round \(round.roundNumber) Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Round Stats
            VStack(spacing: 12) {
                Text("This Round")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Hits")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(round.hits)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Misses")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(round.misses)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Accuracy")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", round.accuracy))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(KubbColors.accuracyColor(for: round.accuracy))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)

            // Session Stats
            VStack(spacing: 12) {
                Text("Session Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Hits")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(session.totalHits)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Misses")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(session.totalMisses)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Accuracy")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", session.accuracy))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(KubbColors.swedishBlue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)

            Spacer()

            // Next Round or Complete Button
            if round.roundNumber < session.configuredRounds {
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
                    
                    navigateToSessionComplete = true
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
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToSessionComplete) {
            SessionCompleteView(session: session, sessionManager: sessionManager, selectedTab: $selectedTab, navigationPath: $navigationPath)
        }
    }
}

// MARK: - SessionCompleteView (iOS)

struct SessionCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let session: TrainingSession
    let sessionManager: TrainingSessionManager
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var showingMilestone: MilestoneDefinition?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Celebration Animation
                CelebrationView(accuracy: session.accuracy)
                    .frame(height: 180)
                    .padding(.bottom, 20)

                // Personal Best Badges
                if !session.newPersonalBests.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(fetchPersonalBests(ids: session.newPersonalBests), id: \.id) { pb in
                            PersonalBestBadge(personalBest: pb)
                        }
                    }
                }

                // Final Stats
                VStack(spacing: 16) {
                    StatRow(label: "Total Throws", value: "\(session.totalThrows)")
                    StatRow(label: "Hits", value: "\(session.totalHits)")
                    StatRow(label: "Misses", value: "\(session.totalMisses)")
                    StatRow(label: "Accuracy", value: String(format: "%.1f%%", session.accuracy))

                    if session.kingThrowCount > 0 {
                        Divider()
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(KubbColors.swedishGold)
                            Text("King Throws")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(session.kingThrowCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }

                    if let duration = session.durationFormatted {
                        Divider()
                        StatRow(label: "Duration", value: duration)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)

                // Best Round
                if let bestRound = session.rounds.max(by: { $0.accuracy < $1.accuracy }) {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(KubbColors.swedishGold)
                            Text("Best Round")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        Text("Round \(bestRound.roundNumber)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(String(format: "%.1f%% accuracy", bestRound.accuracy))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }

                // Done Button
                Button {
                    // Properly complete the session using sessionManager
                    sessionManager.completeSession()

                    // Clear the navigation path to return to home root
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

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .overlay {
            if let milestone = showingMilestone {
                MilestoneAchievementOverlay(milestone: milestone) {
                    // Mark as seen and move to next
                    let milestoneService = MilestoneService(modelContext: modelContext)
                    milestoneService.markAsSeen(milestoneId: milestone.id)

                    // Check for more unseen milestones
                    let remaining = milestoneService.getUnseenMilestones()
                    showingMilestone = remaining.first
                }
            }
        }
        .onAppear {
            // Show first unseen milestone
            let milestoneService = MilestoneService(modelContext: modelContext)
            let unseen = milestoneService.getUnseenMilestones()
            showingMilestone = unseen.first
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

// MARK: - StatRow Component (reused from watch)

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
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
    @Previewable @State var selectedTab: AppTab = .home
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        RoundCompletionView(
            session: session,
            round: round,
            sessionManager: TrainingSessionManager(modelContext: container.mainContext),
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
    }
}
