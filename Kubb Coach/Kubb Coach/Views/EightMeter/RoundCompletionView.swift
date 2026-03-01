//
//  RoundCompletionView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

#if os(iOS)
import UIKit
#endif
import SwiftUI
import SwiftData

struct RoundCompletionView: View {
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

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(KubbColors.forestGreen)

            Text("Round \(round.roundNumber) Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

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
                    // Complete session BEFORE showing results so milestones are ready
                    sessionManager.completeSession()
                    showSessionComplete = true
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
        .padding(.bottom, 125) // Extra padding for tab bar
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showSessionComplete) {
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
    @State private var showShareSheet = false
    @State private var showLevelUp: (oldLevel: Int, newLevel: Int)?
    @State private var showRankUp: (oldRank: String, newRank: String, newLevel: Int)?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                CelebrationView(accuracy: session.accuracy)
                    .frame(height: 180)
                    .padding(.bottom, 20)

                if !session.newPersonalBests.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(fetchPersonalBests(ids: session.newPersonalBests), id: \.id) { pb in
                            PersonalBestBadge(personalBest: pb)
                        }
                    }
                }

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
                        // Dismiss the sheet and clear navigation to go back to home
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigationPath.removeLast(navigationPath.count)
                        }
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
            .padding(.bottom, 80) // Extra padding for tab bar
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(session: session)
        }
        .overlay {
            if let rankUp = showRankUp {
                RankUpCelebrationOverlay(
                    oldRank: rankUp.oldRank,
                    newRank: rankUp.newRank,
                    newLevel: rankUp.newLevel
                ) {
                    showRankUp = nil
                    // After rank up, show level up if there is one, otherwise milestones
                    if showLevelUp == nil {
                        let milestoneService = MilestoneService(modelContext: modelContext)
                        let unseen = milestoneService.getUnseenMilestones()
                        showingMilestone = unseen.first
                    }
                }
            } else if let levelUp = showLevelUp {
                LevelUpCelebrationOverlay(
                    oldLevel: levelUp.oldLevel,
                    newLevel: levelUp.newLevel
                ) {
                    showLevelUp = nil
                    // After level up, show milestones
                    let milestoneService = MilestoneService(modelContext: modelContext)
                    let unseen = milestoneService.getUnseenMilestones()
                    showingMilestone = unseen.first
                }
            } else if let milestone = showingMilestone {
                MilestoneAchievementOverlay(milestone: milestone) {
                    let milestoneService = MilestoneService(modelContext: modelContext)
                    milestoneService.markAsSeen(milestoneId: milestone.id)
                    let remaining = milestoneService.getUnseenMilestones()
                    showingMilestone = remaining.first
                }
            }
        }
        .onAppear {
            SoundService.shared.play(.sessionComplete)

            // Check for level ups
            checkForLevelUp()

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

    private func checkForLevelUp() {
        // Fetch all completed sessions
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let allSessions = try? modelContext.fetch(descriptor) else { return }

        // Calculate level before this session
        let sessionsBeforeThis = allSessions.filter { $0.id != session.id }
        let previousLevel = PlayerLevelService.computeLevel(from: sessionsBeforeThis)

        // Calculate level after this session (includes this one)
        let currentLevel = PlayerLevelService.computeLevel(from: allSessions)

        // Check if we leveled up
        if currentLevel.levelNumber > previousLevel.levelNumber {
            // Check if it's a rank up (name changed)
            if currentLevel.name != previousLevel.name {
                showRankUp = (previousLevel.name, currentLevel.name, currentLevel.levelNumber)
            } else {
                showLevelUp = (previousLevel.levelNumber, currentLevel.levelNumber)
            }
        }
    }
}

struct ShareSheetView: View {
    let session: TrainingSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var personalBests: [PersonalBest] {
        let descriptor = FetchDescriptor<PersonalBest>()
        let allBests = (try? modelContext.fetch(descriptor)) ?? []
        return allBests.filter { session.newPersonalBests.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                SessionShareCardView(session: session, personalBests: personalBests)
                    .padding(.horizontal)

                Button {
                    shareImage()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Image")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Share Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func shareImage() {
        let cardView = SessionShareCardView(session: session, personalBests: personalBests)
            .frame(width: 350)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0

        guard let image = renderer.uiImage else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var presentingVC = rootVC
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = presentingVC.view
            presentingVC.present(activityVC, animated: true)
        }
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
