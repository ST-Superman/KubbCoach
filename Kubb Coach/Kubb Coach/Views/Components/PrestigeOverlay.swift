//
//  PrestigeOverlay.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import OSLog

/// Celebration overlay for achieving prestige
struct PrestigeOverlay: View {
    let prestigeLevel: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotationDegrees: Double = -360

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }

            VStack(spacing: 28) {
                // Animated prestige badge
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    prestigeBadgeColor.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)

                    Image(systemName: prestigeBadgeIcon)
                        .font(.system(size: 60))
                        .foregroundStyle(prestigeBadgeGradient)
                        .frame(width: 120, height: 120)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.4))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(prestigeBorderGradient, lineWidth: 3)
                        )
                        .rotationEffect(.degrees(rotationDegrees))
                        .scaleEffect(scale)
                }
                .opacity(opacity)

                VStack(spacing: 12) {
                    Text("PRESTIGE ACHIEVED")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [prestigeBadgeColor, prestigeBadgeColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: prestigeBadgeColor.opacity(0.5), radius: 10)

                    VStack(spacing: 8) {
                        Text(prestigeTitle)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white)

                        Text(prestigeFullTitle)
                            .font(.title2)
                            .foregroundStyle(prestigeBadgeColor)

                        Text(prestigeExplanation)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(prestigeBadgeGradient)
                        .cornerRadius(12)
                        .shadow(color: prestigeBadgeColor.opacity(0.5), radius: 10)
                }
                .opacity(opacity)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(28)
            .shadow(color: prestigeBadgeColor.opacity(0.3), radius: 40)
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

    // MARK: - Computed Properties

    private var prestigeTitle: String {
        switch prestigeLevel {
        case 1: return "CM"
        case 2: return "FM"
        case 3: return "IM"
        case 4...: return "GM"
        default: return "Prestige"
        }
    }

    private var prestigeFullTitle: String {
        switch prestigeLevel {
        case 1: return "Candidate Master"
        case 2: return "FIDE Master"
        case 3: return "International Master"
        case 4:
            return "Grandmaster"
        case 5...:
            let stars = String(repeating: "⭐", count: prestigeLevel - 3)
            return "Grandmaster \(stars)"
        default:
            return "Prestige Achieved"
        }
    }

    private var prestigeExplanation: String {
        switch prestigeLevel {
        case 1:
            return "You've reached level 60 and earned the rank of Candidate Master!"
        case 2:
            return "A second prestige! You are now a FIDE Master!"
        case 3:
            return "Three prestiges! You've become an International Master!"
        case 4:
            return "Ultimate mastery achieved! You are now a Grandmaster!"
        default:
            return "Your legend continues to grow! Grandmaster level \(prestigeLevel)!"
        }
    }

    private var prestigeBadgeIcon: String {
        switch prestigeLevel {
        case 1: return "shield.fill"
        case 2: return "star.fill"
        case 3: return "crown.fill"
        default: return "sparkles"
        }
    }

    private var prestigeBadgeColor: Color {
        switch prestigeLevel {
        case 1: return KubbColors.swedishBlue
        case 2: return Color.purple
        case 3: return KubbColors.swedishGold
        default: return KubbColors.celebrationGoldStart
        }
    }

    private var prestigeBadgeGradient: LinearGradient {
        switch prestigeLevel {
        case 1:
            return LinearGradient(
                colors: [KubbColors.swedishBlue, KubbColors.duskBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            return LinearGradient(
                colors: [Color.purple, Color.purple.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            return LinearGradient(
                colors: [KubbColors.swedishGold, KubbColors.celebrationGoldEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    KubbColors.celebrationGoldStart,
                    Color.orange,
                    Color.pink,
                    Color.purple,
                    KubbColors.swedishBlue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var prestigeBorderGradient: LinearGradient {
        prestigeBadgeGradient
    }
}

#Preview("CM Prestige") {
    PrestigeOverlay(prestigeLevel: 1) {
        AppLogger.general.debug("Dismissed")
    }
}

#Preview("FM Prestige") {
    PrestigeOverlay(prestigeLevel: 2) {
        AppLogger.general.debug("Dismissed")
    }
}

#Preview("IM Prestige") {
    PrestigeOverlay(prestigeLevel: 3) {
        AppLogger.general.debug("Dismissed")
    }
}

#Preview("GM Prestige") {
    PrestigeOverlay(prestigeLevel: 4) {
        AppLogger.general.debug("Dismissed")
    }
}

#Preview("GM 5-Star") {
    PrestigeOverlay(prestigeLevel: 7) {
        AppLogger.general.debug("Dismissed")
    }
}
