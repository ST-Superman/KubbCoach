//
//  LevelUpCelebrationOverlay.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/28/26.
//

import SwiftUI
import OSLog

// MARK: - Level Up Overlay (Regular)

struct LevelUpCelebrationOverlay: View {
    let oldLevel: Int
    let newLevel: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }

            VStack(spacing: 24) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(KubbColors.swedishBlue)
                    .scaleEffect(scale)
                    .opacity(opacity)

                VStack(spacing: 8) {
                    Text("LEVEL UP!")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        Text("Level \(oldLevel)")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white.opacity(0.4))

                        Text("Level \(newLevel)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(KubbColors.swedishBlue)
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)

                Button {
                    dismissOverlay()
                } label: {
                    Text("CONTINUE")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(KubbColors.swedishBlue)
                        .cornerRadius(12)
                }
                .opacity(opacity)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(radius: 30)
        }
        .onAppear {
            SoundService.shared.play(.levelUp)
            HapticFeedbackService.shared.success()

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
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
}

// MARK: - Rank Up Overlay (Special)

struct RankUpCelebrationOverlay: View {
    let oldRank: String
    let newRank: String
    let newLevel: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotationDegrees: Double = -180

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }

            VStack(spacing: 28) {
                // Epic crown icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    KubbColors.celebrationGoldStart.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [KubbColors.celebrationGoldStart, KubbColors.celebrationGoldEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(rotationDegrees))
                        .scaleEffect(scale)
                }
                .opacity(opacity)

                VStack(spacing: 12) {
                    Text("RANK UP!")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [KubbColors.celebrationGoldStart, KubbColors.celebrationGoldEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: KubbColors.celebrationGoldStart.opacity(0.5), radius: 10)

                    VStack(spacing: 4) {
                        Text(oldRank)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                            .strikethrough()

                        Image(systemName: "arrow.down")
                            .foregroundStyle(KubbColors.celebrationGoldEnd)

                        VStack(spacing: 2) {
                            Text(newRank)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Level \(newLevel)")
                                .font(.title3)
                                .foregroundStyle(KubbColors.celebrationGoldEnd)
                        }
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)

                Button {
                    dismissOverlay()
                } label: {
                    Text("CONTINUE")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [KubbColors.celebrationGoldStart, KubbColors.celebrationGoldEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: KubbColors.celebrationGoldStart.opacity(0.5), radius: 10)
                }
                .opacity(opacity)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(28)
            .shadow(color: KubbColors.celebrationGoldStart.opacity(0.3), radius: 40)
        }
        .onAppear {
            SoundService.shared.play(.rankUp)
            HapticFeedbackService.shared.celebration()

            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
                rotationDegrees = 0
            }
        }
    }

    private func dismissOverlay() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

#Preview("Level Up") {
    LevelUpCelebrationOverlay(oldLevel: 1, newLevel: 2) {
        AppLogger.general.debug("Dismissed")
    }
}

#Preview("Rank Up") {
    RankUpCelebrationOverlay(oldRank: "Nybörjare", newRank: "Spelare", newLevel: 6) {
        AppLogger.general.debug("Dismissed")
    }
}
