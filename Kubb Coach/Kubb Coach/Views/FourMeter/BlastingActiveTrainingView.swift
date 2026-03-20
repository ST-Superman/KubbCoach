//
//  BlastingActiveTrainingView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/23/26.
//

import SwiftUI
import SwiftData
import OSLog

struct BlastingActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int = 9
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    // Resume session parameter
    var resumeSession: TrainingSession? = nil

    @State private var sessionManager: TrainingSessionManager?
    @State private var currentKubbCount: Int = 0
    @State private var navigateToCompletion = false
    @State private var completedSession: TrainingSession?
    @State private var completedRound: TrainingRound?
    @State private var showThrowFeedback = false
    @State private var lastKubbCount: Int = 0
    @State private var showEndSessionConfirmation = false
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
                        Text("Round \(currentRoundNumber) of 9")
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
            .padding()
            .navigationBarBackButtonHidden(true)

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
        .onAppear {
            // Validate existing session or start new one
            if let manager = sessionManager,
               let session = manager.currentSession {
                // Check if session has temporary ID or invalid rounds
                let sessionIDString = "\(session.persistentModelID)"
                let hasTemporarySessionID = sessionIDString.contains("/p")

                AppLogger.training.debug(" 4M: Validating session - ID: \(sessionIDString), isTemporary: \(hasTemporarySessionID)")

                // Check for rounds with temporary IDs
                var hasInvalidRounds = false
                for (index, round) in session.rounds.enumerated() {
                    let roundIDString = "\(round.persistentModelID)"
                    let hasTemporaryID = roundIDString.contains("/p")
                    AppLogger.training.debug(" 4M: Round \(index) - ID: \(roundIDString), isTemporary: \(hasTemporaryID)")
                    if hasTemporaryID {
                        hasInvalidRounds = true
                    }
                }

                if hasTemporarySessionID || hasInvalidRounds {
                    AppLogger.training.debug(" 4M: Session or rounds have temporary IDs - cleaning up and starting fresh")
                    sessionManager = nil
                }
            }

            if sessionManager == nil {
                // Clean up orphaned incomplete 4m sessions
                cleanupOrphanedSessions(phase: .fourMetersBlasting)

                // Clean up orphaned data before starting session
                DataDeletionService.cleanupOrphanedData(modelContext: modelContext, phase: .fourMetersBlasting)

                startSession()
            } else {
                navigateToCompletion = false
            }
        }
        .onChange(of: isBlastingRoundComplete) { _, isComplete in
            if isComplete {
                handleCompleteRound()
            }
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

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)

        if let existingSession = resumeSession {
            // Resume existing session
            manager.resumeSession(existingSession)
        } else {
            // Start new blasting session
            manager.startBlastingSession()
        }

        sessionManager = manager
    }

    private func confirmThrow() {
        guard let manager = sessionManager else { return }

        manager.recordBlastingThrow(kubbsKnockedDown: currentKubbCount)

        lastKubbCount = currentKubbCount
        showThrowFeedback = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showThrowFeedback = false
        }

        // Haptic feedback matches the throw result
        if currentKubbCount > 0 {
            HapticFeedbackService.shared.hit()
            SoundService.shared.play(.hit)
        } else {
            HapticFeedbackService.shared.miss()
            SoundService.shared.play(.miss)
        }

        currentKubbCount = 0
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager,
              let round = manager.currentRound,
              let session = manager.currentSession else { return }

        let isLastRound = round.roundNumber >= 9
        let roundScore = round.score
        let roundNum = round.roundNumber
        let cleared = round.totalKubbsKnockedDown
        let target = round.targetKubbCount ?? 0

        // Capture session and round before completing (they'll persist even after manager.currentSession/Round become nil)
        completedSession = session
        completedRound = round

        manager.completeRound()
        HapticFeedbackService.shared.success()
        SoundService.shared.play(.roundComplete)

        if isLastRound {
            navigateToCompletion = true
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
        // Show cumulative score from all completed rounds
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

    private var completedRoundsCount: Int {
        sessionManager?.currentSession?.rounds.filter { $0.isComplete }.count ?? 0
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
            // Sort throws by throwNumber to ensure correct order (SwiftData arrays are unordered)
            let sortedThrows = (sessionManager?.currentRound?.throwRecords ?? []).sorted { $0.throwNumber < $1.throwNumber }
            // Use array position (throwNum is 1-based, array is 0-based)
            if throwNum - 1 < sortedThrows.count {
                return sortedThrows[throwNum - 1].result == .hit ? KubbColors.hit : KubbColors.miss
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
            // Sort throws by throwNumber to ensure correct order (SwiftData arrays are unordered)
            let sortedThrows = (sessionManager?.currentRound?.throwRecords ?? []).sorted { $0.throwNumber < $1.throwNumber }
            // Use array position (throwNum is 1-based, array is 0-based)
            if throwNum - 1 < sortedThrows.count {
                return sortedThrows[throwNum - 1].result == .hit ? KubbColors.hit.opacity(0.4) : KubbColors.miss.opacity(0.4)
            }
        }
        return .clear
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
        BlastingActiveTrainingView(
            phase: .fourMetersBlasting,
            sessionType: .blasting,
            selectedTab: $selectedTab,
            navigationPath: $navigationPath
        )
        .modelContainer(for: [TrainingSession.self, TrainingRound.self, ThrowRecord.self], inMemory: true)
    }
}
