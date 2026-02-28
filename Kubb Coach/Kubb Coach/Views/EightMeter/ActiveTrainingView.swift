//
//  ActiveTrainingView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData

struct ActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var sessionManager: TrainingSessionManager?
    @State private var showKingThrowAlert = false
    @State private var navigateToCompletion = false
    @State private var willThrowAtKing = false
    @State private var skipSixthThrow = false
    @State private var showThrowFeedback = false
    @State private var lastThrowResult: ThrowResult?
    @State private var showPerfectRoundCelebration = false
    @State private var hitStreakPersonalBest: Int = 0
    @State private var showEndSessionConfirmation = false

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
            // Header
            Text("Round \(currentRoundNumber) of \(configuredRounds)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Visual throw progress
            VStack(spacing: 4) {
                ThrowProgressIndicator(
                    currentThrow: currentThrowNumber,
                    throwRecords: sessionManager?.currentRound?.throwRecords ?? []
                )
                Text("Throw \(displayThrowNumber) of 6")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Real-time streak tracker
            if currentStreak > 0 {
                StreakTrackerView(currentStreak: currentStreak, personalBest: hitStreakPersonalBest)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            if isRoundComplete || skipSixthThrow {
                // Show Complete Round button after 6 throws (or if user declined king throw)
                Button {
                    handleCompleteRound()
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 70))
                        Text("COMPLETE ROUND")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .background(KubbColors.swedishBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(20)
                }
            } else {
                // Dominant HIT button
                Button {
                    handleHitTap()
                } label: {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 75))
                        Text("HIT")
                            .font(.system(size: 38, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .background(KubbColors.hit.opacity(0.2))
                    .foregroundStyle(KubbColors.hit)
                    .cornerRadius(20)
                }

                // Recessive MISS button
                Button {
                    recordThrow(result: .miss, targetType: .baselineKubb)
                    HapticFeedbackService.shared.miss()
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 35))
                        Text("MISS")
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(KubbColors.miss.opacity(0.2))
                    .foregroundStyle(KubbColors.miss)
                    .cornerRadius(20)
                }
            }

            Spacer()

            // Bottom controls
            HStack {
                Button {
                    sessionManager?.undoLastThrow()
                    HapticFeedbackService.shared.buttonTap()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(currentThrowNumber == 1 || isRoundComplete)

                Spacer()

                Text(String(format: "%.1f%% Accuracy", sessionAccuracy))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showEndSessionConfirmation = true
                    HapticFeedbackService.shared.buttonTap()
                } label: {
                    Label("End", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(KubbColors.miss)
            }
            }
            .padding()
            .navigationBarBackButtonHidden(true)

            // Throw feedback overlay
            if showThrowFeedback, let result = lastThrowResult {
                ThrowFeedbackView(result: result)
            }

            // Perfect round celebration overlay
            if showPerfectRoundCelebration {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(KubbColors.swedishGold)

                        Text("PERFECT ROUND!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(KubbColors.swedishGold)

                        Text("6/6 Hits!")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    .padding(40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            if sessionManager == nil {
                startSession()
            } else {
                // Reset navigation and state flags when returning from RoundCompletionView
                navigateToCompletion = false
                willThrowAtKing = false
                skipSixthThrow = false
            }

            // Fetch current personal best for hit streak
            #if os(iOS)
            let category = BestCategory.mostConsecutiveHits
            let descriptor = FetchDescriptor<PersonalBest>(
                predicate: #Predicate { pb in
                    pb.category == category
                },
                sortBy: [SortDescriptor(\.value, order: .reverse)]
            )
            if let best = try? modelContext.fetch(descriptor).first {
                hitStreakPersonalBest = Int(best.value)
            }
            #endif
        }
        .alert("Throw at King?", isPresented: $showKingThrowAlert) {
            Button("Yes") {
                willThrowAtKing = true
            }
            Button("No") {
                skipSixthThrow = true
            }
        } message: {
            Text("You knocked down all 5 kubbs! Throw your last baton at the king?")
        }
        .confirmationDialog("End Session", isPresented: $showEndSessionConfirmation, titleVisibility: .visible) {
            Button("Save & End", role: nil) {
                handleEndSessionEarly(discard: false)
            }
            Button("Discard Session", role: .destructive) {
                handleEndSessionEarly(discard: true)
            }
            Button("Continue Training", role: .cancel) {}
        } message: {
            Text("You have \(completedRoundsCount) completed round\(completedRoundsCount == 1 ? "" : "s"). Would you like to save your progress or discard this session?")
        }
        .navigationDestination(isPresented: $navigateToCompletion) {
            if let session = sessionManager?.currentSession,
               let round = sessionManager?.currentRound {
                RoundCompletionView(
                    session: session,
                    round: round,
                    sessionManager: sessionManager!,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath
                )
            }
        }
    }

    // MARK: - Actions

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        manager.startSession(phase: phase, sessionType: sessionType, rounds: configuredRounds)
        sessionManager = manager
    }

    private func handleHitTap() {
        // Determine target type based on whether user chose to throw at king
        let targetType: TargetType = (currentThrowNumber == 6 && willThrowAtKing) ? .king : .baselineKubb
        recordThrow(result: .hit, targetType: targetType)

        // Haptic feedback
        HapticFeedbackService.shared.hit()
    }

    private func recordThrow(result: ThrowResult, targetType: TargetType) {
        guard let manager = sessionManager else { return }

        manager.recordThrow(result: result, targetType: targetType)

        // Show visual feedback
        lastThrowResult = result
        showThrowFeedback = true

        // Hide feedback after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showThrowFeedback = false
        }

        // After 5th throw, check if user can throw at king
        if manager.currentRound?.throwRecords.count == 5 && manager.canThrowAtKing {
            showKingThrowAlert = true
        }
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager,
              let round = manager.currentRound else { return }

        // Check if perfect round (6/6 hits, 100% accuracy)
        let isPerfect = round.accuracy == 100.0 && round.throwRecords.count == 6

        manager.completeRound()

        // Haptic feedback
        HapticFeedbackService.shared.success()

        // Show instant celebration for perfect round
        if isPerfect {
            showPerfectRoundCelebration = true
            // Hide after 1.5 seconds, then navigate
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showPerfectRoundCelebration = false
                navigateToCompletion = true
            }
        } else {
            // Navigate immediately if not perfect
            navigateToCompletion = true
        }
    }

    private func handleEndSessionEarly(discard: Bool) {
        guard let manager = sessionManager else { return }

        if discard {
            manager.cancelSession()
        } else {
            if let round = manager.currentRound, !round.throwRecords.isEmpty {
                manager.completeRound()
            }
            manager.completeSession()
        }

        HapticFeedbackService.shared.buttonTap()

        if navigationPath.count > 0 {
            navigationPath.removeLast(navigationPath.count)
        } else {
            dismiss()
        }
    }

    // MARK: - Computed Properties

    private var currentRoundNumber: Int {
        sessionManager?.currentRound?.roundNumber ?? 1
    }

    private var currentThrowNumber: Int {
        (sessionManager?.currentRound?.throwRecords.count ?? 0) + 1
    }

    private var displayThrowNumber: Int {
        let count = sessionManager?.currentRound?.throwRecords.count ?? 0
        return min(count + 1, 6)
    }

    private var isRoundComplete: Bool {
        sessionManager?.currentRound?.isComplete ?? false
    }

    private var sessionAccuracy: Double {
        sessionManager?.sessionAccuracy ?? 0
    }

    private var completedRoundsCount: Int {
        sessionManager?.currentSession?.rounds.filter { $0.isComplete }.count ?? 0
    }

    private var currentStreak: Int {
        guard let session = sessionManager?.currentSession else { return 0 }

        var streak = 0
        // Count backwards through all throws to find current streak
        for round in session.rounds.reversed() {
            for throwRecord in round.throwRecords.reversed() {
                if throwRecord.result == .hit {
                    streak += 1
                } else {
                    return streak
                }
            }
        }
        return streak
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .home
    @Previewable @State var navigationPath = NavigationPath()

    NavigationStack {
        ActiveTrainingView(
            phase: .eightMeters,
            sessionType: .standard,
            configuredRounds: 10,
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
    }
}
