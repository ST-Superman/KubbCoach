//
//  WatchThreeForThreeGameView.swift
//  Kubb Coach Watch Watch App
//
//  3-4-3 active game on the Dial system. Crown drives the 0–13 frame score;
//  a tap on the dial logs the frame and triggers an ~850 ms confirmation
//  beat before auto-advancing. See "Watch Dial - Design Handoff.html".
//

import SwiftUI
import SwiftData
import WatchKit

struct WatchThreeForThreeGameView: View {
    @Binding var navigationPath: NavigationPath
    @Environment(\.modelContext) private var modelContext

    private enum Screen { case setup, play }
    private enum Phase { case enter, logged }

    @State private var screen: Screen = .setup
    @State private var phase: Phase = .enter
    @State private var currentFrame: Int = 1
    @State private var frameScores: [Int] = []
    @State private var crownValue: Double = 0
    @State private var navigateToSummary: PressureCookerSession?

    private let totalFrames = PressureCookerSession.totalFrames
    private let maxScore = PressureCookerSession.maxFrameScore

    private var pendingScore: Int {
        max(0, min(maxScore, Int(crownValue.rounded())))
    }

    private var arcAccent: Color {
        pendingScore == 13 ? .Kubb.swedishGold : .Kubb.hitBright
    }

    private var numberColor: Color {
        if pendingScore == 13 { return .Kubb.swedishGold }
        if pendingScore > 0   { return .Kubb.hitBright }
        return .white.opacity(0.38)
    }

    private var runningTotal: Int {
        frameScores.reduce(0, +)
    }

    var body: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()
            switch screen {
            case .setup: setupScreen
            case .play:  playScreen
            }
        }
        .navigationBarBackButtonHidden(screen == .play)
        .navigationDestination(item: $navigateToSummary) { session in
            WatchThreeForThreeSummaryView(session: session, navigationPath: $navigationPath)
        }
    }

    // MARK: - Setup

    private var setupScreen: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)
            ValueGauge(value: 0, max: 13, accent: .Kubb.hitBright) {
                VStack(spacing: 6) {
                    Text("3-4-3")
                        .font(.system(size: 34, weight: .heavy))
                        .kerning(-1)
                        .foregroundStyle(.white)
                    Text("0\u{2013}13 \u{00B7} 10 FRAMES")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }
            .scaleFitToWatch()
            Spacer(minLength: 4)
            Button(action: startGame) {
                Text("Start")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.Kubb.darkForest, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .navigationTitle("3-4-3")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Play

    private var playScreen: some View {
        VStack(spacing: 4) {
            DialHeader(
                leftLabel: "FRAME",
                leftValue: "\(currentFrame) / \(totalFrames)",
                rightLabel: "TOTAL",
                rightValue: "\(displayedTotal)",
                rightAccent: .Kubb.swedishGold
            )
            .padding(.top, 6)

            ZStack {
                CrownHint()
                ValueGauge(value: pendingScore, max: maxScore, accent: arcAccent) {
                    dialCenter
                }
                .scaleFitToWatch()
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { logFrame() }

            ProgressDots(
                total: totalFrames,
                done: frameScores.count,
                current: phase == .enter ? frameScores.count : -1,
                accent: .Kubb.hitBright,
                size: 6,
                gap: 5
            )
            .padding(.bottom, phase == .logged ? 4 : 8)

            if phase == .logged, currentFrame < totalFrames {
                Text("Frame \(currentFrame + 1) \u{2192}")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 4)
        .digitalCrownRotation(
            $crownValue,
            from: 0.0,
            through: Double(maxScore),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Frame \(currentFrame) of \(totalFrames)")
        .accessibilityValue("\(pendingScore) of \(maxScore)")
        .accessibilityAdjustableAction { dir in
            guard phase == .enter else { return }
            switch dir {
            case .increment: crownValue = Double(min(maxScore, pendingScore + 1))
            case .decrement: crownValue = Double(max(0, pendingScore - 1))
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private var dialCenter: some View {
        VStack(spacing: 6) {
            Text("\(pendingScore)")
                .font(.system(size: 78, weight: .heavy))
                .kerning(-2)
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .id("score-\(pendingScore)-\(phase == .logged ? 1 : 0)")
                .transition(.scale.combined(with: .opacity))

            if phase == .enter {
                Text("TAP TO LOG")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.38))
            } else {
                Text(pendingScore == 13 ? "PERFECT \u{2713}" : "LOGGED \u{2713}")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(numberColor)
            }
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pendingScore)
    }

    // MARK: - Total display (header)

    /// While entering, show the committed running total. While in the logged
    /// confirmation beat, the score has not been appended yet — preview the
    /// post-log total in the header.
    private var displayedTotal: Int {
        phase == .logged ? runningTotal + pendingScore : runningTotal
    }

    // MARK: - Actions

    private func startGame() {
        frameScores = []
        currentFrame = 1
        crownValue = 0
        phase = .enter
        screen = .play
    }

    private func logFrame() {
        guard phase == .enter else { return }
        phase = .logged
        WKInterfaceDevice.current().play(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            commitFrame()
        }
    }

    private func commitFrame() {
        frameScores.append(pendingScore)
        if frameScores.count >= totalFrames {
            finishGame()
        } else {
            currentFrame += 1
            crownValue = 0
            phase = .enter
        }
    }

    private func finishGame() {
        let session = PressureCookerSession()
        session.frameScores = frameScores
        session.completedAt = Date()
        session.xpEarned = Self.computeXP(score: session.totalScore)
        modelContext.insert(session)
        try? modelContext.save()
        SessionConditionsCapture.captureIfEnabled(for: session, in: modelContext)
        navigateToSummary = session
    }

    private static func computeXP(score: Int) -> Double {
        switch score {
        case ..<50:   return 5.0
        case 50...75: return 9.0
        default:      return 13.0
        }
    }
}

// MARK: - Summary

struct WatchThreeForThreeSummaryView: View {
    let session: PressureCookerSession
    @Binding var navigationPath: NavigationPath
    @Environment(CloudKitSyncService.self) private var cloudSyncService

    var body: some View {
        ZStack {
            Color.Kubb.activeBg.ignoresSafeArea()
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                ResultRing(values: session.frameScores, colorFor: ringColor) {
                    VStack(spacing: 2) {
                        Text("3-4-3")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.62))
                        Text("\(session.totalScore)")
                            .font(.system(size: 56, weight: .heavy))
                            .kerning(-2)
                            .monospacedDigit()
                            .foregroundStyle(Color.Kubb.swedishGold)
                        Text("/130")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
                .scaleFitToWatch()
                Spacer(minLength: 0)

                HStack(spacing: 28) {
                    StatChip(label: "Best",
                             value: "\(session.frameScores.max() ?? 0)",
                             accent: .Kubb.swedishGold)
                    StatChip(label: "XP",
                             value: "+\(Int(session.xpEarned.rounded()))",
                             accent: .Kubb.hitBright)
                }

                Button { navigationPath = NavigationPath() } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.Kubb.activeSurface2, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
        .navigationTitle("3-4-3")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            _ = try? await cloudSyncService.uploadPressureCookerSession(session)
        }
    }

    private func ringColor(for score: Int) -> Color {
        if score == 13 { return .Kubb.swedishGold }
        if score >= 10 { return .Kubb.hitBright }
        if score >=  7 { return .white.opacity(0.5) }
        return .white.opacity(0.26)
    }
}

#Preview {
    WatchThreeForThreeGameView(navigationPath: .constant(NavigationPath()))
        .modelContainer(for: PressureCookerSession.self, inMemory: true)
}
