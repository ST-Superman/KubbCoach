//
//  ThreeForThreeSessionSummaryView.swift
//  Kubb Coach
//
//  Session complete screen for 3-4-3.
//  Shows total score, all 10 frame scores, XP earned, PBs, and milestones.
//

import SwiftUI
import SwiftData

struct ThreeForThreeSessionSummaryView: View {
    let session: PressureCookerSession
    @Binding var navigateToGame: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // All previous PC sessions for PB comparison
    @Query(
        filter: #Predicate<PressureCookerSession> { $0.completedAt != nil },
        sort: \PressureCookerSession.createdAt, order: .reverse
    )
    private var allPCSessions: [PressureCookerSession]

    @State private var showingMilestone: MilestoneDefinition?
    @State private var milestoneQueue: [MilestoneDefinition] = []
    @State private var hasCheckedMilestones = false

    private let totalFrames = PressureCookerSession.totalFrames
    private let maxScore = PressureCookerSession.maxFrameScore

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header celebration
                headerSection
                    .padding(.top, 24)

                // Total score card
                totalScoreCard

                // 10-frame bowling scorecard
                scorecardSection

                // XP and stats
                statsSection

                // Personal best badge
                if isPersonalBest {
                    personalBestBadge
                }

                // Play again / done
                actionButtons
                    .padding(.bottom, 120)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Game Complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .overlay(milestoneOverlay)
        .onAppear { checkMilestones() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(headerGradient)
                    .frame(width: 96, height: 96)

                Image("three_four_three")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            }

            Text(performanceHeadline)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(performanceSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var headerGradient: LinearGradient {
        LinearGradient(
            colors: [KubbColors.phasePressureCooker.opacity(0.2), KubbColors.phasePressureCooker.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var performanceHeadline: String {
        let total = session.totalScore
        if total >= 100 { return "Century of Pressure!" }
        if total >= 90  { return "Pressure Tested!" }
        if total >= 75  { return "Strong Game!" }
        if total >= 50  { return "Solid Effort" }
        return "Keep Practicing"
    }

    private var performanceSubtitle: String {
        let total = session.totalScore
        let best = session.frameScores.max() ?? 0
        var parts: [String] = []
        if best == 13 { parts.append("Boiling Point achieved") }
        else if best == 12 { parts.append("Steam Rising — 12-point frame") }
        else if best == 11 { parts.append("First Excess reached") }
        else if best == 10 { parts.append("Full Field cleared") }
        if isPersonalBest { parts.append("New personal best!") }
        if parts.isEmpty { parts.append("\(total) points across 10 frames") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Total Score Card

    private var totalScoreCard: some View {
        VStack(spacing: 8) {
            Text("Total Score")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(session.totalScore)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(totalScoreColor)

                Text("/ \(totalFrames * maxScore)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Tier badge
            Text(xpTierLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(KubbColors.phasePressureCooker.opacity(0.15))
                .foregroundStyle(KubbColors.phasePressureCooker)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var totalScoreColor: Color {
        let total = session.totalScore
        if total >= 100 { return KubbColors.swedishGold }
        if total >= 75  { return KubbColors.phasePressureCooker }
        return .primary
    }

    private var xpTierLabel: String {
        let total = session.totalScore
        if total > 75  { return "High Performance · \(Int(session.xpEarned)) XP" }
        if total >= 50 { return "Mid Performance · \(Int(session.xpEarned)) XP" }
        return "Low Performance · \(Int(session.xpEarned)) XP"
    }

    // MARK: - Scorecard

    private var scorecardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Frame Scores")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            // Two rows of 5 frames each
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        SummaryFrameBox(frameNumber: i + 1, score: safeScore(at: i))
                    }
                }
                HStack(spacing: 6) {
                    ForEach(5..<10, id: \.self) { i in
                        SummaryFrameBox(frameNumber: i + 1, score: safeScore(at: i))
                    }
                }
            }
        }
    }

    private func safeScore(at index: Int) -> Int {
        guard index < session.frameScores.count else { return 0 }
        return session.frameScores[index]
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 0) {
            statRow(label: "Best Frame", value: "\(session.frameScores.max() ?? 0) pts")
            Divider().padding(.horizontal, 16)
            statRow(label: "Average Frame", value: String(format: "%.1f pts", averageFrame))
            Divider().padding(.horizontal, 16)
            statRow(label: "Frames with Full Field (10+)", value: "\(fullFieldCount)")
            Divider().padding(.horizontal, 16)
            statRow(label: "Frames with Bonus Points", value: "\(bonusFrameCount)")
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var averageFrame: Double {
        guard !session.frameScores.isEmpty else { return 0 }
        return Double(session.totalScore) / Double(session.frameScores.count)
    }

    private var fullFieldCount: Int {
        session.frameScores.filter { $0 >= 10 }.count
    }

    private var bonusFrameCount: Int {
        session.frameScores.filter { $0 > 10 }.count
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Personal Best

    private var isPersonalBest: Bool {
        let previousBest = allPCSessions
            .filter { $0.id != session.id }
            .map { $0.totalScore }
            .max() ?? 0
        return session.totalScore > previousBest
    }

    private var personalBestBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "medal.fill")
                .foregroundStyle(KubbColors.swedishGold)
            Text("New Personal Best!")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Text("\(session.totalScore) pts")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(KubbColors.swedishGold)
        }
        .padding(14)
        .background(KubbColors.swedishGold.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(KubbColors.swedishGold.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                // Dismiss the summary, then toggle navigateToGame to recreate a fresh game
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    navigateToGame = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        navigateToGame = true
                    }
                }
            } label: {
                Text("Play Again")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KubbColors.phasePressureCooker)
                    .cornerRadius(14)
            }

            Button {
                navigateToGame = false
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(KubbColors.phasePressureCooker)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KubbColors.phasePressureCooker.opacity(0.1))
                    .cornerRadius(14)
            }
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
                milestoneService_markSeen(milestone)
                if milestoneQueue.isEmpty {
                    showingMilestone = nil
                } else {
                    showingMilestone = milestoneQueue.removeFirst()
                }
            }
        }
    }

    private func milestoneService_markSeen(_ milestone: MilestoneDefinition) {
        let service = MilestoneService(modelContext: modelContext)
        service.markAsSeen(milestoneId: milestone.id)
    }
}

// MARK: - Summary Frame Box

private struct SummaryFrameBox: View {
    let frameNumber: Int
    let score: Int

    var body: some View {
        VStack(spacing: 3) {
            Text("\(frameNumber)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            Text("\(score)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
                .frame(height: 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var scoreColor: Color {
        if score == 13 { return KubbColors.swedishGold }
        if score >= 10 { return KubbColors.forestGreen }
        if score >= 7  { return KubbColors.phasePressureCooker }
        return .primary
    }

    private var backgroundColor: Color {
        if score == 13 { return KubbColors.swedishGold.opacity(0.12) }
        if score >= 10 { return KubbColors.forestGreen.opacity(0.10) }
        return Color(.systemBackground)
    }

    private var borderColor: Color {
        if score == 13 { return KubbColors.swedishGold.opacity(0.4) }
        if score >= 10 { return KubbColors.forestGreen.opacity(0.3) }
        return Color(.separator).opacity(0.4)
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
        ThreeForThreeSessionSummaryView(session: session, navigateToGame: .constant(true))
    }
    .modelContainer(container)
}
