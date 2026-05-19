//
//  ThreeForThreeGameView.swift
//  Kubb Coach
//
//  Active game recording view for 3-4-3.
//  Bowling-style scorecard at top; tap-to-select score grid for fast input.
//

import SwiftUI
import SwiftData

struct ThreeForThreeGameView: View {
    @Binding var navigateToGame: Bool

    @Environment(\.modelContext) private var modelContext

    // Current frame being entered (1-based)
    @State private var currentFrame: Int = 1
    // Recorded frame scores so far
    @State private var frameScores: [Int] = []
    // Navigate to summary when game is complete
    @State private var completedSession: PressureCookerSession?
    // Confirm abandon
    @State private var showAbandonAlert = false

    private let totalFrames = PressureCookerSession.totalFrames
    private let maxScore = PressureCookerSession.maxFrameScore

    var body: some View {
        VStack(spacing: 0) {
            // Scorecard
            scorecardView
                .padding(.top, KubbSpacing.s)
                .padding(.bottom, KubbSpacing.l)
                .background(Color.Kubb.activeSurface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.Kubb.activeBorderSoft)
                        .frame(height: 1)
                }

            ScrollView {
                VStack(spacing: KubbSpacing.xl2) {
                    // Score grid
                    scoreGridSection
                        .padding(.top, KubbSpacing.xl2)

                    // Running total
                    runningTotalSection
                        .padding(.bottom, KubbSpacing.giant)
                }
                .padding(.horizontal, KubbSpacing.xl2)
            }
        }
        .background(Color.Kubb.activeBg.ignoresSafeArea())
        .navigationTitle("Frame \(currentFrame) of \(totalFrames)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showAbandonAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.Kubb.textSec)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    undoLastFrame()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundStyle(frameScores.isEmpty ? Color.Kubb.textTer : Color.Kubb.phasePC)
                }
                .disabled(frameScores.isEmpty)
            }
        }
        .alert("Abandon Game?", isPresented: $showAbandonAlert) {
            Button("Abandon", role: .destructive) {
                navigateToGame = false
            }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("Your progress will be lost.")
        }
        .navigationDestination(item: $completedSession) { session in
            ThreeForThreeSessionSummaryView(
                session: session,
                navigateToGame: $navigateToGame
            )
        }
    }

    // MARK: - Scorecard

    private var scorecardView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KubbSpacing.xs2) {
                    ForEach(1...totalFrames, id: \.self) { frame in
                        FrameBox(
                            frameNumber: frame,
                            score: scoreFor(frame: frame),
                            isCurrent: frame == currentFrame,
                            isCompleted: frame < currentFrame
                        )
                        .id(frame)
                    }
                }
                .padding(.horizontal, KubbSpacing.l)
                .padding(.vertical, KubbSpacing.s2)
            }
            .onChange(of: currentFrame) { _, newFrame in
                withAnimation {
                    proxy.scrollTo(min(newFrame + 1, totalFrames), anchor: .center)
                }
            }
        }
    }

    private func scoreFor(frame: Int) -> Int? {
        guard frame <= frameScores.count else { return nil }
        return frameScores[frame - 1]
    }

    // MARK: - Score Grid

    private var scoreGridSection: some View {
        VStack(spacing: KubbSpacing.l) {
            Text("Frame \(currentFrame) Score")
                .font(KubbFont.fraunces(19, weight: .medium))
                .foregroundStyle(Color.Kubb.text)

            VStack(spacing: KubbSpacing.s) {
                // Row 1: 0–4
                HStack(spacing: KubbSpacing.s) {
                    ForEach(0...4, id: \.self) { score in
                        ScoreTile(score: score) { recordFrame(score: $0) }
                    }
                }
                // Row 2: 5–9
                HStack(spacing: KubbSpacing.s) {
                    ForEach(5...9, id: \.self) { score in
                        ScoreTile(score: score) { recordFrame(score: $0) }
                    }
                }
                // Row 3: 10–13 (special scores, wider tiles)
                HStack(spacing: KubbSpacing.s) {
                    ForEach(10...13, id: \.self) { score in
                        ScoreTile(score: score) { recordFrame(score: $0) }
                    }
                }
            }
        }
    }

    // MARK: - Running Total

    private var runningTotalSection: some View {
        VStack(spacing: KubbSpacing.xs) {
            Text("RUNNING TOTAL")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .textCase(.uppercase)
                .foregroundStyle(Color.Kubb.textSec)
            Text("\(frameScores.reduce(0, +))")
                .font(KubbFont.fraunces(28, weight: .medium, italic: true))
                .foregroundStyle(Color.Kubb.text)
                .monospacedDigit()
            Text("of \(totalFrames * maxScore) possible")
                .font(KubbFont.mono(10, weight: .medium))
                .foregroundStyle(Color.Kubb.textSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KubbSpacing.m2)
        .background(Color.Kubb.activeSurface)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.ml, style: .continuous)
                .strokeBorder(Color.Kubb.activeBorderSoft, lineWidth: 1)
        )
    }

    // MARK: - Logic

    private func undoLastFrame() {
        guard !frameScores.isEmpty else { return }
        frameScores.removeLast()
        currentFrame -= 1
    }

    private func recordFrame(score: Int) {
        frameScores.append(score)

        if frameScores.count >= totalFrames {
            finishGame()
        } else {
            currentFrame += 1
        }
    }

    private func finishGame() {
        let session = PressureCookerSession()
        session.frameScores = frameScores
        session.completedAt = Date()
        session.xpEarned = PlayerLevelService.computeXP(for: session)

        modelContext.insert(session)
        try? modelContext.save()

        completedSession = session
    }
}

// MARK: - Frame Box

private struct FrameBox: View {
    let frameNumber: Int
    let score: Int?
    let isCurrent: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: KubbSpacing.xs) {
            Text("\(frameNumber)")
                .font(KubbFont.mono(9, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(isCurrent ? .white : Color.Kubb.textSec)

            Text(scoreText)
                .font(KubbFont.fraunces(15, weight: .medium, italic: true))
                .foregroundStyle(scoreTextColor)
                .monospacedDigit()
                .frame(width: 36, height: 28)
        }
        .frame(width: 44, height: 58)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KubbRadius.s, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isCurrent ? 2 : 1)
        )
    }

    private var scoreText: String {
        guard let s = score else { return isCurrent ? "—" : "" }
        return "\(s)"
    }

    private var scoreTextColor: Color {
        guard let s = score else { return isCurrent ? .white : Color.Kubb.textSec }
        if s == 13 { return Color.Kubb.swedishGold }
        if s >= 10 { return Color.Kubb.forestGreen }
        if isCurrent { return .white }
        return Color.Kubb.text
    }

    private var backgroundColor: Color {
        if isCurrent { return Color.Kubb.phasePC }
        if isCompleted { return Color.Kubb.activeSurface }
        return Color.Kubb.activeSurfaceTinted
    }

    private var borderColor: Color {
        if isCurrent { return Color.Kubb.phasePC }
        if isCompleted { return Color.Kubb.phasePC.opacity(0.3) }
        return Color.Kubb.activeBorderSoft
    }
}

// MARK: - Score Tile

private struct ScoreTile: View {
    let score: Int
    let onSelect: (Int) -> Void

    var body: some View {
        Button {
            onSelect(score)
        } label: {
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(KubbFont.fraunces(20, weight: .medium, italic: true))
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                if let label = shortLabel {
                    Text(label)
                        .font(KubbFont.inter(9, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: score >= 10 ? 60 : 52)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KubbRadius.m, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        switch score {
        case 13:     return Color.Kubb.swedishGold
        case 11, 12: return Color.Kubb.phasePC
        case 10:     return Color.Kubb.forestGreen
        default:     return Color.Kubb.text
        }
    }

    private var backgroundColor: Color {
        switch score {
        case 13:     return Color.Kubb.swedishGold.opacity(0.12)
        case 11, 12: return Color.Kubb.phasePC.opacity(0.12)
        case 10:     return Color.Kubb.forestGreen.opacity(0.12)
        default:     return Color.Kubb.card
        }
    }

    private var borderColor: Color {
        switch score {
        case 13:     return Color.Kubb.swedishGold.opacity(0.4)
        case 11, 12: return Color.Kubb.phasePC.opacity(0.3)
        case 10:     return Color.Kubb.forestGreen.opacity(0.3)
        default:     return Color.Kubb.activeBorderSoft
        }
    }

    private var shortLabel: String? {
        switch score {
        case 0:  return "miss"
        case 10: return "full field"
        case 11: return "+1 bonus"
        case 12: return "+2 bonus"
        case 13: return "boiling pt"
        default: return nil
        }
    }
}

#Preview {
    NavigationStack {
        ThreeForThreeGameView(navigateToGame: .constant(true))
    }
    .modelContainer(for: PressureCookerSession.self, inMemory: true)
}
