//
//  InTheRedSessionSummaryView.swift
//  Kubb Coach
//
//  Session complete screen for "In the Red".
//  Shows overall score, per-scenario breakdown, XP, personal best, and milestones.
//

import SwiftUI
import SwiftData

struct InTheRedSessionSummaryView: View {
    let session: PressureCookerSession
    @Binding var navigateToGame: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<PressureCookerSession> { $0.completedAt != nil },
        sort: \PressureCookerSession.createdAt, order: .reverse
    )
    private var allPCSessions: [PressureCookerSession]

    @State private var showingMilestone: MilestoneDefinition?
    @State private var milestoneQueue: [MilestoneDefinition] = []
    @State private var hasCheckedMilestones = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                    .padding(.top, 24)

                totalScoreCard

                scenarioBreakdownSection

                statsSection

                if isPersonalBest {
                    personalBestBadge
                }

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
                    .fill(
                        LinearGradient(
                            colors: [Color.Kubb.phasePC.opacity(0.2), Color.Kubb.phasePC.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                Image("in_the_red")
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

    private var performanceHeadline: String {
        let total = session.totalScore
        let rounds = session.itrTotalRounds
        if total == rounds { return "Perfect Under Pressure!" }
        if total >= rounds - 1 { return "Almost Perfect!" }
        if total > 0 { return "In the Green" }
        if total == 0 { return "Even Game" }
        return "Back to the Range"
    }

    private var performanceSubtitle: String {
        let total = session.totalScore
        let rounds = session.itrTotalRounds
        var parts: [String] = []
        if total == rounds { parts.append("All kings knocked") }
        else {
            let kings = session.frameScores.filter { $0 == 1 }.count
            if kings == 0 { parts.append("No kings this time") }
            else { parts.append("\(kings) king\(kings == 1 ? "" : "s") knocked") }
        }
        if isPersonalBest { parts.append("New personal best!") }
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
                Text(signedScore(session.totalScore))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(totalScoreColor)

                Text("/ +\(session.itrTotalRounds)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("\(Int(session.xpEarned.rounded())) XP earned")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.Kubb.phasePC.opacity(0.15))
                .foregroundStyle(Color.Kubb.phasePC)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var totalScoreColor: Color {
        let s = session.totalScore
        if s > 0 { return Color.Kubb.forestGreen }
        if s < 0 { return Color(.systemRed) }
        return .primary
    }

    // MARK: - Scenario Breakdown

    private var scenarioBreakdownSection: some View {
        let breakdown = buildBreakdown()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Scenario Breakdown")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(breakdown.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider().padding(.horizontal, 16) }
                    scenarioRow(item: item)
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func scenarioRow(item: ScenarioStat) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.scenario.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(item.rounds) round\(item.rounds == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Result dots
            HStack(spacing: 4) {
                ForEach(item.scores, id: \.self) { score in
                    resultDot(score: score)
                }
            }

            Text(signedScore(item.net))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(scoreColor(item.net))
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func resultDot(score: Int) -> some View {
        let (bg, text): (Color, String) = {
            switch score {
            case 1:  return (Color.Kubb.swedishGold, "✓")
            case 0:  return (Color.Kubb.forestGreen.opacity(0.2), "○")
            default: return (Color(.systemRed).opacity(0.15), "✗")
            }
        }()
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(score == 1 ? Color.Kubb.swedishGold : (score == 0 ? Color.Kubb.forestGreen : Color(.systemRed)))
            .frame(width: 22, height: 22)
            .background(bg)
            .cornerRadius(4)
    }

    // MARK: - Stats

    private var statsSection: some View {
        let scores = session.frameScores
        let kings  = scores.filter { $0 == 1 }.count
        let misses = scores.filter { $0 == -1 }.count
        let kubbs  = scores.filter { $0 == 0 }.count

        return VStack(spacing: 0) {
            statRow(label: "Kings knocked (+1)", value: "\(kings)")
            Divider().padding(.horizontal, 16)
            statRow(label: "Kubbs only (0)", value: "\(kubbs)")
            Divider().padding(.horizontal, 16)
            statRow(label: "Missed rounds (−1)", value: "\(misses)")
            Divider().padding(.horizontal, 16)
            statRow(label: "XP earned", value: String(format: "%.1f", session.xpEarned))
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Personal Best

    private var allITRSessions: [PressureCookerSession] {
        allPCSessions.filter { $0.gameType == PressureCookerGameType.inTheRed.rawValue }
    }

    private var isPersonalBest: Bool {
        let previousBest = allITRSessions
            .filter { $0.id != session.id && $0.itrTotalRounds == session.itrTotalRounds }
            .map { $0.totalScore }
            .max()
        guard let best = previousBest else {
            return allITRSessions.filter { $0.id != session.id && $0.itrTotalRounds == session.itrTotalRounds }.isEmpty
        }
        return session.totalScore > best
    }

    private var personalBestBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "medal.fill").foregroundStyle(Color.Kubb.swedishGold)
            Text("New Personal Best!")
                .font(.subheadline).fontWeight(.semibold)
            Spacer()
            Text("\(signedScore(session.totalScore)) pts")
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(Color.Kubb.swedishGold)
        }
        .padding(14)
        .background(Color.Kubb.swedishGold.opacity(0.12))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.Kubb.swedishGold.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    navigateToGame = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        navigateToGame = true
                    }
                }
            } label: {
                Text("Play Again")
                    .font(.headline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.Kubb.phasePC)
                    .cornerRadius(14)
            }

            Button {
                navigateToGame = false
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline).fontWeight(.semibold)
                    .foregroundStyle(Color.Kubb.phasePC)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.Kubb.phasePC.opacity(0.1))
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
                milestoneService_markSeen(milestone)
                showingMilestone = milestoneQueue.isEmpty ? nil : milestoneQueue.removeFirst()
            }
        }
    }

    private func milestoneService_markSeen(_ milestone: MilestoneDefinition) {
        MilestoneService(modelContext: modelContext).markAsSeen(milestoneId: milestone.id)
    }

    // MARK: - Helpers

    private func signedScore(_ score: Int) -> String {
        score >= 0 ? "+\(score)" : "\(score)"
    }

    private func scoreColor(_ score: Int) -> Color {
        if score > 0 { return Color.Kubb.forestGreen }
        if score < 0 { return Color(.systemRed) }
        return .secondary
    }

    // MARK: - Breakdown computation

    private struct ScenarioStat {
        let scenario: InTheRedScenario
        let scores: [Int]
        var rounds: Int { scores.count }
        var net: Int { scores.reduce(0, +) }
    }

    private func buildBreakdown() -> [ScenarioStat] {
        var map: [InTheRedScenario: [Int]] = [:]
        let scenarioStrings = session.itrRoundScenarios
        let scores = session.frameScores

        for (i, rawValue) in scenarioStrings.enumerated() {
            guard i < scores.count,
                  let scenario = InTheRedScenario(rawValue: rawValue) else { continue }
            map[scenario, default: []].append(scores[i])
        }

        // Present in canonical order
        return InTheRedScenario.allCases.compactMap { scenario in
            guard let scores = map[scenario] else { return nil }
            return ScenarioStat(scenario: scenario, scores: scores)
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
