//
//  SessionShareCardView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/28/26.
//

import SwiftUI

struct SessionShareCardView: View {
    let session: TrainingSession

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("KUBB COACH")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.7))

                Text(mainStat)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [KubbColors.celebrationGoldStart, KubbColors.celebrationGoldEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(session.safePhase.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                HStack(spacing: 16) {
                    Label("\(session.configuredRounds) rounds", systemImage: "repeat")
                    Label("\(session.totalThrows) throws", systemImage: "figure.throw")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

                if session.safePhase == .eightMeters {
                    HStack(spacing: 16) {
                        Label("\(session.totalHits) hits", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(KubbColors.forestGreen)

                        let maxStreak = computeMaxStreak()
                        if maxStreak > 0 {
                            Label("\(maxStreak) streak", systemImage: "flame.fill")
                                .foregroundStyle(KubbColors.streakFlame)
                        }
                    }
                    .font(.subheadline)
                }

                Text(session.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [KubbColors.recordsNavy, KubbColors.recordsSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(KubbColors.swedishGold.opacity(0.3), lineWidth: 1)
        )
    }

    private var mainStat: String {
        if session.safePhase == .fourMetersBlasting, let score = session.totalSessionScore {
            return score > 0 ? "+\(score)" : "\(score)"
        }
        return String(format: "%.1f%%", session.accuracy)
    }

    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self.frame(width: 340))
        renderer.scale = 3.0
        return renderer.uiImage
    }

    private func computeMaxStreak() -> Int {
        var maxStreak = 0
        var currentStreak = 0
        for round in session.rounds.sorted(by: { $0.roundNumber < $1.roundNumber }) {
            for throwRecord in round.throwRecords.sorted(by: { $0.throwNumber < $1.throwNumber }) {
                if throwRecord.result == .hit {
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                } else {
                    currentStreak = 0
                }
            }
        }
        return maxStreak
    }
}

#Preview {
    SessionShareCardView(
        session: TrainingSession(
            phase: .eightMeters,
            sessionType: .standard,
            configuredRounds: 10,
            startingBaseline: .north
        )
    )
    .padding()
}
