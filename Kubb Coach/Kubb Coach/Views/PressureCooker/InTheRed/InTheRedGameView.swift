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
    var onDone: () -> Void = {}

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
                .padding(.horizontal, KubbSpacing.xl)
                .padding(.top, KubbSpacing.m)
                .padding(.bottom, KubbSpacing.l)
                .background(Color.Kubb.activeSurface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.Kubb.activeBorderSoft)
                        .frame(height: 1)
                }

            ScrollView {
                VStack(spacing: KubbSpacing.xl2) {
                    // Scenario card
                    if !roundSequence.isEmpty {
                        scenarioCard(for: roundSequence[currentRound - 1])
                            .padding(.top, KubbSpacing.xl2)
                    }

                    // Outcome picker
                    outcomePicker
                        .padding(.bottom, KubbSpacing.s)

                    // Record button
                    recordButton
                        .padding(.horizontal, KubbSpacing.xl2)
                        .padding(.bottom, KubbSpacing.giant)
                }
                .padding(.horizontal, KubbSpacing.xl2)
            }
        }
        .background(Color.Kubb.activeBg.ignoresSafeArea())
        .navigationTitle("Round \(currentRound) of \(roundCount)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showAbandonAlert = true } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.Kubb.textSec)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { undoLastRound() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundStyle(roundScores.isEmpty ? Color.Kubb.textTer : Color.Kubb.phasePC)
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
            InTheRedSessionSummaryView(session: session, onDone: onDone)
        }
        .onAppear {
            generateSequence()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Kubb.textSec)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(scoreText(roundScores.reduce(0, +)))
                        .font(KubbFont.fraunces(28, weight: .medium, italic: true))
                        .foregroundStyle(runningScoreColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: roundScores.count)
                    Text("/ +\(roundCount)")
                        .font(KubbFont.mono(11, weight: .medium))
                        .foregroundStyle(Color.Kubb.textSec)
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
            return isCurrent ? Color.Kubb.phasePC.opacity(0.3) : Color.Kubb.activeBorder
        }
        switch s {
        case 1:  return Color.Kubb.swedishGold
        case 0:  return Color.Kubb.forestGreen.opacity(0.6)
        default: return Color.Kubb.miss.opacity(0.7)
        }
    }

    private var runningScoreColor: Color {
        let total = roundScores.reduce(0, +)
        if total > 0 { return Color.Kubb.forestGreen }
        if total < 0 { return Color.Kubb.miss }
        return Color.Kubb.text
    }

    // MARK: - Scenario Card

    private func scenarioCard(for scenario: InTheRedScenario) -> some View {
        VStack(alignment: .leading, spacing: KubbSpacing.m2) {
            HStack {
                VStack(alignment: .leading, spacing: KubbSpacing.xs) {
                    Text("SCENARIO")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Kubb.textSec)
                    Text(scenario.displayName)
                        .font(KubbFont.fraunces(22, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                }
                Spacer()
                batonBadge(count: scenario.batonCount)
            }

            Rectangle()
                .fill(Color.Kubb.sep)
                .frame(height: 0.5)

            Text(scenario.setupDescription)
                .font(KubbFont.inter(13))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: KubbSpacing.xs2) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Kubb.phasePC)
                Text(scenario.throwingOrderSummary)
                    .font(KubbFont.inter(12, weight: .medium))
                    .foregroundStyle(Color.Kubb.phasePC)
            }
        }
        .padding(KubbSpacing.l)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous)
                .strokeBorder(Color.Kubb.phasePC.opacity(0.2), lineWidth: 1)
        )
        .kubbCardShadow()
    }

    private func batonBadge(count: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.Kubb.phasePC)
                    .frame(width: 6, height: 22)
            }
        }
        .padding(KubbSpacing.s)
        .background(Color.Kubb.phasePC.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.s, style: .continuous)
                .strokeBorder(Color.Kubb.phasePC.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Outcome Picker
    // Wheel picker is load-bearing for accessibility/hit-targets (per the
    // handoff: keep `Picker(.wheel)`, just wrap it in a Kubb surface).

    private var outcomePicker: some View {
        VStack(spacing: KubbSpacing.m) {
            Text("ROUND OUTCOME")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .textCase(.uppercase)
                .foregroundStyle(Color.Kubb.textSec)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Outcome", selection: $pendingScore) {
                Text("−1   Miss — kubb(s) still standing").tag(-1)
                Text("  0   Kubbs cleared — missed king").tag(0)
                Text("+1   Complete! — all down + king").tag(1)
            }
            .pickerStyle(.wheel)
            .frame(height: 130)
            .background(Color.Kubb.activeSurface)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml, style: .continuous))
        }
    }

    // MARK: - Record Button (Primary CTA)

    private var recordButton: some View {
        Button(action: recordRound) {
            Text(currentRound < roundCount ? "RECORD & NEXT ROUND" : "FINISH GAME")
                .font(KubbFont.inter(13, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.Kubb.midnightNavy)
                .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
                .shadow(color: Color.Kubb.midnightNavy.opacity(0.22), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
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

        SessionConditionsCapture.captureIfEnabled(for: session, in: modelContext)

        // Fire-and-forget: sweep unsynced sessions to CloudKit (Phase 1 / PR3).
        let contextForSync = modelContext
        Task { @MainActor in
            await CloudKitSyncService.shared.syncUp(context: contextForSync)
        }

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
