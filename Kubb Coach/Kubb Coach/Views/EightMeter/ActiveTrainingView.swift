//
//  ActiveTrainingView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/20/26.
//

import SwiftUI
import SwiftData
import OSLog

struct ActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    // Guided mode parameters (optional, for onboarding)
    var isGuidedMode: Bool = false
    var isTutorialSession: Bool = false
    var onRoundComplete: (() -> Void)? = nil
    var onSessionComplete: (() -> Void)? = nil

    // Resume session parameter
    var resumeSession: TrainingSession? = nil

    @State private var sessionManager: TrainingSessionManager?
    @State private var showKingThrowAlert = false
    @State private var navigateToCompletion = false
    @State private var completedSession: TrainingSession?
    @State private var completedRound: TrainingRound?
    @State private var willThrowAtKing = false
    @State private var skipSixthThrow = false
    @State private var showThrowFeedback = false
    @State private var lastThrowResult: ThrowResult?
    @State private var showPerfectRoundCelebration = false
    @State private var hitStreakPersonalBest: Int = 0
    @State private var showEndSessionConfirmation = false
    @State private var hitRippleTrigger = false
    @State private var missShakeTrigger = false
    @State private var showInlineRoundResult = false
    @State private var inlineRoundAccuracy: Double = 0
    @State private var inlineRoundHits: Int = 0
    @State private var inlineRoundNumber: Int = 0
    @State private var showNextRoundButton = false
    @State private var streakMilestoneText: String? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                HStack {
                    Text("Round \(currentRoundNumber) of \(configuredRounds)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    Text(String(format: "%.1f%%", sessionAccuracy))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.5))
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
                    Text("Throw \(displayThrowNumber) of 6")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                if showInlineRoundResult {
                    inlineRoundResultView
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if isRoundComplete || skipSixthThrow {
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
                        .background(KubbColors.hit.opacity(0.25))
                        .foregroundStyle(KubbColors.hit)
                        .cornerRadius(20)
                    }
                    .rippleEffect(trigger: hitRippleTrigger, color: KubbColors.hit)

                    Button {
                        recordThrow(result: .miss, targetType: .baselineKubb)
                        HapticFeedbackService.shared.miss()
                        SoundService.shared.play(.miss)
                        missShakeTrigger.toggle()
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
                    .screenShake(trigger: missShakeTrigger)
                }

                Spacer()

                HStack(alignment: .center) {
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

                    if currentStreak > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: currentStreak >= 5 ? "flame.fill" : "flame")
                                .font(.system(size: 14 + min(CGFloat(currentStreak), 10) * 0.8))
                                .foregroundStyle(streakColor)
                                .scaleEffect(currentStreak >= 10 ? 1.3 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: currentStreak)

                            Text("\(currentStreak)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(streakColor)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Hide End button in guided mode
                    if !isGuidedMode {
                        Button {
                            showEndSessionConfirmation = true
                            HapticFeedbackService.shared.buttonTap()
                        } label: {
                            Label("End", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.bordered)
                        .tint(KubbColors.miss.opacity(0.5))
                    }
                }
            }
            .padding()
            .padding(.bottom, 80)  // Extra padding for tab bar
            .navigationBarBackButtonHidden(true)

            if showThrowFeedback, let result = lastThrowResult {
                ThrowFeedbackView(result: result)
            }

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

            if let milestone = streakMilestoneText {
                VStack {
                    Spacer()

                    Text(milestone)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(KubbColors.streakFlame)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(KubbColors.trainingDarkGray)
                        .cornerRadius(12)
                        .shadow(color: KubbColors.streakFlame.opacity(0.3), radius: 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 80)
                }
            }
        }
        .momentumBackground(streakCount: currentStreak)
        .preferredColorScheme(.dark)
        .onAppear {
            // Validate existing session or start new one
            if let manager = sessionManager,
               let session = manager.currentSession {
                // Check if session has temporary ID or invalid rounds
                let sessionIDString = "\(session.persistentModelID)"
                let hasTemporarySessionID = sessionIDString.contains("/p")

                AppLogger.training.debug(" 8M: Validating session - ID: \(sessionIDString), isTemporary: \(hasTemporarySessionID)")

                // Check for rounds with temporary IDs
                var hasInvalidRounds = false
                for (index, round) in session.rounds.enumerated() {
                    let roundIDString = "\(round.persistentModelID)"
                    let hasTemporaryID = roundIDString.contains("/p")
                    AppLogger.training.debug(" 8M: Round \(index) - ID: \(roundIDString), isTemporary: \(hasTemporaryID)")
                    if hasTemporaryID {
                        hasInvalidRounds = true
                    }
                }

                if hasTemporarySessionID || hasInvalidRounds {
                    AppLogger.training.debug(" 8M: Session or rounds have temporary IDs - cleaning up and starting fresh")
                    sessionManager = nil
                }
            }

            if sessionManager == nil {
                // Clean up orphaned incomplete 8m sessions
                cleanupOrphanedSessions(phase: .eightMeters)

                // Clean up orphaned data before starting session
                DataDeletionService.cleanupOrphanedData(modelContext: modelContext, phase: .eightMeters)

                startSession()
            } else {
                navigateToCompletion = false
                willThrowAtKing = false
                skipSixthThrow = false
            }

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
            if let session = completedSession,
               let round = completedRound,
               let manager = sessionManager {
                RoundCompletionView(
                    session: session,
                    round: round,
                    sessionManager: manager,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath,
                    onDismissRequest: {
                        navigateToCompletion = false

                        // If in onboarding, complete it automatically
                        if !hasCompletedOnboarding {
                            hasCompletedOnboarding = true
                        }

                        // Dismiss ActiveTrainingView to return to previous screen
                        if navigationPath.count > 0 {
                            navigationPath.removeLast(navigationPath.count)
                        } else {
                            dismiss()
                        }
                    }
                )
            }
        }
    }

    // MARK: - Inline Round Result View

    private var inlineRoundResultView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Text("Round \(inlineRoundNumber) Complete")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))

                CountUpText(value: inlineRoundAccuracy, format: "%.0f%%")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(KubbColors.accuracyColor(for: inlineRoundAccuracy))
                    .animation(.easeOut(duration: 0.8), value: inlineRoundAccuracy)

                Text("\(inlineRoundHits)/6 hits")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
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

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)

        if let existingSession = resumeSession {
            // Resume existing session
            manager.resumeSession(existingSession)
        } else {
            // Start new session
            manager.startSession(phase: phase, sessionType: sessionType, rounds: configuredRounds, isTutorialSession: isTutorialSession)
        }

        sessionManager = manager
    }

    private func handleHitTap() {
        let targetType: TargetType = (currentThrowNumber == 6 && willThrowAtKing) ? .king : .baselineKubb
        recordThrow(result: .hit, targetType: targetType)

        hitRippleTrigger.toggle()
        HapticFeedbackService.shared.hit()
        SoundService.shared.play(.hit)
    }

    private func recordThrow(result: ThrowResult, targetType: TargetType) {
        guard let manager = sessionManager else { return }

        manager.recordThrow(result: result, targetType: targetType)

        lastThrowResult = result
        showThrowFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showThrowFeedback = false
        }

        let newStreak = currentStreak
        if result == .hit && (newStreak == 5 || newStreak == 10 || newStreak == 15 || newStreak == 20) {
            SoundService.shared.play(.streakMilestone)
            withAnimation(.spring(response: 0.3)) {
                streakMilestoneText = "🔥 x\(newStreak)!"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    streakMilestoneText = nil
                }
            }
        }

        if manager.currentRound?.throwRecords.count == 5 && manager.canThrowAtKing {
            showKingThrowAlert = true
        }
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager,
              let round = manager.currentRound,
              let session = manager.currentSession else { return }

        let isPerfect = round.accuracy == 100.0 && round.throwRecords.count == 6
        let isLastRound = round.roundNumber >= configuredRounds
        let roundAcc = round.accuracy
        let roundHitCount = round.hits
        let roundNum = round.roundNumber

        // Capture session and round before completing (they'll persist even after manager.currentSession/Round become nil)
        completedSession = session
        completedRound = round

        manager.completeRound()
        HapticFeedbackService.shared.success()
        SoundService.shared.play(.roundComplete)

        if isPerfect {
            SoundService.shared.play(.perfectRound)
            showPerfectRoundCelebration = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showPerfectRoundCelebration = false
                if isLastRound {
                    if isGuidedMode {
                        onSessionComplete?()
                    } else {
                        navigateToCompletion = true
                    }
                } else {
                    showInlineResult(accuracy: roundAcc, hits: roundHitCount, roundNumber: roundNum)
                    // Call onRoundComplete for guided mode after round 1
                    if isGuidedMode && roundNum == 1 {
                        onRoundComplete?()
                    }
                }
            }
        } else if isLastRound {
            if isGuidedMode {
                onSessionComplete?()
            } else {
                navigateToCompletion = true
            }
        } else {
            showInlineResult(accuracy: roundAcc, hits: roundHitCount, roundNumber: roundNum)
            // Call onRoundComplete for guided mode after round 1
            if isGuidedMode && roundNum == 1 {
                onRoundComplete?()
            }
        }
    }

    private func showInlineResult(accuracy: Double, hits: Int, roundNumber: Int) {
        inlineRoundAccuracy = accuracy
        inlineRoundHits = hits
        inlineRoundNumber = roundNumber

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

        willThrowAtKing = false
        skipSixthThrow = false

        withAnimation(.easeInOut(duration: 0.3)) {
            showInlineRoundResult = false
            showNextRoundButton = false
        }
    }

    private func handleEndSessionEarly(discard: Bool) {
        guard let manager = sessionManager else { return }

        if discard {
            manager.cancelSession()
            HapticFeedbackService.shared.buttonTap()

            if navigationPath.count > 0 {
                navigationPath.removeLast(navigationPath.count)
            } else {
                dismiss()
            }
        } else {
            if let round = manager.currentRound, !round.throwRecords.isEmpty {
                manager.completeRound()
            }

            Task { @MainActor in
                await manager.completeSession()
                HapticFeedbackService.shared.buttonTap()

                if navigationPath.count > 0 {
                    navigationPath.removeLast(navigationPath.count)
                } else {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Throw Square Helpers

    private func throwSquareFill(for throwNum: Int) -> Color {
        if throwNum < currentThrowNumber {
            // Sort throws by throwNumber to ensure correct order (SwiftData arrays are unordered)
            let sortedThrows = (sessionManager?.currentRound?.throwRecords ?? []).sorted { $0.throwNumber < $1.throwNumber }
            // Use array position (throwNum is 1-based, array is 0-based)
            if throwNum - 1 < sortedThrows.count {
                return sortedThrows[throwNum - 1].result == .hit ? KubbColors.hit : KubbColors.miss
            }
            return KubbColors.hit
        } else if throwNum == currentThrowNumber {
            return KubbColors.swedishBlue.opacity(0.3)
        } else {
            return .white.opacity(0.08)
        }
    }

    private func throwSquareStroke(for throwNum: Int) -> Color {
        throwNum == currentThrowNumber ? KubbColors.swedishBlue : .clear
    }

    private func throwSquareShadow(for throwNum: Int) -> Color {
        if throwNum < currentThrowNumber {
            // Sort throws by throwNumber to ensure correct order (SwiftData arrays are unordered)
            let sortedThrows = (sessionManager?.currentRound?.throwRecords ?? []).sorted { $0.throwNumber < $1.throwNumber }
            // Use array position (throwNum is 1-based, array is 0-based)
            if throwNum - 1 < sortedThrows.count {
                return sortedThrows[throwNum - 1].result == .hit ? KubbColors.hit.opacity(0.4) : KubbColors.miss.opacity(0.4)
            }
        }
        return .clear
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
        // Sort rounds by round number descending (most recent first)
        let sortedRounds = session.rounds.sorted { $0.roundNumber > $1.roundNumber }

        for round in sortedRounds {
            // Sort throws by throw number descending (most recent first)
            let sortedThrows = round.throwRecords.sorted { $0.throwNumber > $1.throwNumber }
            for throwRecord in sortedThrows {
                if throwRecord.result == .hit {
                    streak += 1
                } else {
                    return streak
                }
            }
        }
        return streak
    }

    private var streakColor: Color {
        if currentStreak > hitStreakPersonalBest && hitStreakPersonalBest > 0 {
            return KubbColors.swedishGold
        } else if currentStreak >= 10 {
            return KubbColors.streakFlame
        } else if currentStreak >= 5 {
            return KubbColors.streakGlow
        } else {
            return .white.opacity(0.7)
        }
    }

    private func cleanupOrphanedSessions(phase: TrainingPhase) {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt == nil }
        )

        do {
            let incompleteSessions = try modelContext.fetch(descriptor)
            let orphanedSessions = incompleteSessions.filter { $0.phase == phase }

            for session in orphanedSessions {
                modelContext.delete(session)
            }
            if !orphanedSessions.isEmpty {
                try modelContext.save()
                AppLogger.database.info(" Cleaned up \(orphanedSessions.count) orphaned \(phase.rawValue) sessions")
            }
        } catch {
            AppLogger.database.error(" Failed to cleanup orphaned sessions: \(error)")
        }
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .lodge
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
