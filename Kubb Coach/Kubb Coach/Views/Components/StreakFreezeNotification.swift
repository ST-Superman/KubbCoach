//
//  StreakFreezeNotification.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import OSLog

/// Notification displayed when a streak freeze is earned
struct StreakFreezeNotification: View {
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissNotification()
                }

            VStack(spacing: 20) {
                // Shield icon
                ZStack {
                    Circle()
                        .fill(KubbColors.swedishBlue.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [KubbColors.swedishBlue, KubbColors.duskBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(scale)
                .opacity(opacity)

                VStack(spacing: 10) {
                    Text("Streak Freeze Earned!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("You've earned a streak freeze after 7 consecutive days of training. It will automatically protect your streak if you miss a day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
                .scaleEffect(scale)
                .opacity(opacity)

                Button {
                    dismissNotification()
                } label: {
                    Text("Got it!")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(KubbColors.swedishBlue)
                        .cornerRadius(12)
                }
                .opacity(opacity)
            }
            .padding(30)
            .background(.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
        .onAppear {
            SoundService.shared.play(.streakMilestone)
            HapticFeedbackService.shared.success()

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    private func dismissNotification() {
        withAnimation(.easeOut(duration: 0.2)) {
            opacity = 0
            scale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

#Preview {
    StreakFreezeNotification {
        AppLogger.general.debug("Dismissed")
    }
}
