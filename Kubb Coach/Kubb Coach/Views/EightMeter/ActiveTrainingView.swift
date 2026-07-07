//
//  ActiveTrainingView.swift
//  Kubb Coach
//

import SwiftUI
import SwiftData
import OSLog

struct ActiveTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    let phase: TrainingPhase
    let sessionType: SessionType
    let configuredRounds: Int
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    var isGuidedMode: Bool = false
    var isTutorialSession: Bool = false
    var onRoundComplete: (() -> Void)? = nil
    var onSessionComplete: (() -> Void)? = nil
    var resumeSession: TrainingSession? = nil

    @State private var sessionManager: TrainingSessionManager?
    @State private var navigateToCompletion = false
    @State private var completedSession: TrainingSession?

    // Overlays
    @State private var showThrowFeedback = false
    @State private var lastThrowResult: ThrowResult?
    @State private var showPerfectRoundCelebration = false
    @State private var showInlineRoundResult = false
    @State private var isLastRoundResult = false
    @State private var inlineRoundAccuracy: Double = 0
    @State private var inlineRoundHits: Int = 0
    @State private var inlineRoundThrows: [ThrowRecord] = []
    @State private var inlineRoundNumber: Int = 0
    @State private var inlineWasPerfect = false
    @State private var showPauseOverlay = false
    @State private var showUndoSheet = false

    // Feedback animation
    @State private var hitRippleTrigger = false
    @State private var missShakeTrigger = false
    @State private var streakMilestoneText: String? = nil
    @State private var hitStreakPersonalBest: Int = 0

    // Slot scale animation (index 0–5)
    @State private var slotScale: [CGFloat] = Array(repeating: 1.0, count: 6)

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

                actionZone
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                Spacer(minLength: 0)

                bottomDock
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
            }

            // Throw feedback (momentary)
            if showThrowFeedback, let result = lastThrowResult {
                ThrowFeedbackView(result: result)
                    .allowsHitTesting(false)
            }

            // Streak milestone banner
            if let milestone = streakMilestoneText {
                VStack {
                    Spacer()
                    Text(milestone)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.Kubb.streakFlame)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.Kubb.activeSurface)
                        .clipShape(Capsule())
                        .shadow(color: Color.Kubb.streakFlame.opacity(0.3), radius: 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 120)
                }
            }

            // Round result overlay (state 3 perfect / state 4 round result)
            if showInlineRoundResult {
                roundResultOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }

            // Perfect round overlay (state 3) — shows briefly before round result
            if showPerfectRoundCelebration {
                perfectRoundOverlay
                    .transition(.opacity)
                    .zIndex(11)
            }

            // Pause overlay (state 6)
            if showPauseOverlay {
                pauseOverlay
                    .transition(.opacity)
                    .zIndex(12)
            }

            // Undo sheet (state 7)
            if showUndoSheet {
                undoSheetOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(13)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { handleOnAppear() }
        .fullScreenCover(isPresented: $navigateToCompletion) {
            if let session = completedSession {
                SessionCompleteView(
                    session: session,
                    sessionManager: sessionManager ?? TrainingSessionManager(modelContext: modelContext),
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
                Text(eyebrowText)
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

                Text(String(format: "%.0f%%", sessionAccuracy))
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Color.Kubb.activeAccuracyColor(for: sessionAccuracy))
            }
        }
    }

    private var eyebrowText: String {
        let dist = phase == .eightMeters ? "8 METERS" : "4 METERS"
        let type = sessionType == .standard ? "STANDARD" : sessionType.displayName.uppercased()
        return "\(dist) · \(type)"
    }

    // MARK: - Round Progress Bar

    private var roundProgressBar: some View {
        HStack(spacing: 4) {
            ForEach(1...configuredRounds, id: \.self) { n in
                RoundedRectangle(cornerRadius: 2)
                    .fill(roundSegmentColor(for: n))
                    .frame(height: n == currentRoundNumber ? 5 : 3)
                    .shadow(
                        color: n == currentRoundNumber ? Color.Kubb.swedishBlue.opacity(0.6) : .clear,
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
                return Color.Kubb.roundBarColor(for: rounds[n - 1].accuracy)
            }
            return Color.Kubb.hitBright
        } else if n == currentRoundNumber {
            return Color.Kubb.swedishBlue
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
                    Text("/ \(maxThrowsForRound)")
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
        let isKing = slot == 6

        Group {
            if isPast {
                let record = sortedThrows.count >= slot ? sortedThrows[slot - 1] : nil
                let isHit = record?.result == .hit
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHit ? Color.Kubb.darkForest : Color.Kubb.miss)
                    .frame(height: 56)
                    .overlay(
                        Image(systemName: isHit ? "checkmark" : "xmark")
                            .font(.system(size: isHit ? 20 : 17, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(
                        color: (isHit ? Color.Kubb.darkForest : Color.Kubb.miss).opacity(0.33),
                        radius: 8, y: 4
                    )
            } else if isCurrent {
                let isKingSlot = isKingThrow && isKing
                RoundedRectangle(cornerRadius: 12)
                    .fill(isKingSlot ? Color.Kubb.swedishGold : Color.Kubb.swedishBlue)
                    .frame(height: 56)
                    .overlay(
                        Group {
                            if isKingSlot {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.Kubb.midnightNavy)
                            } else {
                                Text("\(slot)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isKingSlot ? Color.Kubb.swedishGold : Color.Kubb.swedishBlue,
                                lineWidth: 2
                            )
                    )
            } else {
                // Future slot — only show king crown when hitting all remaining kubbs is still possible
                let remainingKubbs = sessionManager?.kubbsRemaining ?? 5
                let throwsBeforeSix = 6 - currentThrowNumber
                let canPossiblyKing = isKing && remainingKubbs <= throwsBeforeSix
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.Kubb.activeSurfaceTinted)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    canPossiblyKing
                                        ? Color.Kubb.swedishGold.opacity(0.33)
                                        : Color.Kubb.activeBorderSoft,
                                    style: canPossiblyKing
                                        ? StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                                        : StrokeStyle(lineWidth: 1)
                                )
                        )

                    if canPossiblyKing {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.Kubb.swedishGold.opacity(0.5))
                    } else {
                        Text("\(slot)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.Kubb.activeTextFaint)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Zone

    @ViewBuilder
    private var actionZone: some View {
        if isRoundComplete {
            // Should auto-complete — show nothing (handled by auto-complete logic)
            EmptyView()
        } else {
            VStack(spacing: 12) {
                // HIT button (fills remaining space)
                Button { handleHitTap() } label: {
                    hitButtonLabel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 180)
                .background(hitButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: hitShadowColor.opacity(0.4), radius: 20, y: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(isKingThrow ? 0.4 : 0.18), lineWidth: 1)
                        .blendMode(.overlay)
                )
                .rippleEffect(trigger: hitRippleTrigger, color: isKingThrow ? Color.Kubb.swedishGold : Color.Kubb.darkForest)
                .animation(.easeInOut(duration: 0.25), value: isKingThrow)

                // MISS button (fixed height)
                Button {
                    recordThrow(result: .miss, targetType: .baselineKubb)
                    HapticFeedbackService.shared.miss()
                    SoundService.shared.play(.miss)
                    missShakeTrigger.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                        Text("MISS")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(Color.Kubb.missBright)
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                }
                .background(
                    colorScheme == .dark
                        ? Color.Kubb.miss.opacity(0.14)
                        : Color.Kubb.missBright.opacity(0.08)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.Kubb.miss.opacity(0.33), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .screenShake(trigger: missShakeTrigger)
            }
        }
    }

    @ViewBuilder
    private var hitButtonLabel: some View {
        if isKingThrow {
            VStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.Kubb.midnightNavy)
                Text("KING")
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Color.Kubb.midnightNavy)
                Text("LAST BATON · ALL KUBBS DOWN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.Kubb.midnightNavy.opacity(0.7))
            }
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text("HIT")
                    .font(.system(size: 32, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 24)
        }
    }

    private var hitButtonBackground: some ShapeStyle {
        if isKingThrow {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "FFD93D"), Color.Kubb.swedishGold],
                startPoint: .top, endPoint: .bottom
            ))
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [Color.Kubb.hitBright, Color.Kubb.darkForest],
                startPoint: .top, endPoint: .bottom
            ))
        }
    }

    private var hitShadowColor: Color {
        isKingThrow ? Color.Kubb.swedishGold : Color.Kubb.darkForest
    }

    // MARK: - Bottom Dock

    private var bottomDock: some View {
        HStack {
            // Undo
            Button {
                if currentThrowNumber > 1 || hasThrowsInSession {
                    showUndoSheet = true
                    HapticFeedbackService.shared.buttonTap()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14))
                    Text("Undo")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.Kubb.activeTextDim)
            }
            .disabled(!hasThrowsInSession)

            Spacer()

            // Streak chip
            if currentStreak > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                    Text("×\(currentStreak)")
                        .font(.system(size: 14, weight: .heavy))
                }
                .foregroundStyle(Color.Kubb.streakFlame)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.Kubb.streakFlame.opacity(0.12))
                .overlay(
                    Capsule().strokeBorder(Color.Kubb.streakFlame.opacity(0.33), lineWidth: 1)
                )
                .clipShape(Capsule())
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentStreak)
            }

            Spacer()

            // End button
            if !isGuidedMode {
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

    // MARK: - Perfect Round Overlay (State 3)

    private var perfectRoundOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .blur(radius: 0)
                .background(.ultraThinMaterial.opacity(0.1))
                .onTapGesture { dismissPerfectRound() }

            VStack(spacing: 0) {
                // Gold circle with star
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.Kubb.swedishGold, Color(hex: "D9A800")],
                                center: .center, startRadius: 0, endRadius: 48
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.Kubb.swedishGold.opacity(0.5), radius: 20)

                    Image(systemName: "star.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.Kubb.midnightNavy)
                }

                Text("PERFECT ROUND!")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Color.Kubb.swedishGold)
                    .shadow(color: Color.Kubb.swedishGold.opacity(0.4), radius: 10)
                    .padding(.top, 18)

                Text("Round \(inlineRoundNumber) · 6/6 hits")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.Kubb.activeText)
                    .padding(.top, 8)

                Text("Including the king")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.Kubb.activeTextDim)
                    .padding(.top, 14)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 36)
            .background(
                colorScheme == .dark
                    ? Color.Kubb.activeSurface.opacity(0.92)
                    : Color.Kubb.activeSurface.opacity(0.96)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(Color.Kubb.swedishGold.opacity(0.33), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: Color.black.opacity(0.5), radius: 30, y: 12)
            .shadow(color: Color.Kubb.swedishGold.opacity(0.2), radius: 0, x: 0, y: 0)
            .padding(.horizontal, 40)
        }
    }

    private func dismissPerfectRound() {
        withAnimation(.easeOut(duration: 0.3)) {
            showPerfectRoundCelebration = false
        }
    }

    // MARK: - Round Result Overlay (State 4)

    private var roundResultOverlay: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
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
                    Text("ROUND ACCURACY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.Kubb.activeTextFaint)
                        .textCase(.uppercase)

                    Text(String(format: "%.0f%%", inlineRoundAccuracy))
                        .font(.system(size: 96, weight: .heavy, design: .rounded))
                        .tracking(-3)
                        .foregroundStyle(Color.Kubb.activeAccuracyColor(for: inlineRoundAccuracy))
                        .shadow(
                            color: colorScheme == .dark
                                ? Color.Kubb.activeAccuracyColor(for: inlineRoundAccuracy).opacity(0.3)
                                : .clear,
                            radius: 20
                        )

                    Text("\(inlineRoundHits)/\(inlineRoundThrows.count) hits")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.Kubb.activeTextDim)

                    // Throw dot row
                    HStack(spacing: 8) {
                        ForEach(inlineRoundThrows.sorted { $0.throwNumber < $1.throwNumber }) { record in
                            throwDot(for: record)
                        }
                    }
                    .padding(.top, 20)
                }

                Spacer()

                // Next / View Results button
                Button {
                    if isLastRoundResult {
                        advanceToSessionComplete()
                    } else {
                        startNextRoundInline()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(isLastRoundResult ? "VIEW RESULTS" : "NEXT ROUND")
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
    private func throwDot(for record: ThrowRecord) -> some View {
        let isHit = record.result == .hit
        let isKing = record.targetType == .king

        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isHit ? Color.Kubb.darkForest : Color.Kubb.miss)
                .frame(width: 18, height: 18)

            if isKing {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(isHit ? Color.Kubb.swedishGold : Color.Kubb.missBright)
            }
        }
    }

    // MARK: - Pause Overlay (State 6)

    private var pauseOverlay: some View {
        ZStack {
            (colorScheme == .dark
                ? Color.black.opacity(0.72)
                : Color.white.opacity(0.85))
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.3))

            VStack(spacing: 0) {
                // Pause icon circle
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

                Text("Round \(currentRoundNumber) · throw \(min(currentThrowNumber, 6)) of \(maxThrowsForRound)")
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

    // MARK: - Undo Sheet (State 7)

    private var undoSheetOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .blur(radius: 0)
                .background(.ultraThinMaterial.opacity(0.1))
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showUndoSheet = false
                    }
                }

            VStack(spacing: 0) {
                // Grabber
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.Kubb.activeBorderSoft)
                    .frame(width: 36, height: 4)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                // Header row
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.Kubb.activeSurfaceTinted)
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.Kubb.activeText)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Undo last throw?")
                            .font(.system(size: 16, weight: .heavy))
                            .tracking(-0.2)
                            .foregroundStyle(Color.Kubb.activeText)
                        Text(undoSubtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.Kubb.activeTextDim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 14)

                // Preview pill
                if let lastThrow = lastRecordedThrow {
                    let isHit = lastThrow.result == .hit
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHit ? Color.Kubb.darkForest : Color.Kubb.miss)
                                .frame(width: 32, height: 32)
                            Image(systemName: isHit ? "checkmark" : "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Throw \(lastThrow.throwNumber) — \(isHit ? "HIT" : "MISS")")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.Kubb.activeText)
                            Text("Will be removed from session totals")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.Kubb.activeTextDim)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        (isHit ? Color.Kubb.darkForest : Color.Kubb.miss).opacity(0.08)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                (isHit ? Color.Kubb.darkForest : Color.Kubb.miss).opacity(0.2),
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 8)
                }

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showUndoSheet = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.Kubb.activeText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.Kubb.activeBorder, lineWidth: 1)
                            )
                    }

                    Button {
                        performUndo()
                    } label: {
                        Text("Undo")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.Kubb.activeBg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.Kubb.activeText)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .background(Color.Kubb.activeSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.Kubb.activeBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Color.black.opacity(0.4), radius: 20, y: -8)
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .safeAreaPadding(.bottom)
        }
    }

    private var undoSubtitle: String {
        guard let last = lastRecordedThrow else { return "" }
        return "Round \(currentRoundNumber), throw \(last.throwNumber) · marked \(last.result == .hit ? "HIT" : "MISS")"
    }

    private var lastRecordedThrow: ThrowRecord? {
        (sessionManager?.currentRound?.throwRecords ?? [])
            .sorted { $0.throwNumber < $1.throwNumber }
            .last
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
            cleanupOrphanedSessions(phase: .eightMeters)
            DataDeletionService.cleanupOrphanedData(modelContext: modelContext, phase: .eightMeters)
            startSession()
        } else {
            navigateToCompletion = false
        }

        #if os(iOS)
        let pbService = PersonalBestService(modelContext: modelContext)
        if let best = pbService.getBest(for: .mostConsecutiveHits) {
            hitStreakPersonalBest = Int(best.value)
        }
        #endif
    }

    private func startSession() {
        let manager = TrainingSessionManager(modelContext: modelContext)
        if let existingSession = resumeSession {
            _ = manager.resumeSession(existingSession)
        } else {
            manager.startSession(phase: phase, sessionType: sessionType, rounds: configuredRounds, isTutorialSession: isTutorialSession)
        }
        sessionManager = manager
    }

    private func handleHitTap() {
        let targetType: TargetType = isKingThrow ? .king : .baselineKubb
        recordThrow(result: .hit, targetType: targetType)
        hitRippleTrigger.toggle()
        HapticFeedbackService.shared.hit()
        SoundService.shared.play(.hit)
    }

    private func recordThrow(result: ThrowResult, targetType: TargetType) {
        guard let manager = sessionManager else { return }

        manager.recordThrow(result: result, targetType: targetType)

        // Animate the slot that was just recorded
        let throwIdx = (manager.currentRound?.throwRecords.count ?? 1) - 1
        if throwIdx >= 0 && throwIdx < 6 {
            withAnimation(.easeOut(duration: 0.1)) { slotScale[throwIdx] = 1.05 }
            withAnimation(.easeOut(duration: 0.1).delay(0.1)) { slotScale[throwIdx] = 1.0 }
        }

        lastThrowResult = result
        showThrowFeedback = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            showThrowFeedback = false
        }

        // Streak milestone toast
        let newStreak = currentStreak
        if result == .hit && (newStreak == 5 || newStreak == 10 || newStreak == 15 || newStreak == 20) {
            SoundService.shared.play(.streakMilestone)
            withAnimation(.spring(response: 0.3)) { streakMilestoneText = "🔥 ×\(newStreak)!" }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { streakMilestoneText = nil }
            }
        }

        // Auto-complete round when all 6 throws are used
        let throwCount = manager.currentRound?.throwRecords.count ?? 0
        let shouldComplete = throwCount >= 6
        if shouldComplete {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                handleCompleteRound()
            }
        }
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager,
              let round = manager.currentRound,
              let session = manager.currentSession else { return }

        let isPerfect = round.accuracy == 100.0 && round.throwRecords.count == 6
        let isLastRound = round.roundNumber >= configuredRounds
        let roundAcc = round.accuracy
        let roundHits = round.hits
        let roundNum = round.roundNumber
        let roundThrows = round.throwRecords.sorted { $0.throwNumber < $1.throwNumber }

        completedSession = session
        manager.completeRound()
        HapticFeedbackService.shared.success()
        SoundService.shared.play(.roundComplete)

        if isPerfect {
            SoundService.shared.play(.perfectRound)
            inlineRoundNumber = roundNum

            withAnimation(.easeIn(duration: 0.25)) { showPerfectRoundCelebration = true }

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeOut(duration: 0.3)) { showPerfectRoundCelebration = false }
                try? await Task.sleep(for: .seconds(0.3))

                if isLastRound {
                    if isGuidedMode { onSessionComplete?() }
                    else { advanceToSessionComplete() }
                } else {
                    showRoundResult(accuracy: roundAcc, hits: roundHits, throws: roundThrows, roundNumber: roundNum, isLast: false)
                    if isGuidedMode && roundNum == 1 { onRoundComplete?() }
                }
            }
        } else if isLastRound {
            if isGuidedMode {
                onSessionComplete?()
            } else {
                showRoundResult(accuracy: roundAcc, hits: roundHits, throws: roundThrows, roundNumber: roundNum, isLast: true)
            }
        } else {
            showRoundResult(accuracy: roundAcc, hits: roundHits, throws: roundThrows, roundNumber: roundNum, isLast: false)
            if isGuidedMode && roundNum == 1 { onRoundComplete?() }
        }
    }

    private func showRoundResult(accuracy: Double, hits: Int, throws throwRecords: [ThrowRecord], roundNumber: Int, isLast: Bool) {
        inlineRoundAccuracy = accuracy
        inlineRoundHits = hits
        inlineRoundThrows = throwRecords
        inlineRoundNumber = roundNumber
        isLastRoundResult = isLast

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showInlineRoundResult = true
        }
    }

    private func startNextRoundInline() {
        sessionManager?.startNextRound()
        withAnimation(.easeOut(duration: 0.25)) {
            showInlineRoundResult = false
        }
    }

    private func advanceToSessionComplete() {
        withAnimation(.easeOut(duration: 0.25)) {
            showInlineRoundResult = false
        }

        Task { @MainActor in
            await sessionManager?.completeSession()
            completedSession = sessionManager?.currentSession ?? completedSession
            navigateToCompletion = true
        }
    }

    private func performUndo() {
        sessionManager?.undoLastThrow()
        HapticFeedbackService.shared.buttonTap()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showUndoSheet = false
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

    private var maxThrowsForRound: Int { 6 }

    private var isRoundComplete: Bool {
        sessionManager?.currentRound?.isComplete ?? false
    }

    private var isKingThrow: Bool {
        sessionManager?.canThrowAtKing ?? false
    }

    private var sessionAccuracy: Double {
        sessionManager?.sessionAccuracy ?? 0
    }

    private var hasThrowsInSession: Bool {
        (sessionManager?.currentRound?.throwRecords.isEmpty == false) ||
        (sessionManager?.currentSession?.rounds.filter { !$0.throwRecords.isEmpty }.isEmpty == false)
    }

    private var currentStreak: Int {
        guard let session = sessionManager?.currentSession else { return 0 }
        var streak = 0
        let sortedRounds = session.rounds.sorted { $0.roundNumber > $1.roundNumber }
        for round in sortedRounds {
            let sortedThrows = round.throwRecords.sorted { $0.throwNumber > $1.throwNumber }
            for throwRecord in sortedThrows {
                if throwRecord.result == .hit { streak += 1 }
                else { return streak }
            }
        }
        return streak
    }

    private func cleanupOrphanedSessions(phase: TrainingPhase) {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        do {
            let incompleteSessions = try modelContext.fetch(descriptor)
            let orphaned = incompleteSessions.filter { $0.phase == phase }
            for session in orphaned { modelContext.delete(session) }
            if !orphaned.isEmpty { try modelContext.save() }
        } catch {
            AppLogger.database.error("Failed to cleanup orphaned sessions: \(error)")
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
