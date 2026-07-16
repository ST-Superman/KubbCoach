//
//  ThreeForThreeSessionSummaryView.swift
//  Kubb Coach
//
//  Thin wrapper around the canonical SessionRecapView for 3-4-3 sessions.
//  Owns only what the shared recap can't: milestone overlay, share sheet,
//  notes binding, and the "Play Again" navigation toggle dance.
//

import SwiftUI
import SwiftData

struct ThreeForThreeSessionSummaryView: View {
    let session: PressureCookerSession
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingMilestone: MilestoneDefinition?
    @State private var milestoneQueue: [MilestoneDefinition] = []
    @State private var hasCheckedMilestones = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.Kubb.paper.ignoresSafeArea()

            SessionRecapView(pcSession: session)

            RecapFooter(
                primaryLabel: "DONE",
                onShare: { shareSummary() },
                onPrimary: { done() }
            )
        }
        .navigationTitle("Game Complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .overlay(milestoneOverlay)
        .onAppear {
            TabBarVisibility.shared.isHidden = true
            checkMilestones()
        }
        .onDisappear {
            TabBarVisibility.shared.isHidden = false
        }
    }

    // MARK: - Actions

    private func done() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDone()
        }
    }

    private func shareSummary() {
        let text = "3-4-3 · \(session.totalScore) of \(PressureCookerSession.maxTotalScore). \(Int(session.xpEarned.rounded())) XP."
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

        let earned = milestoneService.checkForMilestones(pcSession: session, allSessions: sessionItems)
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
    let session = PressureCookerSession()
    session.frameScores = [10, 7, 13, 8, 11, 9, 6, 12, 10, 8]
    session.completedAt = Date()
    session.xpEarned = 13.0
    container.mainContext.insert(session)

    return NavigationStack {
        ThreeForThreeSessionSummaryView(session: session, onDone: {})
    }
    .modelContainer(container)
}
