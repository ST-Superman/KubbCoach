//
//  InTheRedSessionSummaryView.swift
//  Kubb Coach
//
//  Thin wrapper around the canonical SessionRecapView for In the Red sessions.
//  Owns only what the shared recap can't: milestone overlay, share sheet,
//  notes binding, and the "Play Again" navigation toggle dance.
//

import SwiftUI
import SwiftData

struct InTheRedSessionSummaryView: View {
    let session: PressureCookerSession
    @Binding var navigateToGame: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sessionNotes: String = ""
    @State private var showingMilestone: MilestoneDefinition?
    @State private var milestoneQueue: [MilestoneDefinition] = []
    @State private var hasCheckedMilestones = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.Kubb.paper.ignoresSafeArea()

            SessionRecapView(pcSession: session, notes: $sessionNotes)

            RecapFooter(
                primaryLabel: "PLAY AGAIN",
                onShare: { shareSummary() },
                onPrimary: { playAgain() }
            )
        }
        .navigationTitle("Game Complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .overlay(milestoneOverlay)
        .onAppear { checkMilestones() }
    }

    // MARK: - Actions

    private func playAgain() {
        // Dismiss the summary, then toggle navigateToGame to recreate a fresh game.
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            navigateToGame = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                navigateToGame = true
            }
        }
    }

    private func shareSummary() {
        let signed = session.totalScore >= 0 ? "+\(session.totalScore)" : "\(session.totalScore)"
        let text = "In the Red · \(signed) over \(session.itrTotalRounds) rounds. \(Int(session.xpEarned.rounded())) XP."
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            var presenter = root
            while let next = presenter.presentedViewController { presenter = next }
            activity.popoverPresentationController?.sourceView = presenter.view
            presenter.present(activity, animated: true)
        }
    }

    // MARK: - Milestones

    private func checkMilestones() {
        guard !hasCheckedMilestones else { return }
        hasCheckedMilestones = true

        let milestoneService = MilestoneService(modelContext: modelContext)

        let trainingDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let trainingSessions = (try? modelContext.fetch(trainingDescriptor)) ?? []
        let sessionItems = trainingSessions.map { SessionDisplayItem.local($0) }

        let itrDescriptor = FetchDescriptor<PressureCookerSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let allITR = ((try? modelContext.fetch(itrDescriptor)) ?? [])
            .filter { $0.gameType == PressureCookerGameType.inTheRed.rawValue }

        let earned = milestoneService.checkForMilestonesITR(
            itrSession: session,
            allSessions: sessionItems,
            allITRSessions: allITR
        )
        if !earned.isEmpty {
            milestoneQueue = earned
            showingMilestone = milestoneQueue.removeFirst()
        }
    }

    @ViewBuilder
    private var milestoneOverlay: some View {
        if let milestone = showingMilestone {
            MilestoneAchievementOverlay(milestone: milestone) {
                MilestoneService(modelContext: modelContext).markAsSeen(milestoneId: milestone.id)
                showingMilestone = milestoneQueue.isEmpty ? nil : milestoneQueue.removeFirst()
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PressureCookerSession.self, configurations: config)
    let session = PressureCookerSession(gameType: .inTheRed)
    session.itrTotalRounds = 10
    session.itrMode = "random"
    session.itrRoundScenarios = [
        "4m_8m_king", "8m_8m_king", "8m_king",
        "4m_8m_king", "8m_king", "8m_8m_king",
        "4m_8m_king", "8m_king", "8m_8m_king", "4m_8m_king"
    ]
    session.frameScores = [1, 0, -1, 1, 1, 0, -1, 1, 1, 0]
    session.completedAt = Date()
    session.xpEarned = 13.0
    container.mainContext.insert(session)

    return NavigationStack {
        InTheRedSessionSummaryView(session: session, navigateToGame: .constant(true))
    }
    .modelContainer(container)
}
