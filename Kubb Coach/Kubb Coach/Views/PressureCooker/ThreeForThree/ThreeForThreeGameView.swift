//
//  ThreeForThreeGameView.swift
//  Kubb Coach
//
//  Active game recording view for 3-4-3.
//  Bowling-style scorecard at top; stepper input for each frame score.
//

import SwiftUI
import SwiftData

struct ThreeForThreeGameView: View {
    @Binding var navigateToGame: Bool

    @Environment(\.modelContext) private var modelContext

    // Current frame being entered (1-based)
    @State private var currentFrame: Int = 1
    // Score for the frame currently being entered
    @State private var pendingScore: Int = 0
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
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(Color(.secondarySystemBackground))

            ScrollView {
                VStack(spacing: 28) {
                    // Frame prompt
                    frameInputSection
                        .padding(.top, 24)

                    // Running total
                    runningTotalSection

                    // Confirm button
                    confirmButton
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle("Frame \(currentFrame) of \(totalFrames)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showAbandonAlert = true
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
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
                HStack(spacing: 6) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
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

    // MARK: - Frame Input

    private var frameInputSection: some View {
        VStack(spacing: 20) {
            Text("Frame \(currentFrame) Score")
                .font(.title3)
                .fontWeight(.semibold)

            // Large score display with stepper
            HStack(spacing: 32) {
                Button {
                    if pendingScore > 0 { pendingScore -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(pendingScore > 0 ? KubbColors.phasePressureCooker : Color(.tertiaryLabel))
                }
                .disabled(pendingScore == 0)

                Text("\(pendingScore)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(pendingScore))
                    .frame(minWidth: 100)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: pendingScore)

                Button {
                    if pendingScore < maxScore { pendingScore += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(pendingScore < maxScore ? KubbColors.phasePressureCooker : Color(.tertiaryLabel))
                }
                .disabled(pendingScore == maxScore)
            }

            // Score label
            Text(scoreLabel(pendingScore))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .animation(.easeInOut, value: pendingScore)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 13:      return KubbColors.swedishGold
        case 11, 12:  return KubbColors.phasePressureCooker
        case 10:      return KubbColors.forestGreen
        default:      return .primary
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 0:       return "No kubbs cleared"
        case 1...9:   return "\(score) kubb\(score == 1 ? "" : "s") cleared"
        case 10:      return "Full Field! All 10 kubbs cleared"
        case 11:      return "Full Field + 1 bonus baton"
        case 12:      return "Full Field + 2 bonus batons"
        case 13:      return "Boiling Point! Perfect frame"
        default:      return ""
        }
    }

    // MARK: - Running Total

    private var runningTotalSection: some View {
        let runningTotal = frameScores.reduce(0, +) + (currentFrame <= frameScores.count ? 0 : 0)
        return VStack(spacing: 4) {
            Text("Running Total")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("\(frameScores.reduce(0, +))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text("of \(totalFrames * maxScore) possible")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            recordFrame()
        } label: {
            Text(currentFrame < totalFrames ? "Record Frame \(currentFrame)" : "Finish Game")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(KubbColors.phasePressureCooker)
                .cornerRadius(14)
        }
    }

    // MARK: - Logic

    private func recordFrame() {
        frameScores.append(pendingScore)

        if frameScores.count >= totalFrames {
            finishGame()
        } else {
            currentFrame += 1
            pendingScore = 0
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
        VStack(spacing: 4) {
            Text("\(frameNumber)")
                .font(.caption2)
                .foregroundStyle(isCurrent ? .white : .secondary)

            Text(scoreText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(scoreTextColor)
                .frame(width: 36, height: 28)
        }
        .frame(width: 44, height: 58)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: isCurrent ? 2 : 1)
        )
    }

    private var scoreText: String {
        guard let s = score else { return isCurrent ? "—" : "" }
        return "\(s)"
    }

    private var scoreTextColor: Color {
        guard let s = score else { return .secondary }
        if s == 13 { return KubbColors.swedishGold }
        if s >= 10 { return KubbColors.forestGreen }
        return .primary
    }

    private var backgroundColor: Color {
        if isCurrent { return KubbColors.phasePressureCooker }
        if isCompleted { return Color(.systemBackground) }
        return Color(.tertiarySystemBackground)
    }

    private var borderColor: Color {
        if isCurrent { return KubbColors.phasePressureCooker }
        if isCompleted { return KubbColors.phasePressureCooker.opacity(0.3) }
        return Color(.separator).opacity(0.4)
    }
}

#Preview {
    NavigationStack {
        ThreeForThreeGameView(navigateToGame: .constant(true))
    }
    .modelContainer(for: PressureCookerSession.self, inMemory: true)
}
