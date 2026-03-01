//
//  SessionShareCardView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/28/26.
//

import SwiftUI
import SwiftData

struct SessionShareCardView: View {
    let session: TrainingSession
    let personalBests: [PersonalBest]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                headerSection
                statsSection
                personalBestsSection
                dateSection
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .cornerRadius(20)
        .overlay(cardBorder)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("KUBB COACH")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(3)
                .foregroundStyle(.white.opacity(0.7))

            Text(mainStat)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(mainStatGradient)

            Text(session.safePhase.displayName)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }

    private var statsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Label("\(session.configuredRounds) rounds", systemImage: "repeat")
                Label("\(session.totalThrows) throws", systemImage: "figure.throw")
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.8))

            if session.safePhase == .eightMeters {
                eightMeterStats
            }
        }
    }

    private var eightMeterStats: some View {
        HStack(spacing: 16) {
            Label("\(session.totalHits) hits", systemImage: "checkmark.circle.fill")
                .foregroundStyle(KubbColors.forestGreen)

            if computeMaxStreak() > 0 {
                Label("\(computeMaxStreak()) streak", systemImage: "flame.fill")
                    .foregroundStyle(KubbColors.streakFlame)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var personalBestsSection: some View {
        if !session.newPersonalBests.isEmpty {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(KubbColors.swedishGold)
                    Text("PERSONAL BESTS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .tracking(2)
                }
                .foregroundStyle(.white.opacity(0.9))

                VStack(spacing: 4) {
                    ForEach(personalBests, id: \.id) { pb in
                        Text(pb.category.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(KubbColors.celebrationGoldEnd)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var dateSection: some View {
        Text(session.createdAt, style: .date)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
    }

    private var mainStatGradient: LinearGradient {
        LinearGradient(
            colors: [KubbColors.celebrationGoldStart, KubbColors.celebrationGoldEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [KubbColors.recordsNavy, KubbColors.recordsSurface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(KubbColors.swedishGold.opacity(0.3), lineWidth: 1)
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
        ),
        personalBests: []
    )
    .padding()
}
