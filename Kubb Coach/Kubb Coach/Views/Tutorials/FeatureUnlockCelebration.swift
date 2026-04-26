//
//  FeatureUnlockCelebration.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/11/26.
//

import SwiftUI
import OSLog

struct FeatureUnlockCelebration: View {
    let level: Int
    let onDismiss: () -> Void

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var confettiTrigger = 0

    private var unlockedFeatures: [(icon: String, name: String, description: String)] {
        switch level {
        case 2:
            return [
                ("flag.fill", "4 Meter Blasting", "Train your field kubb accuracy with par-based scoring"),
                ("applewatch", "Watch Sessions", "View your Apple Watch training sessions")
            ]
        case 3:
            return [
                ("scope", "Inkasting Training", "Practice your kubb throwing precision and consistency")
            ]
        case 4:
            return [
                ("target", "Training Goals", "Set and track personalized training objectives"),
                ("trophy.fill", "Competition Tracking", "Count down to your next competition")
            ]
        case 5:
            return [
                ("flame.fill", "Pressure Cooker", "Score-based mini-games targeting specific Kubb skills and high-pressure scenarios")
            ]
        default:
            return []
        }
    }

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissCelebration()
                }

            VStack {
                Spacer()

                // Celebration card
                VStack(spacing: 20) {
                    // Confetti animation
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.Kubb.swedishGold, Color.Kubb.swedishGold.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.Kubb.swedishGold.opacity(0.4), radius: 20)

                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)

                    // Title
                    VStack(spacing: 8) {
                        Text("Level \(level) Unlocked!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("New training features available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Unlocked features list
                    VStack(spacing: 16) {
                        ForEach(unlockedFeatures, id: \.name) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: feature.icon)
                                    .font(.title3)
                                    .foregroundStyle(Color.Kubb.swedishBlue)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(feature.name)
                                        .font(.headline)
                                        .fontWeight(.semibold)

                                    Text(feature.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal)

                    // Dismiss button
                    Button {
                        dismissCelebration()
                    } label: {
                        Text("Start Training!")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.Kubb.swedishBlue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 30)
                .scaleEffect(scale)
                .opacity(opacity)
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
            }

            // Trigger confetti effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                confettiTrigger += 1
                HapticFeedbackService.shared.success()
            }
        }
    }

    private func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.2)) {
            opacity = 0
            scale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
        HapticFeedbackService.shared.buttonTap()
    }
}

#Preview {
    FeatureUnlockCelebration(level: 2) {
        AppLogger.general.debug("Dismissed")
    }
}
