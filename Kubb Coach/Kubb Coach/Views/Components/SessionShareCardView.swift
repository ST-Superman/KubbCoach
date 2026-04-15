//
//  SessionShareCardView.swift
//  Kubb Coach
//

import SwiftUI
import SwiftData

struct SessionShareCardView: View {
    let session: TrainingSession
    let personalBests: [PersonalBest]

    @Environment(\.modelContext) private var modelContext
    @Query private var inkastingSettingsList: [InkastingSettings]

    private var inkastingSettings: InkastingSettings {
        inkastingSettingsList.first ?? InkastingSettings()
    }

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

    // MARK: - Header

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

            VStack(spacing: 2) {
                Text(session.safePhase.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                // For inkasting, clarify what the main stat represents
                if session.safePhase == .inkastingDrilling,
                   session.averageClusterArea(context: modelContext) != nil {
                    Text("avg cluster area")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Stats (phase-specific)

    private var statsSection: some View {
        VStack(spacing: 8) {
            switch session.safePhase {
            case .eightMeters:
                eightMeterStats
            case .fourMetersBlasting:
                fourMeterStats
            case .inkastingDrilling:
                inkastingStats
            case .gameTracker:
                EmptyView()
            }
        }
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.85))
    }

    private var eightMeterStats: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Label("\(session.totalHits)/\(session.totalThrows) hits", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(KubbColors.forestGreen)
                Label("\(session.configuredRounds) rounds", systemImage: "repeat")
            }

            if computeMaxStreak() > 0 {
                Label("\(computeMaxStreak()) hit streak", systemImage: "flame.fill")
                    .foregroundStyle(KubbColors.streakFlame)
            }

            if session.kingThrowCount > 0 {
                Label(
                    "\(session.kingThrowCount) king shot\(session.kingThrowCount == 1 ? "" : "s") · \(String(format: "%.0f%%", session.kingThrowAccuracy))",
                    systemImage: "crown.fill"
                )
                .foregroundStyle(KubbColors.swedishGold)
            }
        }
    }

    private var fourMeterStats: some View {
        VStack(spacing: 6) {
            Label("\(session.configuredRounds) rounds · \(session.totalThrows) throws", systemImage: "repeat")

            Label(
                "\(session.underParRoundsCount)/\(session.configuredRounds) rounds under par",
                systemImage: "flag.2.crossed.fill"
            )
            .foregroundStyle(session.underParRoundsCount > 0 ? KubbColors.forestGreen : .white.opacity(0.6))

            if let avg = session.averageRoundScore {
                Label(String(format: "Avg %+.1f per round", avg), systemImage: "chart.bar.fill")
                    .foregroundStyle(avg < 0 ? KubbColors.forestGreen : .white.opacity(0.6))
            }
        }
    }

    private var inkastingStats: some View {
        VStack(spacing: 6) {
            Label("\(session.configuredRounds) rounds · \(session.totalInkastKubbs) kubbs", systemImage: "repeat")

            if let area = session.averageClusterArea(context: modelContext) {
                let diameter = 2 * sqrt(area / .pi)
                Label(
                    "avg ∅ \(inkastingSettings.formatDistance(diameter))",
                    systemImage: "circle.dashed"
                )
                .foregroundStyle(.white.opacity(0.85))
            }

            let perfect = session.perfectRoundsCount(context: modelContext)
            Label(
                "\(perfect)/\(session.configuredRounds) perfect rounds",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(perfect > 0 ? KubbColors.forestGreen : .white.opacity(0.6))

            if let totalOutliers = session.totalOutliers(context: modelContext),
               session.configuredRounds > 0 {
                let avg = Double(totalOutliers) / Double(session.configuredRounds)
                Label(
                    String(format: "%.1f outliers/round", avg),
                    systemImage: avg < 1 ? "checkmark.seal.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(avg < 1 ? KubbColors.forestGreen : KubbColors.miss)
            }
        }
    }

    // MARK: - Personal Bests

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

    // MARK: - Date

    private var dateSection: some View {
        Text(session.createdAt, style: .date)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Main stat

    private var mainStat: String {
        switch session.safePhase {
        case .fourMetersBlasting:
            if let score = session.totalSessionScore {
                return score > 0 ? "+\(score)" : "\(score)"
            }
            return "—"
        case .inkastingDrilling:
            if let area = session.averageClusterArea(context: modelContext) {
                return inkastingSettings.formatArea(area)
            }
            return "—"
        default: // .eightMeters
            return String(format: "%.1f%%", session.accuracy)
        }
    }

    // MARK: - Styling

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

    // MARK: - Render

    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self.frame(width: 340))
        renderer.scale = 3.0
        return renderer.uiImage
    }

    // MARK: - Helpers

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
