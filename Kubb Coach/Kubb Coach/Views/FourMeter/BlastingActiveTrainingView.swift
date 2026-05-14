//
//  BlastingActiveTrainingView.swift
//  Kubb Coach
//
//  V1A "Refined Classic" chrome adapted from the 8m reference impl in
//  ActiveTrainingView.swift. State machine and TrainingSessionManager
//  API are unchanged — visual-only refactor.
//

import SwiftUI
import SwiftData
import OSLog

struct BlastingActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int = 9
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    var resumeSession: TrainingSession? = nil

    @State private var sessionManager: TrainingSessionManager?
    @State private var currentKubbCount: Int = 0
    @State private var navigateToCompletion = false
    @State private var completedSession: TrainingSession?
    @State private var completedRound: TrainingRound?
    @State private var showThrowFeedback = false
    @State private var lastKubbCount: Int = 0

    // V1A overlays
    @State private var showPauseOverlay = false
    @State private var showInlineRoundResult = false
    @State private var inlineRoundScore: Int = 0
    @State private var inlineRoundNumber: Int = 0
    @State private var inlineKubbsCleared: Int = 0
    @State private var inlineTargetKubbs: Int = 0
    @State private var inlineRoundThrows: [ThrowRecord] = []

    // Slot scale animation (index 0–5)
    @State private var slotScale: [CGFloat] = Array(repeating: 1.0, count: 6)
    // Pending tap (auto-commits after a short preview)
    @State private var pendingCommitToken: Int = 0

    var body: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                roundProgressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                throwStripCard
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                if let target = targetKubbCount {
                    kubbClusterView(target: target, knocked: totalKubbsKnockedDown)
                        .padding(.top, 16)
                }

                Spacer(minLength: 0)

                actionZone
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                bottomDock
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
            }

            if showThrowFeedback {
                NumberFeedbackView(count: lastKubbCount)
                    .allowsHitTesting(false)
            }

            if showInlineRoundResult {
                roundResultOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }

            if showPauseOverlay {
                pauseOverlay
                    .transition(.opacity)
                    .zIndex(11)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { handleOnAppear() }
        .onChange(of: isBlastingRoundComplete) { _, isComplete in
            if isComplete { handleCompleteRound() }
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

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("4 METERS · BLASTING")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.Kubb.activeTextFaint)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Round \(currentRoundNumber)")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(Color.Kubb.activeText)
                    Text("/ \(configuredRounds)")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color.Kubb.activeTextDim)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SESSION")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.Kubb.activeTextFaint)
                    .textCase(.uppercase)

                Text(sessionScoreText)
                    .font(KubbFont.fraunces(28, weight: .medium, italic: true))
                    .foregroundStyle(Color.Kubb.scoreColor(sessionScoreValue))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Round Progress Bar

    private var roundProgressBar: some View {
        HStack(spacing: 4) {
            ForEach(1...configuredRounds, id: \.self) { n in
                RoundedRectangle(cornerRadius: 2)
                    .fill(roundSegmentColor(for: n))
                    .frame(height: n == currentRoundNumber ? 5 : 3)
                    .shadow(
                        color: n == currentRoundNumber ? Color.Kubb.phase4m.opacity(0.6) : .clear,
                        radius: 5
                    )
                    .animation(.easeInOut(duration: 0.2), value: currentRoundNumber)
            }
        }
    }

    private func roundSegmentColor(for n: Int) -> Color {
        if n < currentRoundNumber {
            let rounds = sessionManager?.currentSession?.rounds.sorted { $0.roundNumber < $1.roundNumber } ?? []
            if n - 1 < rounds.count {
                return Color.Kubb.scoreColor(rounds[n - 1].score)
            }
            return Color.Kubb.forestGreen
        } else if n == currentRoundNumber {
            return Color.Kubb.phase4m
        } else {
            return colorScheme == .dark
                ? Color.white.opacity(0.07)
                : Color.black.opacity(0.06)
        }
    }

    // MARK: - Throw Strip Card

    private var throwStripCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("THROWS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.Kubb.activeTextFaint)
                    .textCase(.uppercase)
                Spacer()
                HStack(spacing: 2) {
                    Text("\(min(currentThrowNumber, 6))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Kubb.activeText)
                    Text("/ 6")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Kubb.activeTextFaint)
                }
            }

            HStack(spacing: 8) {
                ForEach(1...6, id: \.self) { slot in
                    throwSlot(for: slot)
                        .scaleEffect(slotScale[slot - 1])
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.Kubb.activeSurfaceTinted)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.Kubb.activeBorderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func throwSlot(for slot: Int) -> some View {
        let sortedThrows = (sessionManager?.currentRound?.throwRecords ?? [])
            .sorted { $0.throwNumber < $1.throwNumber }
        let isPast = slot < currentThrowNumber
        let isCurrent = slot == currentThrowNumber && !isRoundComplete

        Group {
            if isPast {
                let kubbs = slot - 1 < sortedThrows.count ? (sortedThrows[slot - 1].kubbsKnockedDown ?? 0) : 0
                let isHit = kubbs > 0
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHit ? Color.Kubb.forestGreen : Color.Kubb.phasePC)
                    .frame(height: 56)
                    .overlay(
                        Text("\(kubbs)")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                    )
                    .shadow(
                        color: (isHit ? Color.Kubb.forestGreen : Color.Kubb.phasePC).opacity(0.33),
                        radius: 8, y: 4
                    )
            } else if isCurrent {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.Kubb.phase4m)
                    .frame(height: 56)
                    .overlay(
                        Text("\(slot)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.Kubb.phase4m, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.Kubb.activeSurfaceTinted)
                    .frame(height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.Kubb.activeBorderSoft, lineWidth: 1)
                    )
                    .overlay(
                        Text("\(slot)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.Kubb.activeTextFaint)
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Kubb cluster (standing kubbs viz)

    private func kubbClusterView(target: Int, knocked: Int) -> some View {
        let standing = max(0, target - knocked)
        let columns = min(target, 5)
        let rows = (target + columns - 1) / columns

        return VStack(spacing: 8) {
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        let startIdx = row * columns
                        let endIdx = min(startIdx + columns, target)
                        ForEach(startIdx..<endIdx, id: \.self) { idx in
                            let isStanding = idx < standing
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isStanding ? Color.Kubb.phase4m : Color.Kubb.activeSurfaceTinted)
                                .frame(width: 22, height: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(
                                            isStanding ? Color.Kubb.phase4m.opacity(0.6) : Color.Kubb.activeBorderSoft,
                                            lineWidth: 1
                                        )
                                )
                                .opacity(isStanding ? 1.0 : 0.45)
                                .animation(.easeInOut(duration: 0.3), value: knocked)
                        }
                    }
                }
            }

            Text("\(standing) STANDING · \(knocked) DOWN")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(Color.Kubb.activeTextFaint)
        }
    }

    // MARK: - Action Zone (0..max count buttons)

    private var actionZone: some View {
        HStack(spacing: 8) {
            ForEach(0...5, id: \.self) { count in
                kubbCountButton(count: count)
            }
        }
    }

    @ViewBuilder
    private func kubbCountButton(count: Int) -> some View {
        let isDisabled = remainingKubbs.map { count > $0 } ?? false
        let isSelected = currentKubbCount == count && count > 0

        Button {
            handleKubbCountTap(count)
        } label: {
            Text("\(count)")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(
                    isDisabled ? Color.Kubb.activeTextFaint
                    : isSelected ? .white
                    : Color.Kubb.activeText
                )
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isSelected ? Color.Kubb.swedishBlue : Color.Kubb.activeSurfaceTinted
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected ? Color.Kubb.swedishBlue
                            : Color.Kubb.activeBorderSoft,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: isSelected ? Color.Kubb.swedishBlue.opacity(0.3) : .clear,
                    radius: 8, y: 4
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1.0)
    }

    private func handleKubbCountTap(_ count: Int) {
        currentKubbCount = count
        HapticFeedbackService.shared.buttonTap()

        // Auto-commit after 300ms preview (lets the user see what they tapped).
        pendingCommitToken &+= 1
        let token = pendingCommitToken
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard token == pendingCommitToken else { return }
            confirmThrow()
        }
    }

    // MARK: - Bottom Dock

    private var bottomDock: some View {
        HStack {
            Button {
                sessionManager?.undoLastThrow()
                HapticFeedbackService.shared.buttonTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                    Text("Undo")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.Kubb.activeTextDim)
            }
            .disabled(currentThrowNumber == 1)
            .opacity(currentThrowNumber == 1 ? 0.4 : 1.0)

            Spacer()

            if let score = currentRoundScore {
                HStack(spacing: 5) {
                    Text(score > 0 ? "+\(score)" : "\(score)")
                        .font(.system(size: 14, weight: .heavy))
                    Text(golfTerm(for: score))
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                }
                .foregroundStyle(Color.Kubb.scoreColor(score))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.Kubb.scoreColor(score).opacity(0.12))
                .overlay(
                    Capsule().strokeBorder(Color.Kubb.scoreColor(score).opacity(0.33), lineWidth: 1)
                )
                .clipShape(Capsule())
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: score)
            }

            Spacer()

            Button {
                showPauseOverlay = true
                HapticFeedbackService.shared.buttonTap()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 11))
                    Text("End")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.Kubb.missBright)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.Kubb.miss.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.04)
                : Color.black.opacity(0.04)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.Kubb.activeBorderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Round Result Overlay (V1A hero — score variant)

    private var roundResultOverlay: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("ROUND \(inlineRoundNumber) COMPLETE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Color.Kubb.activeTextFaint)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 8) {
                    Text("ROUND SCORE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.Kubb.activeTextFaint)
                        .textCase(.uppercase)

                    Text(inlineRoundScore > 0 ? "+\(inlineRoundScore)" : "\(inlineRoundScore)")
                        .font(.system(size: 96, weight: .heavy, design: .rounded))
                        .tracking(-3)
                        .foregroundStyle(Color.Kubb.scoreColor(inlineRoundScore))
                        .shadow(
                            color: colorScheme == .dark
                                ? Color.Kubb.scoreColor(inlineRoundScore).opacity(0.3)
                                : .clear,
                            radius: 20
                        )
                        .monospacedDigit()

                    Text(golfTerm(for: inlineRoundScore))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.Kubb.scoreColor(inlineRoundScore).opacity(0.85))

                    Text("\(inlineKubbsCleared)/\(inlineTargetKubbs) kubbs cleared")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.Kubb.activeTextDim)
                        .padding(.top, 4)

                    // Per-throw dot row showing kubbs knocked
                    HStack(spacing: 6) {
                        ForEach(inlineRoundThrows.sorted { $0.throwNumber < $1.throwNumber }) { record in
                            throwResultChip(for: record)
                        }
                    }
                    .padding(.top, 20)
                }

                Spacer()

                Button {
                    startNextRoundInline()
                } label: {
                    HStack(spacing: 8) {
                        Text("NEXT ROUND")
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(1.5)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.Kubb.swedishBlueDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.Kubb.swedishBlueDeep.opacity(0.27), radius: 12, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
        }
    }

    @ViewBuilder
    private func throwResultChip(for record: ThrowRecord) -> some View {
        let kubbs = record.kubbsKnockedDown ?? 0
        let isHit = kubbs > 0
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isHit ? Color.Kubb.forestGreen : Color.Kubb.phasePC)
                .frame(width: 22, height: 22)
            Text("\(kubbs)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Pause Overlay

    private var pauseOverlay: some View {
        ZStack {
            (colorScheme == .dark
                ? Color.black.opacity(0.72)
                : Color.white.opacity(0.85))
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.Kubb.activeSurfaceTinted)
                        .frame(width: 56, height: 56)
                        .overlay(Circle().strokeBorder(Color.Kubb.activeBorder, lineWidth: 1))

                    HStack(spacing: 6) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.Kubb.activeText)
                                .frame(width: 5, height: 22)
                        }
                    }
                }

                Text("Session Paused")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(Color.Kubb.activeText)
                    .padding(.top, 18)

                Text("Round \(currentRoundNumber) · throw \(min(currentThrowNumber, 6)) of 6")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.Kubb.activeTextDim)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    Button {
                        showPauseOverlay = false
                        handleEndSessionEarly(discard: false)
                    } label: {
                        Text("END SESSION")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.Kubb.missBright)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.Kubb.miss.opacity(0.4), lineWidth: 1)
                            )
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showPauseOverlay = false
                        }
                    } label: {
                        Text("RESUME")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.Kubb.swedishBlueDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.top, 24)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
            .background(Color.Kubb.activeSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.Kubb.activeBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Actions

    private func handleOnAppear() {
        if let manager = sessionManager, let session = manager.currentSession {
            let sessionIDString = "\(session.persistentModelID)"
            let hasTemporarySessionID = sessionIDString.contains("/p")
            var hasInvalidRounds = false
            for round in session.rounds {
                if "\(round.persistentModelID)".contains("/p") { hasInvalidRounds = true }
            }
            if hasTemporarySessionID || hasInvalidRounds { sessionManager = nil }
        }

        if sessionManager == nil {
            cleanupOrphanedSessions(phase: .fourMetersBlasting)
            DataDeletionService.cleanupOrphanedData(modelContext: modelContext, phase: .fourMetersBlasting)
            startSession()
        } else {
            navigateToCompletion = false
        }
    }

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        if let existingSession = resumeSession {
            _ = manager.resumeSession(existingSession)
        } else {
            manager.startBlastingSession()
        }
        sessionManager = manager
    }

    private func confirmThrow() {
        guard let manager = sessionManager else { return }

        manager.recordBlastingThrow(kubbsKnockedDown: currentKubbCount)

        // Animate the slot that was just recorded
        let throwIdx = (manager.currentRound?.throwRecords.count ?? 1) - 1
        if throwIdx >= 0 && throwIdx < 6 {
            withAnimation(.easeOut(duration: 0.1)) { slotScale[throwIdx] = 1.05 }
            withAnimation(.easeOut(duration: 0.1).delay(0.1)) { slotScale[throwIdx] = 1.0 }
        }

        lastKubbCount = currentKubbCount
        showThrowFeedback = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            showThrowFeedback = false
        }

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
        let throwRecords = round.throwRecords.sorted { $0.throwNumber < $1.throwNumber }

        completedSession = session
        completedRound = round

        manager.completeRound()
        HapticFeedbackService.shared.success()
        SoundService.shared.play(.roundComplete)

        if isLastRound {
            navigateToCompletion = true
        } else {
            inlineRoundScore = roundScore
            inlineRoundNumber = roundNum
            inlineKubbsCleared = cleared
            inlineTargetKubbs = target
            inlineRoundThrows = throwRecords
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showInlineRoundResult = true
            }
        }
    }

    private func startNextRoundInline() {
        sessionManager?.startNextRound()
        withAnimation(.easeOut(duration: 0.25)) {
            showInlineRoundResult = false
        }
    }

    private func handleEndSessionEarly(discard: Bool) {
        guard let manager = sessionManager else { return }

        if discard {
            manager.cancelSession()
            HapticFeedbackService.shared.buttonTap()
            if navigationPath.count > 0 { navigationPath.removeLast(navigationPath.count) }
            else { dismiss() }
        } else {
            if let round = manager.currentRound, !round.throwRecords.isEmpty {
                manager.completeRound()
            }
            Task { @MainActor in
                await manager.completeSession()
                HapticFeedbackService.shared.buttonTap()
                if navigationPath.count > 0 { navigationPath.removeLast(navigationPath.count) }
                else { dismiss() }
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

    private var isRoundComplete: Bool {
        sessionManager?.currentRound?.isComplete ?? false
    }

    private var remainingKubbs: Int? {
        guard let target = targetKubbCount else { return nil }
        return max(0, target - totalKubbsKnockedDown)
    }

    /// Cumulative session score across all completed rounds (over/under par).
    private var currentRoundScore: Int? {
        guard let session = sessionManager?.currentSession else { return nil }
        let completed = session.rounds.filter { $0.completedAt != nil }
        guard !completed.isEmpty else { return nil }
        return completed.reduce(0) { $0 + $1.score }
    }

    private var sessionScoreValue: Int {
        currentRoundScore ?? 0
    }

    private var sessionScoreText: String {
        guard let score = currentRoundScore else { return "–" }
        return score > 0 ? "+\(score)" : "\(score)"
    }

    private func golfTerm(for score: Int) -> String {
        switch score {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        default: return "Triple+"
        }
    }

    private func cleanupOrphanedSessions(phase: TrainingPhase) {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        do {
            let incompleteSessions = try modelContext.fetch(descriptor)
            let orphanedSessions = incompleteSessions.filter { $0.phase == phase }
            for session in orphanedSessions { modelContext.delete(session) }
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
