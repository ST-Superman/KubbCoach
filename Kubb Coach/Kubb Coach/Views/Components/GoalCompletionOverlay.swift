//
//  GoalCompletionOverlay.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import SwiftUI

struct GoalCompletionOverlay: View {
    let goal: TrainingGoal
    let xpAwarded: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var iconRotation: Double = -180

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }

            VStack(spacing: 28) {
                // Trophy/Target Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [phaseColor.opacity(0.3), phaseColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "target")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [phaseColor, phaseColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(iconRotation))
                }
                .scaleEffect(scale)
                .opacity(opacity)

                VStack(spacing: 12) {
                    Text("GOAL COMPLETED!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text(goalDescription)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    // XP Award
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(KubbColors.swedishGold)

                        Text("+\(xpAwarded) XP")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(KubbColors.swedishGold)
                    }
                    .padding(.top, 8)

                    // Bonus indicator if earned
                    if goal.bonusXP > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)

                            Text("Early Completion Bonus!")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.yellow)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)

                Button {
                    dismissOverlay()
                } label: {
                    Text("CONTINUE")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(phaseColor)
                        .cornerRadius(12)
                }
                .opacity(opacity)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: phaseColor.opacity(0.3), radius: 30)
        }
        .onAppear {
            SoundService.shared.play(.sessionComplete)
            HapticFeedbackService.shared.success()

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
                iconRotation = 0
            }
        }
    }

    private func dismissOverlay() {
        withAnimation(.easeOut(duration: 0.2)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }

    private var goalDescription: String {
        let phaseText = goal.phaseEnum?.displayName ?? "Any Phase"
        return "Completed \(goal.targetSessionCount) \(phaseText) Session\(goal.targetSessionCount == 1 ? "" : "s")"
    }

    private var phaseColor: Color {
        guard let phase = goal.phaseEnum else {
            return KubbColors.swedishBlue
        }

        switch phase {
        case .eightMeters:
            return KubbColors.phase8m
        case .fourMetersBlasting:
            return KubbColors.phase4m
        case .inkastingDrilling:
            return KubbColors.phaseInkasting
        case .gameTracker:
            return KubbColors.swedishBlue
        case .pressureCooker:
            return KubbColors.phasePressureCooker
        }
    }
}
