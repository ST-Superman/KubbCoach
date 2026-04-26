//
//  InTheRedGameView.swift
//  Kubb Coach
//
//  Active game recording view for "In the Red".
//  Shows the current scenario setup, then a scrollable wheel picker to record −1 / 0 / +1.
//

import SwiftUI
import SwiftData

struct InTheRedGameView: View {
    let roundCount: Int
    let mode: InTheRedMode

    @Binding var navigateToGame: Bool

    @Environment(\.modelContext) private var modelContext

    @State private var currentRound: Int = 1
    @State private var roundScores: [Int] = []
    @State private var roundSequence: [InTheRedScenario] = []
    @State private var pendingScore: Int = 0
    @State private var completedSession: PressureCookerSession?
    @State private var showAbandonAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: round counter + running score
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(Color(.secondarySystemBackground))

            ScrollView {
                VStack(spacing: 24) {
                    // Scenario card
                    if !roundSequence.isEmpty {
                        scenarioCard(for: roundSequence[currentRound - 1])
                            .padding(.top, 24)
                    }

                    // Outcome picker
                    outcomePicker
                        .padding(.bottom, 8)

                    // Record button
                    recordButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle("Round \(currentRound) of \(roundCount)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showAbandonAlert = true } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { undoLastRound() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundStyle(roundScores.isEmpty ? Color(.tertiaryLabel) : Color.Kubb.phasePC)
                }
                .disabled(roundScores.isEmpty)
            }
        }
        .alert("Abandon Game?", isPresented: $showAbandonAlert) {
            Button("Abandon", role: .destructive) { navigateToGame = false }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("Your progress will be lost.")
        }
        .navigationDestination(item: $completedSession) { session in
            InTheRedSessionSummaryView(session: session, navigateToGame: $navigateToGame)
        }
        .onAppear {
            generateSequence()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(scoreText(roundScores.reduce(0, +)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(runningScoreColor)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: roundScores.count)
                    Text("/ +\(roundCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Round progress dots
            HStack(spacing: 5) {
                ForEach(1...roundCount, id: \.self) { round in
                    roundDot(for: round)
                }
            }
        }
    }

    private func roundDot(for round: Int) -> some View {
        let score: Int? = round <= roundScores.count ? roundScores[round - 1] : nil
        let isCurrent = round == currentRound

        return Circle()
            .fill(dotColor(score: score, isCurrent: isCurrent))
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .strokeBorder(isCurrent ? Color.Kubb.phasePC : Color.clear, lineWidth: 1.5)
                    .frame(width: 11, height: 11)
            )
    }

    private func dotColor(score: Int?, isCurrent: Bool) -> Color {
        guard let s = score else {
            return isCurrent ? Color.Kubb.phasePC.opacity(0.3) : Color(.tertiarySystemFill)
        }
        switch s {
        case 1:  return Color.Kubb.swedishGold
        case 0:  return Color.Kubb.forestGreen.opacity(0.6)
        default: return Color(.systemRed).opacity(0.7)
        }
    }

    private var runningScoreColor: Color {
        let total = roundScores.reduce(0, +)
        if total > 0 { return Color.Kubb.forestGreen }
        if total < 0 { return Color(.systemRed) }
        return .primary
    }

    // MARK: - Scenario Card

    private func scenarioCard(for scenario: InTheRedScenario) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scenario")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(scenario.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
                batonBadge(count: scenario.batonCount)
            }

            Divider()

            Text(scenario.setupDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.Kubb.phasePC)
                Text(scenario.throwingOrderSummary)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Kubb.phasePC)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.Kubb.phasePC.opacity(0.2), lineWidth: 1)
        )
    }

    private func batonBadge(count: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.Kubb.phasePC)
                    .frame(width: 6, height: 22)
            }
        }
        .padding(8)
        .background(Color.Kubb.phasePC.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.Kubb.phasePC.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Outcome Picker

    private var outcomePicker: some View {
        VStack(spacing: 12) {
            Text("Round Outcome")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Outcome", selection: $pendingScore) {
                Text("−1   Miss — kubb(s) still standing").tag(-1)
                Text("  0   Kubbs cleared — missed king").tag(0)
                Text("+1   Complete! — all down + king").tag(1)
            }
            .pickerStyle(.wheel)
            .frame(height: 130)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button(action: recordRound) {
            Text(currentRound < roundCount ? "Record & Next Round" : "Finish Game")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(buttonColor)
                .cornerRadius(14)
        }
    }

    private var buttonColor: Color {
        switch pendingScore {
        case 1:  return Color.Kubb.swedishGold
        case -1: return Color(.systemRed)
        default: return Color.Kubb.phasePC
        }
    }

    // MARK: - Logic

    private func generateSequence() {
        switch mode {
        case .random:
            roundSequence = InTheRedScenario.generateRandomSequence(rounds: roundCount)
        case .fixed(let scenario):
            roundSequence = Array(repeating: scenario, count: roundCount)
        }
    }

    private func recordRound() {
        guard currentRound <= roundSequence.count else { return }
        roundScores.append(pendingScore)

        if roundScores.count >= roundCount {
            finishGame()
        } else {
            currentRound += 1
            pendingScore = 0
        }
    }

    private func undoLastRound() {
        guard !roundScores.isEmpty else { return }
        roundScores.removeLast()
        currentRound -= 1
        pendingScore = 0
    }

    private func finishGame() {
        let session = PressureCookerSession(gameType: .inTheRed)
        session.itrTotalRounds = roundCount
        session.itrMode = mode.rawValue
        session.itrRoundScenarios = roundSequence.map { $0.rawValue }
        session.frameScores = roundScores
        session.completedAt = Date()
        session.xpEarned = PlayerLevelService.computeXP(for: session)

        modelContext.insert(session)
        try? modelContext.save()

        completedSession = session
    }

    private func scoreText(_ score: Int) -> String {
        score >= 0 ? "+\(score)" : "\(score)"
    }
}

#Preview {
    NavigationStack {
        InTheRedGameView(
            roundCount: 10,
            mode: .random,
            navigateToGame: .constant(true)
        )
    }
    .modelContainer(for: PressureCookerSession.self, inMemory: true)
}
