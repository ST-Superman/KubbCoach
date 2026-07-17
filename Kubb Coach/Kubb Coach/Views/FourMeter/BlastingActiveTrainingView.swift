//
//  BlastingActiveTrainingView.swift
//  Kubb Coach
//
//  V2 "Scorecard" redesign per design_handoff_4m_blasting/README.md
//  Kubb count, par position, and knockdown buttons reflect the actual round
//  target (Round 1 = 2 kubbs, …, Round 9 = 10 kubbs; par per table in model).
//  Round completion shows an inline result panel + "Next Round" button.
//

import SwiftUI
import SwiftData
import OSLog

// MARK: - File-local primitives

private enum BatonState: Equatable { case used, available, current }

private struct BatonIconView: View {
    let state: BatonState
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var orange: Color { Color(hex: "E08E27") }

    var body: some View {
        let w = max(size * 0.24, 5)
        Canvas { ctx, sz in
            let r = w / 2
            let xOff = (sz.width - w) / 2
            let rect = CGRect(x: xOff, y: 0, width: w, height: sz.height)
            let path = Path(roundedRect: rect, cornerRadius: r)
            if state == .used {
                let fill   = colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.14)
                let stroke = colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.18)
                ctx.fill(path, with: .color(fill))
                ctx.stroke(path, with: .color(stroke), lineWidth: 1)
            } else {
                ctx.fill(path, with: .color(orange))
                // Cap band near bottom
                let cap = Path(roundedRect: CGRect(x: xOff, y: sz.height * 0.68,
                                                   width: w, height: sz.height * 0.22),
                               cornerRadius: r)
                ctx.fill(cap, with: .color(Color.black.opacity(0.18)))
                // Highlight streak
                let hlW = w * 0.32
                let hl  = Path(roundedRect: CGRect(x: xOff + 2, y: 2,
                                                   width: hlW, height: sz.height - 5),
                               cornerRadius: hlW / 2)
                ctx.fill(hl, with: .color(Color.white.opacity(0.22)))
            }
        }
        .frame(width: w + 4, height: size)
        .scaleEffect(state == .current ? 1.33 : 1.0)
        .shadow(color: state == .current ? orange.opacity(0.7) : .clear, radius: 5)
        .shadow(color: state == .current ? orange.opacity(0.4) : .clear, radius: 12)
        .animation(.easeInOut(duration: 0.2), value: state)
    }
}

private struct KubbPieceView: View {
    let isDown: Bool
    let height: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var woodColor: Color {
        colorScheme == .dark ? Color(hex: "E4D3AC") : Color(hex: "8C6A3F")
    }

    var body: some View {
        if isDown {
            RoundedRectangle(cornerRadius: 1)
                .fill(woodColor.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 1).strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                .frame(width: height, height: height * 0.5)
        } else {
            let w = height * 0.46
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(woodColor)
                    .overlay(RoundedRectangle(cornerRadius: 1).strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                // Top highlight strip
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.16))
                    .frame(height: height * 0.15)
            }
            .frame(width: w, height: height)
        }
    }
}

private struct DownwardTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Main view

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
    @State private var navigateToCompletion = false
    @State private var completedSession: TrainingSession?
    @State private var completedRound: TrainingRound?
    @State private var showThrowFeedback = false
    @State private var lastKubbCount: Int = 0
    @State private var showRoundComplete = false
    @State private var showPauseOverlay = false

    var body: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                scorecardStrip
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                kubbPitchCard
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                Spacer(minLength: 0)

                // Lower panel: batons + knockdown input, OR round result
                Group {
                    if showRoundComplete {
                        roundCompletePanel
                    } else {
                        VStack(spacing: 14) {
                            batonsCard
                            knockdownInputSection
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showRoundComplete)

                bottomDock
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 100)
            }

            if showThrowFeedback {
                NumberFeedbackView(count: lastKubbCount)
                    .allowsHitTesting(false)
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
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.Kubb.activeTextFaint)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Round \(currentRoundNumber)")
                        .font(.system(size: 27, weight: .bold))
                        .tracking(-0.6)
                        .foregroundStyle(Color.Kubb.activeText)
                    Text("/ \(configuredRounds)")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.Kubb.activeTextDim)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SESSION")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.Kubb.activeTextFaint)
                    .textCase(.uppercase)

                Text(sessionScoreText)
                    .font(.system(size: 27, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(sessionScoreColor)
                    .monospacedDigit()
                    .animation(.easeInOut(duration: 0.2), value: sessionScoreText)
            }
        }
    }

    // MARK: - Scorecard Strip

    private var scorecardStrip: some View {
        let completedRoundNumber = completedRound?.roundNumber ?? 0
        let rounds = sessionManager?.currentSession?.rounds
            .sorted { $0.roundNumber < $1.roundNumber } ?? []

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(0..<configuredRounds, id: \.self) { i in
                    let roundNum = i + 1
                    // During round-complete panel, no cell is highlighted; the just-completed
                    // round shows its final score like any other completed round.
                    let isCurrent  = !showRoundComplete && roundNum == currentRoundNumber
                    let isCompleted = showRoundComplete
                        ? roundNum <= completedRoundNumber
                        : roundNum < currentRoundNumber
                    let delta: Int? = isCompleted && i < rounds.count ? rounds[i].score : nil

                    VStack(spacing: 2) {
                        Text("\(roundNum)")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .tracking(0.4)
                            .foregroundStyle(Color.Kubb.activeTextFaint)

                        Text(scorecardLabel(isCurrent: isCurrent, delta: delta))
                            .font(.system(size: 13, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(scorecardColor(isCurrent: isCurrent, delta: delta))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minWidth: 30)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(scorecardBg(isCurrent: isCurrent, isCompleted: isCompleted))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(scorecardBorder(isCurrent: isCurrent, isCompleted: isCompleted), lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 0.2), value: showRoundComplete)
                    .animation(.easeInOut(duration: 0.2), value: currentRoundNumber)
                }
            }
        }
    }

    // MARK: - Kubb Pitch Card
    // Shows actual targetKubbCount for the round (Round 1 = 2, Round 9 = 10).

    private var kubbPitchCard: some View {
        let total    = currentTargetKubbCount
        let standing = currentStanding
        let down     = total - standing

        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.Kubb.phase4m.opacity(0.14), location: 0),
                            .init(color: Color.Kubb.phase4m.opacity(0.03), location: 0.55),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.Kubb.activeBorder, lineWidth: 1)

            VStack(spacing: 0) {
                // GeometryReader sizes kubbs so the all-fallen state always fits:
                // n * h + (n-1) * gap ≤ available width (fallen kubbs are `h` wide)
                GeometryReader { geo in
                    let gap: CGFloat = 10
                    let h = min(58, max(18, floor((geo.size.width - CGFloat(max(total - 1, 0)) * gap) / CGFloat(max(total, 1)))))

                    ZStack(alignment: .bottom) {
                        // Dashed ground line spans full width
                        Canvas { ctx, size in
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: size.height - 5))
                            path.addLine(to: CGPoint(x: size.width, y: size.height - 5))
                            ctx.stroke(path, with: .color(Color.Kubb.phase4m.opacity(0.35)),
                                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }

                        // Kubbs bottom-aligned, sized to fit
                        HStack(alignment: .bottom, spacing: gap) {
                            ForEach(0..<total, id: \.self) { i in
                                KubbPieceView(isDown: i < down, height: h)
                            }
                        }
                        .padding(.bottom, 8)
                        .animation(.easeInOut(duration: 0.3), value: down)
                    }
                }
                .frame(height: 80)

                Text("\(standing) standing · \(down) down")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.Kubb.activeTextDim)
                    .textCase(.uppercase)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
        }
    }

    // MARK: - Batons Card
    // PAR marker column = par - 1 (0-based), derived from model: e.g. Round 1 target=2 → par=2 → index 1.

    private var batonsCard: some View {
        let used     = currentThrowsUsed
        let parIndex = currentRoundPar - 1   // 0-based column for PAR marker
        let cols     = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

        return VStack(spacing: 10) {
            HStack {
                Text("BATONS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.Kubb.activeTextDim)
                    .textCase(.uppercase)
                Spacer()
                HStack(spacing: 0) {
                    Text("\(used)")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Color.Kubb.activeText)
                    Text(" / 6")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.Kubb.activeTextFaint)
                }
            }

            LazyVGrid(columns: cols, spacing: 4) {
                // PAR marker row — only one column shows the marker
                ForEach(0..<6, id: \.self) { i in
                    Group {
                        if i == parIndex {
                            VStack(spacing: 2) {
                                Text("PAR")
                                    .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(Color(hex: "F5B85D"))
                                DownwardTriangle()
                                    .fill(Color(hex: "F5B85D"))
                                    .frame(width: 6, height: 4)
                            }
                        } else {
                            Color.clear.frame(height: 20)
                        }
                    }
                }

                // Baton icons
                ForEach(0..<6, id: \.self) { i in
                    let state: BatonState = i < used ? .used
                        : (i == used && used < 6 ? .current : .available)
                    HStack {
                        Spacer()
                        BatonIconView(state: state, size: 26)
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.Kubb.activeSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.Kubb.activeBorderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Knockdown Input
    // Buttons 0…standing, where standing = remainingKubbs for the current round.

    private var knockdownInputSection: some View {
        let standing = currentStanding

        return VStack(alignment: .leading, spacing: 8) {
            Text("KUBBS FELLED THIS THROW")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.Kubb.activeTextFaint)
                .textCase(.uppercase)

            // Row 1: 0–5 (always shown); row 2: 6–standing (only when standing > 5)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0...min(5, max(standing, 0)), id: \.self) { n in
                        kubbCountButton(n)
                    }
                }
                if standing > 5 {
                    HStack(spacing: 8) {
                        ForEach(6...standing, id: \.self) { n in
                            kubbCountButton(n)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func kubbCountButton(_ n: Int) -> some View {
        Button { handleKubbCountTap(n) } label: {
            Text("\(n)")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(n == 0 ? Color.Kubb.activeTextDim : Color.Kubb.activeText)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(n == 0
                              ? Color.Kubb.activeSurface2
                              : Color.Kubb.phase4m.opacity(0.08 + Double(n) * 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            n == 0 ? Color.Kubb.activeBorderSoft : Color.Kubb.phase4m.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Round Complete Panel

    @ViewBuilder
    private var roundCompletePanel: some View {
        if let round = completedRound {
            let score      = round.score
            let term       = golfTerm(score)
            let throwsSorted = round.throwRecords.sorted { $0.throwNumber < $1.throwNumber }

            VStack(spacing: 12) {
                // Score summary card
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ROUND \(round.roundNumber) COMPLETE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(Color.Kubb.activeTextFaint)
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(scoreText(score))
                                .font(.system(size: 44, weight: .heavy))
                                .tracking(-1)
                                .foregroundStyle(scoreTextColor(score))
                                .monospacedDigit()
                            Text(term)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(scoreTextColor(score).opacity(0.8))
                                .padding(.bottom, 4)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("THROWS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Color.Kubb.activeTextFaint)
                            .textCase(.uppercase)

                        HStack(spacing: 4) {
                            ForEach(throwsSorted) { record in
                                throwChip(for: record)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(Color.Kubb.activeSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(scoreTextColor(score).opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Next Round button
                Button { startNextRoundAction() } label: {
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
                    .background(Color.Kubb.phase4m)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.Kubb.phase4m.opacity(0.35), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func throwChip(for record: ThrowRecord) -> some View {
        let kubbs = record.kubbsKnockedDown ?? 0
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(kubbs > 0 ? Color.Kubb.hitBright.opacity(0.18) : Color.Kubb.activeSurface2)
                .frame(width: 26, height: 26)
            Text("\(kubbs)")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(kubbs > 0 ? Color.Kubb.hitBright : Color.Kubb.activeTextFaint)
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
            .disabled(currentThrowsUsed == 0 || showRoundComplete)
            .opacity(currentThrowsUsed == 0 || showRoundComplete ? 0.4 : 1.0)

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
        .background(Color.Kubb.activeSurface2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.Kubb.activeBorderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                        .fill(Color.Kubb.activeSurface)
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

                Text("Round \(currentRoundNumber) · throw \(min(currentThrowsUsed + 1, 6)) of 6")
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
            if resumeSession == nil {
                cleanupOrphanedSessions(phase: .fourMetersBlasting)
                DataDeletionService.cleanupOrphanedData(modelContext: modelContext, phase: .fourMetersBlasting)
            }
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

    private func handleKubbCountTap(_ count: Int) {
        guard let manager = sessionManager else { return }
        manager.recordBlastingThrow(kubbsKnockedDown: count)

        lastKubbCount = count
        showThrowFeedback = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            showThrowFeedback = false
        }

        if count > 0 {
            HapticFeedbackService.shared.hit()
            SoundService.shared.play(.hit)
        } else {
            HapticFeedbackService.shared.miss()
            SoundService.shared.play(.miss)
        }
    }

    private func handleCompleteRound() {
        guard let manager = sessionManager,
              let round = manager.currentRound,
              let session = manager.currentSession else { return }

        let isLastRound = round.roundNumber >= configuredRounds

        completedSession = session
        completedRound   = round

        manager.completeRound()
        HapticFeedbackService.shared.success()
        SoundService.shared.play(.roundComplete)

        if isLastRound {
            navigateToCompletion = true
        } else {
            // Show round result panel; startNextRound() called when user taps "Next Round"
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showRoundComplete = true
            }
        }
    }

    private func startNextRoundAction() {
        sessionManager?.startNextRound()
        withAnimation(.easeOut(duration: 0.25)) {
            showRoundComplete = false
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

    /// Round number for display. After completeRound() currentRound still points to the
    /// just-finished round (completedAt is set but the reference is unchanged), so this
    /// returns the correct number during the round-complete panel too.
    private var currentRoundNumber: Int {
        sessionManager?.currentRound?.roundNumber ?? 1
    }

    private var currentThrowsUsed: Int {
        sessionManager?.currentRound?.throwRecords.count ?? 0
    }

    /// Actual kubb target for the current round (Round 1=2, …, Round 9=10).
    private var currentTargetKubbCount: Int {
        sessionManager?.currentRound?.targetKubbCount ?? 2
    }

    /// Kubbs still standing in the current round (uses model's remainingKubbs).
    private var currentStanding: Int {
        sessionManager?.currentRound?.remainingKubbs ?? currentTargetKubbCount
    }

    /// Par throws for the current round (varies by target count per model).
    private var currentRoundPar: Int {
        sessionManager?.currentRound?.par ?? 2
    }

    private var isBlastingRoundComplete: Bool {
        sessionManager?.isBlastingRoundComplete ?? false
    }

    private var sessionScoreText: String {
        let completed = sessionManager?.currentSession?.rounds.filter { $0.completedAt != nil } ?? []
        guard !completed.isEmpty else { return "–" }
        return scoreText(completed.reduce(0) { $0 + $1.score })
    }

    private var sessionScoreValue: Int {
        let completed = sessionManager?.currentSession?.rounds.filter { $0.completedAt != nil } ?? []
        return completed.reduce(0) { $0 + $1.score }
    }

    private var sessionScoreColor: Color {
        let completed = sessionManager?.currentSession?.rounds.filter { $0.completedAt != nil } ?? []
        guard !completed.isEmpty else { return Color.Kubb.activeTextFaint }
        return scoreTextColor(sessionScoreValue)
    }

    // MARK: - Helpers

    private func scoreText(_ delta: Int) -> String {
        if delta == 0 { return "E" }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }

    private func scoreTextColor(_ score: Int) -> Color {
        if score < 0 { return Color.Kubb.hitBright }
        if score == 0 { return Color.Kubb.activeTextDim }
        return Color.Kubb.missBright
    }

    private func golfTerm(_ score: Int) -> String {
        switch score {
        case ...(-3): return "Albatross"
        case -2:  return "Eagle"
        case -1:  return "Birdie"
        case 0:   return "Par"
        case 1:   return "Bogey"
        case 2:   return "Double Bogey"
        default:  return "Triple+"
        }
    }

    private func scorecardLabel(isCurrent: Bool, delta: Int?) -> String {
        if isCurrent { return "···" }
        guard let d = delta else { return "–" }
        return scoreText(d)
    }

    private func scorecardColor(isCurrent: Bool, delta: Int?) -> Color {
        if isCurrent { return Color.Kubb.phase4m }
        guard let d = delta else { return Color.Kubb.activeTextFaint }
        return scoreTextColor(d)
    }

    private func scorecardBg(isCurrent: Bool, isCompleted: Bool) -> Color {
        if isCurrent    { return Color.Kubb.phase4m.opacity(0.16) }
        if isCompleted  { return Color.Kubb.activeSurface2 }
        return .clear
    }

    private func scorecardBorder(isCurrent: Bool, isCompleted: Bool) -> Color {
        if isCurrent    { return Color.Kubb.phase4m.opacity(0.4) }
        if isCompleted  { return Color.Kubb.activeBorderSoft }
        return Color.Kubb.activeBorder.opacity(0.3)
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
