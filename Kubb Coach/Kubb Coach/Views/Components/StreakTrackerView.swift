//
//  StreakTrackerView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI

struct StreakTrackerView: View {
    let currentStreak: Int
    let personalBest: Int

    @State private var showNewRecord = false
    @State private var justBeatRecord = false

    private var isNewRecord: Bool {
        currentStreak > personalBest
    }

    private var progress: Double {
        guard personalBest > 0 else { return 0 }
        return min(Double(currentStreak) / Double(personalBest), 1.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Flame icon with animation
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: currentStreak >= 5 ? "flame.fill" : "flame")
                    .font(.title3)
                    .foregroundStyle(streakColor)
                    .scaleEffect(showNewRecord ? 1.3 : 1.0)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Hit Streak:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(currentStreak)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(streakColor)

                    if isNewRecord {
                        Text("NEW RECORD!")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.Kubb.swedishGold)
                    }
                }

                if personalBest > 0 && !isNewRecord {
                    // Progress bar toward personal best
                    VStack(alignment: .leading, spacing: 2) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.Kubb.sep)
                                    .frame(height: 6)

                                // Progress
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(streakColor)
                                    .frame(width: geometry.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text("\(personalBest - currentStreak) more to beat record (\(personalBest))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if isNewRecord {
                    Text("🔥 Keep it going!")
                        .font(.caption)
                        .foregroundStyle(streakColor)
                }
            }
        }
        .padding(12)
        .background(Color.Kubb.paper2)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .onChange(of: currentStreak) { oldValue, newValue in
            // Check if we just beat personal record
            if newValue > personalBest && oldValue <= personalBest && personalBest > 0 {
                justBeatRecord = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showNewRecord = true
                }

                // Haptic celebration
                HapticFeedbackService.shared.success()

                // Reset animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showNewRecord = false
                    }
                }
            }
        }
        .overlay {
            // New record celebration overlay
            if justBeatRecord && showNewRecord {
                VStack(spacing: 4) {
                    Text("🏆")
                        .font(.largeTitle)
                    Text("New Record!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.Kubb.swedishGold)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var streakColor: Color {
        if isNewRecord {
            return Color.Kubb.swedishGold
        } else if currentStreak >= 10 {
            return Color.Kubb.phase4m
        } else if currentStreak >= 5 {
            return Color.Kubb.swedishBlue
        } else {
            return Color.gray
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakTrackerView(currentStreak: 0, personalBest: 8)
        StreakTrackerView(currentStreak: 3, personalBest: 8)
        StreakTrackerView(currentStreak: 5, personalBest: 8)
        StreakTrackerView(currentStreak: 7, personalBest: 8)
        StreakTrackerView(currentStreak: 9, personalBest: 8)  // New record!
        StreakTrackerView(currentStreak: 12, personalBest: 8)  // Way past record
    }
    .padding()
}
