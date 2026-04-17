//
//  WatchThreeForThreeGameView.swift
//  Kubb Coach Watch Watch App
//
//  Active game recording view for 3-4-3 on Apple Watch.
//  Shows frame number, running total, and a +/- score input with Digital Crown support.
//

import SwiftUI
import SwiftData

struct WatchThreeForThreeGameView: View {
    @Binding var navigationPath: NavigationPath
    @Environment(\.modelContext) private var modelContext

    @State private var currentFrame: Int = 1
    @State private var pendingScore: Int = 0
    @State private var frameScores: [Int] = []
    @State private var crownValue: Double = 0.0
    @State private var showAbandonAlert = false
    @State private var navigateToSummary: PressureCookerSession?

    private let totalFrames = PressureCookerSession.totalFrames
    private let maxScore = PressureCookerSession.maxFrameScore

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header: frame / total
                headerRow(geometry: geometry)

                // Large score display
                scoreDisplay(geometry: geometry)

                // +/- buttons
                stepperRow(geometry: geometry)

                // Confirm
                confirmButton(geometry: geometry)
            }
        }
        .navigationTitle("\(currentFrame)/\(totalFrames)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .digitalCrownRotation(
            detent: $crownValue,
            from: 0.0,
            through: Double(maxScore),
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            pendingScore = Int(newValue.rounded())
        }
        .alert("Abandon?", isPresented: $showAbandonAlert) {
            Button("Yes", role: .destructive) { navigationPath.removeLast() }
            Button("No", role: .cancel) {}
        }
        .navigationDestination(item: $navigateToSummary) { session in
            WatchThreeForThreeSummaryView(session: session, navigationPath: $navigationPath)
        }
    }

    // MARK: - Header

    private func headerRow(geometry: GeometryProxy) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Frame \(currentFrame) of \(totalFrames)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("Total: \(frameScores.reduce(0, +))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KubbColors.phasePressureCooker)
            }
        }
        .padding(.horizontal, geometry.size.width * 0.05)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Score Display

    private func scoreDisplay(geometry: GeometryProxy) -> some View {
        Text("\(pendingScore)")
            .font(.system(size: geometry.size.height * 0.28, weight: .bold, design: .rounded))
            .foregroundStyle(scoreColor)
            .frame(maxWidth: .infinity)
            .contentTransition(.numericText())
            .animation(.snappy, value: pendingScore)
            .padding(.vertical, 4)
    }

    private var scoreColor: Color {
        if pendingScore == 13 { return KubbColors.swedishGold }
        if pendingScore >= 10 { return KubbColors.forestGreen }
        return .primary
    }

    // MARK: - Stepper Row

    private func stepperRow(geometry: GeometryProxy) -> some View {
        HStack(spacing: geometry.size.width * 0.06) {
            Button {
                if pendingScore > 0 {
                    pendingScore -= 1
                    crownValue = Double(pendingScore)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: geometry.size.height * 0.12))
                    .foregroundStyle(pendingScore > 0 ? KubbColors.phasePressureCooker : .secondary)
            }
            .disabled(pendingScore == 0)
            .buttonStyle(.plain)

            Spacer()

            Button {
                if pendingScore < maxScore {
                    pendingScore += 1
                    crownValue = Double(pendingScore)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: geometry.size.height * 0.12))
                    .foregroundStyle(pendingScore < maxScore ? KubbColors.phasePressureCooker : .secondary)
            }
            .disabled(pendingScore == maxScore)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, geometry.size.width * 0.08)
    }

    // MARK: - Confirm Button

    private func confirmButton(geometry: GeometryProxy) -> some View {
        Button(action: recordFrame) {
            Text(currentFrame < totalFrames ? "Next" : "Finish")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, geometry.size.height * 0.045)
                .background(KubbColors.phasePressureCooker)
                .foregroundStyle(.white)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, geometry.size.width * 0.05)
        .padding(.bottom, 4)
    }

    // MARK: - XP (inlined — PlayerLevelService is iOS-only)

    private static func computeXP(score: Int) -> Double {
        switch score {
        case ..<50:   return 5.0
        case 50...75: return 9.0
        default:      return 13.0
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
            crownValue = 0.0
        }
    }

    private func finishGame() {
        let session = PressureCookerSession()
        session.frameScores = frameScores
        session.completedAt = Date()
        session.xpEarned = Self.computeXP(score: session.totalScore)
        modelContext.insert(session)
        try? modelContext.save()
        navigateToSummary = session
    }
}

// MARK: - Watch Summary View

struct WatchThreeForThreeSummaryView: View {
    let session: PressureCookerSession
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Score
                VStack(spacing: 2) {
                    Text("Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(session.totalScore)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(KubbColors.phasePressureCooker)
                    Text("/ 130")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Stats
                HStack {
                    statItem(label: "Best Frame", value: "\(session.frameScores.max() ?? 0)")
                    Spacer()
                    statItem(label: "XP Earned", value: "+\(Int(session.xpEarned))")
                }

                Divider()

                Button {
                    // Pop to root
                    navigationPath = NavigationPath()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(KubbColors.phasePressureCooker)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .navigationTitle("3-4-3 Done")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchThreeForThreeGameView(navigationPath: .constant(NavigationPath()))
        .modelContainer(for: PressureCookerSession.self, inMemory: true)
}
