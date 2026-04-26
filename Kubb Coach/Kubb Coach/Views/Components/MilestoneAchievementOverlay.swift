//
//  MilestoneAchievementOverlay.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct MilestoneAchievementOverlay: View {
    let milestone: MilestoneDefinition
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var iconRotation: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Achievement card
            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(milestone.color.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: milestone.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(milestone.color)
                        .rotationEffect(.degrees(iconRotation))
                }

                VStack(spacing: 8) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(milestone.color)

                    Text(milestone.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(milestone.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Awesome!")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(milestone.color)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            // Rotate icon
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6)) {
                iconRotation = 360
            }

            // Haptic + sound
            HapticFeedbackService.shared.success()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0.8
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

#Preview {
    MilestoneAchievementOverlay(
        milestone: MilestoneDefinition(
            id: "session_10",
            title: "Dedicated",
            description: "Complete 10 training sessions",
            icon: "flame.fill",
            category: .sessionCount,
            threshold: 10,
            color: Color.Kubb.swedishGold
        ),
        onDismiss: {}
    )
}
