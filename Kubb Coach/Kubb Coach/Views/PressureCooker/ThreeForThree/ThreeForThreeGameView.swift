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
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(Color(.secondarySystemBackground))

            ScrollView {
                VStack(spacing: 24) {
                    // Score grid
                    scoreGridSection
                        .padding(.top, 24)

                    // Running total
                    runningTotalSection
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    undoLastFrame()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundStyle(frameScores.isEmpty ? Color(.tertiaryLabel) : Color.Kubb.phasePC)
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

    // MARK: - Score Grid

    private var scoreGridSection: some View {
        VStack(spacing: 16) {
            Text("Frame \(currentFrame) Score")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                // Row 1: 0–4
                HStack(spacing: 8) {
                    ForEach(0...4, id: \.self) { score in
                        ScoreTile(score: score) { recordFrame(score: $0) }
                    }
                }
                // Row 2: 5–9
                HStack(spacing: 8) {
                    ForEach(5...9, id: \.self) { score in
                        ScoreTile(score: score) { recordFrame(score: $0) }
                    }
                }
                // Row 3: 10–13 (special scores, wider tiles)
                HStack(spacing: 8) {
                    ForEach(10...13, id: \.self) { score in
                        ScoreTile(score: score) { recordFrame(score: $0) }
                    }
                }
            }
        }
    }

    // MARK: - Running Total

    private var runningTotalSection: some View {
        VStack(spacing: 4) {
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
        if s == 13 { return Color.Kubb.swedishGold }
        if s >= 10 { return Color.Kubb.forestGreen }
        return .primary
    }

    private var backgroundColor: Color {
        if isCurrent { return Color.Kubb.phasePC }
        if isCompleted { return Color(.systemBackground) }
        return Color(.tertiarySystemBackground)
    }

    private var borderColor: Color {
        if isCurrent { return Color.Kubb.phasePC }
        if isCompleted { return Color.Kubb.phasePC.opacity(0.3) }
        return Color(.separator).opacity(0.4)
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
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
                if let label = shortLabel {
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: score >= 10 ? 60 : 52)
            .background(backgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
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
        default:     return .primary
        }
    }

    private var backgroundColor: Color {
        switch score {
        case 13:     return Color.Kubb.swedishGold.opacity(0.12)
        case 11, 12: return Color.Kubb.phasePC.opacity(0.12)
        case 10:     return Color.Kubb.forestGreen.opacity(0.12)
        default:     return Color(.secondarySystemBackground)
        }
    }

    private var borderColor: Color {
        switch score {
        case 13:     return Color.Kubb.swedishGold.opacity(0.4)
        case 11, 12: return Color.Kubb.phasePC.opacity(0.3)
        case 10:     return Color.Kubb.forestGreen.opacity(0.3)
        default:     return Color(.separator).opacity(0.3)
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
