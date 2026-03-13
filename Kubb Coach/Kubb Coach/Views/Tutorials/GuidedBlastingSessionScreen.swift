//
//  GuidedBlastingSessionScreen.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import SwiftData

struct GuidedBlastingSessionScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath
    let onComplete: () -> Void

    @State private var showTutorial = true
    @State private var showIntroTooltip = false
    @State private var showScoringTooltip = false
    @State private var showRoundSummaryTooltip = false
    @State private var completedRounds = 0
    @State private var sessionManager: TrainingSessionManager?
    @State private var navigateToCompletion = false
    @State private var completedSession: TrainingSession?
    @State private var completedRound: TrainingRound?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Embedded BlastingActiveTrainingView (modified for guided mode)
                if sessionManager != nil {
                    guidedBlastingView
                }

                // Intro Tooltip
                if showIntroTooltip {
                    OnboardingTooltip(
                        title: "4 Meter Blasting Training",
                        message: "Set up 5 field kubbs on a baseline 4 meters away. You'll complete 3 practice rounds of 6 throws each. The goal is to knock down as many kubbs as possible to beat par. Tap 'Got it!' when you're ready to begin.",
                        position: .center,
                        onDismiss: {
                            showIntroTooltip = false
                            // Show scoring tooltip after intro
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showScoringTooltip = true
                            }
                        }
                    )
                }

                // Scoring Tooltip
                if showScoringTooltip {
                    OnboardingTooltip(
                        title: "Record Your Throws",
                        message: "After each throw, select how many kubbs you knocked down (0-5). Your score is based on par - like golf, lower scores are better! Try to beat par by clearing all kubbs in fewer throws.",
                        position: .center,
                        onDismiss: {
                            showScoringTooltip = false
                        }
                    )
                }

                // Round Summary Tooltip
                if showRoundSummaryTooltip {
                    OnboardingTooltip(
                        title: "Round Complete!",
                        message: "Great job! You'll see your score relative to par with golf terms like Birdie, Par, or Bogey. Each round gets progressively harder with more kubbs.",
                        position: .top,
                        onDismiss: {
                            showRoundSummaryTooltip = false
                        }
                    )
                }
            }
            .navigationBarBackButtonHidden(true)
        }
        .fullScreenCover(isPresented: $showTutorial) {
            KubbFieldSetupView(mode: .blasting) {
                // Tutorial completed - show intro tooltip and start session
                showTutorial = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showIntroTooltip = true
                }
            }
        }
        .onAppear {
            if sessionManager == nil {
                startGuidedSession()
            }
        }
    }

    private var guidedBlastingView: some View {
        GuidedBlastingActiveView(
            sessionManager: $sessionManager,
            navigateToCompletion: $navigateToCompletion,
            completedSession: $completedSession,
            completedRound: $completedRound,
            selectedTab: $selectedTab,
            navigationPath: $navigationPath,
            onRoundComplete: {
                handleRoundComplete()
            },
            onSessionComplete: {
                handleSessionComplete()
            }
        )
        .navigationDestination(isPresented: $navigateToCompletion) {
            if let session = completedSession,
               let round = completedRound,
               let manager = sessionManager {
                BlastingRoundCompletionView(
                    session: session,
                    round: round,
                    sessionManager: manager,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath
                )
            }
        }
    }

    private func startGuidedSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        manager.startSession(phase: .fourMetersBlasting, sessionType: .blasting, rounds: 3)
        sessionManager = manager
    }

    private func handleRoundComplete() {
        completedRounds += 1

        // Show round summary tooltip after first round only
        if completedRounds == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRoundSummaryTooltip = true
            }
        }
    }

    private func handleSessionComplete() {
        // Mark guided session as complete and dismiss
        onComplete()
    }
}

// Separate view to handle the blasting active training logic in guided mode
private struct GuidedBlastingActiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var sessionManager: TrainingSessionManager?
    @Binding var navigateToCompletion: Bool
    @Binding var completedSession: TrainingSession?
    @Binding var completedRound: TrainingRound?
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath
    let onRoundComplete: () -> Void
    let onSessionComplete: () -> Void

    @State private var currentKubbCount: Int = 0
    @State private var showThrowFeedback = false
    @State private var lastKubbCount: Int = 0
    @State private var showInlineRoundResult = false
    @State private var inlineRoundScore: Int = 0
    @State private var inlineRoundNumber: Int = 0
    @State private var inlineKubbsCleared: Int = 0
    @State private var inlineTargetKubbs: Int = 0
    @State private var showNextRoundButton = false

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Round \(currentRoundNumber) of 3")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        if let score = currentRoundScore {
                            HStack(spacing: 4) {
                                Text(score > 0 ? "+\(score)" : "\(score)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(scoreColor(score))
                                Text(golfTerm(for: score))
                                    .font(.caption)
                                    .foregroundStyle(scoreColor(score).opacity(0.8))
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        HStack(spacing: 10) {
                            ForEach(1...6, id: \.self) { throwNum in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(throwSquareFill(for: throwNum))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(throwSquareStroke(for: throwNum), lineWidth: throwNum == currentThrowNumber ? 2.5 : 0)
                                    )
                                    .shadow(color: throwSquareShadow(for: throwNum), radius: throwNum < currentThrowNumber ? 3 : 0, y: 1)
                            }
                        }
                        Text("Throw \(currentThrowNumber) of 6")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    if let target = targetKubbCount {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "flag.fill")
                                    .font(.caption)
                                    .foregroundStyle(KubbColors.phase4m)
                                Text("Par: \(currentPar)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(KubbColors.phase4m.opacity(0.15))
                            .cornerRadius(8)

                            ProgressView(value: Double(totalKubbsKnockedDown), total: Double(target))
                                .progressViewStyle(.linear)
                                .tint(KubbColors.phase4m)

                            HStack(spacing: 4) {
                                Image(systemName: "target")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.4))
                                Text("\(totalKubbsKnockedDown)/\(target) kubbs knocked")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }

                if showInlineRoundResult {
                    inlineRoundResultView
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    if let target = targetKubbCount {
                        kubbClusterView(target: target, knocked: totalKubbsKnockedDown)
                            .padding(.horizontal)
                    }

                    Spacer()

                    KubbCounterGrid(
                        selectedCount: $currentKubbCount,
                        onConfirm: { confirmThrow() },
                        maxCount: remainingKubbs
                    )
                    .padding(.horizontal)
                }

                Spacer()

                HStack {
                    Button {
                        sessionManager?.undoLastThrow()
                        HapticFeedbackService.shared.buttonTap()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.2))
                    .disabled(currentThrowNumber == 1)

                    Spacer()
                }
            }
            .padding()

            if showThrowFeedback {
                NumberFeedbackView(count: lastKubbCount)
            }
        }
        .background(
            LinearGradient(
                colors: [KubbColors.trainingCharcoal, KubbColors.trainingDarkGray],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .onChange(of: isBlastingRoundComplete) { _, isComplete in
            if isComplete {
                handleCompleteRound()
            }
        }
    }

    // MARK: - Kubb Cluster View

    private func kubbClusterView(target: Int, knocked: Int) -> some View {
        let standing = max(0, target - knocked)

        return VStack(spacing: 8) {
            let columns = min(target, 5)
            let rows = (target + columns - 1) / columns

            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        let startIdx = row * columns
                        let endIdx = min(startIdx + columns, target)
                        ForEach(startIdx..<endIdx, id: \.self) { idx in
                            let isStanding = idx < standing
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isStanding ? KubbColors.phase4m : KubbColors.trainingMidGray.opacity(0.3))
                                .frame(width: 22, height: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(isStanding ? KubbColors.phase4m.opacity(0.6) : .clear, lineWidth: 1)
                                )
                                .opacity(isStanding ? 1.0 : 0.3)
                                .animation(.easeInOut(duration: 0.3), value: knocked)
                        }
                    }
                }
            }

            Text("\(standing) standing")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 12)
    }

    // MARK: - Inline Round Result View

    private var inlineRoundResultView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Text("Round \(inlineRoundNumber) Complete")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))

                Text(inlineRoundScore > 0 ? "+\(inlineRoundScore)" : "\(inlineRoundScore)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(inlineRoundScore))
                    .contentTransition(.numericText(value: Double(inlineRoundScore)))
                    .animation(.easeOut(duration: 0.8), value: inlineRoundScore)

                Text(golfTerm(for: inlineRoundScore))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor(inlineRoundScore).opacity(0.8))

                Text("\(inlineKubbsCleared)/\(inlineTargetKubbs) kubbs cleared")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if showNextRoundButton {
                Button {
                    startNextRoundInline()
                } label: {
                    Text("NEXT ROUND")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KubbColors.swedishBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func confirmThrow() {
        guard let manager = sessionManager else { return }

        manager.recordBlastingThrow(kubbsKnockedDown: currentKubbCount)

        lastKubbCount = currentKubbCount
        showThrowFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showThrowFeedback = false
        }

        HapticFeedbackService.shared.success()
        SoundService.shared.play(currentKubbCount > 0 ? .hit : .miss)

        currentKubbCount = 0
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager,
              let round = manager.currentRound,
              let session = manager.currentSession else { return }

        let isLastRound = round.roundNumber >= 3
        let roundScore = round.score
        let roundNum = round.roundNumber
        let cleared = round.totalKubbsKnockedDown
        let target = round.targetKubbCount ?? 0

        // Capture session and round before completing
        completedSession = session
        completedRound = round

        manager.completeRound()
        HapticFeedbackService.shared.success()
        SoundService.shared.play(.roundComplete)

        // Notify parent about round completion
        onRoundComplete()

        if isLastRound {
            // Complete the session and notify parent
            Task { @MainActor in
                await manager.completeSession()
                onSessionComplete()
            }
        } else {
            showInlineResult(score: roundScore, roundNumber: roundNum, kubbsCleared: cleared, targetKubbs: target)
        }
    }

    private func showInlineResult(score: Int, roundNumber: Int, kubbsCleared: Int, targetKubbs: Int) {
        inlineRoundScore = score
        inlineRoundNumber = roundNumber
        inlineKubbsCleared = kubbsCleared
        inlineTargetKubbs = targetKubbs

        withAnimation(.easeInOut(duration: 0.3)) {
            showInlineRoundResult = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNextRoundButton = true
            }
        }
    }

    private func startNextRoundInline() {
        sessionManager?.startNextRound()

        withAnimation(.easeInOut(duration: 0.3)) {
            showInlineRoundResult = false
            showNextRoundButton = false
        }
    }

    // MARK: - Computed Properties

    private var currentRoundNumber: Int {
        sessionManager?.currentRound?.roundNumber ?? 1
    }

    private var currentThrowNumber: Int {
        (sessionManager?.currentRound?.throwRecords.count ?? 0) + 1
    }

    private var targetKubbCount: Int? {
        sessionManager?.targetKubbCount
    }

    private var totalKubbsKnockedDown: Int {
        sessionManager?.currentRound?.totalKubbsKnockedDown ?? 0
    }

    private var isBlastingRoundComplete: Bool {
        sessionManager?.isBlastingRoundComplete ?? false
    }

    private var currentRoundScore: Int? {
        guard let session = sessionManager?.currentSession else { return nil }
        return session.rounds.filter { $0.completedAt != nil }.reduce(0) { $0 + $1.score }
    }

    private var remainingKubbs: Int? {
        guard let target = targetKubbCount else { return nil }
        let remaining = target - totalKubbsKnockedDown
        return max(0, remaining)
    }

    private var currentPar: Int {
        sessionManager?.currentRound?.par ?? 0
    }

    private func scoreColor(_ score: Int) -> Color {
        KubbColors.scoreColor(score)
    }

    private func golfTerm(for score: Int) -> String {
        switch score {
        case ...(-3): return "Albatross!"
        case -2: return "Eagle!"
        case -1: return "Birdie!"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        default: return "Triple Bogey+"
        }
    }

    // MARK: - Throw Progress Squares

    private func throwSquareFill(for throwNum: Int) -> Color {
        if throwNum < currentThrowNumber {
            if let throwRecord = (sessionManager?.currentRound?.throwRecords ?? []).first(where: { $0.throwNumber == throwNum }) {
                return throwRecord.result == .hit ? KubbColors.hit : KubbColors.miss
            }
            return KubbColors.hit
        } else if throwNum == currentThrowNumber {
            return KubbColors.phase4m.opacity(0.3)
        } else {
            return .white.opacity(0.08)
        }
    }

    private func throwSquareStroke(for throwNum: Int) -> Color {
        throwNum == currentThrowNumber ? KubbColors.phase4m : .clear
    }

    private func throwSquareShadow(for throwNum: Int) -> Color {
        if throwNum < currentThrowNumber {
            if let throwRecord = (sessionManager?.currentRound?.throwRecords ?? []).first(where: { $0.throwNumber == throwNum }) {
                return throwRecord.result == .hit ? KubbColors.hit.opacity(0.4) : KubbColors.miss.opacity(0.4)
            }
        }
        return .clear
    }
}
