//
//  GameShareCardView.swift
//  Kubb Coach
//
//  Share card for completed Game Tracker sessions.
//

import SwiftUI

struct GameShareCardView: View {
    let session: GameSession
    var newPersonalBests: [PersonalBest] = []

    private var analysis: GamePerformanceAnalysis {
        GamePerformanceAnalyzer.analyze(session: session)
    }

    /// Non-nil only for competitive defeats — the winner's performance for comparison.
    private var opponentAnalysis: GamePerformanceAnalysis? {
        guard session.gameMode == .competitive,
              session.userWon == false,
              let winnerSide = session.winnerSide else { return nil }
        return GamePerformanceAnalyzer.analyze(session: session, forSide: winnerSide)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                headerSection
                statsSection
                if !newPersonalBests.isEmpty { personalBestsSection }
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

            Text(session.gameMode.displayName)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 6) {
            let avg = session.averageUserProgress
            Label(
                String(format: "%+.1f avg progress/turn", avg),
                systemImage: "chart.bar.fill"
            )
            .foregroundStyle(avg >= 0 ? KubbColors.forestGreen : KubbColors.miss)

            if let eff = analysis.fieldEfficiency, analysis.fieldTurnsWithData >= 1 {
                if let opp = opponentAnalysis, let oppEff = opp.fieldEfficiency, opp.fieldTurnsWithData >= 1 {
                    Label(
                        String(format: "You %.2f | Them %.2f kubbs/baton", eff, oppEff),
                        systemImage: "flag.2.crossed.fill"
                    )
                    .foregroundStyle(eff >= 2.0 ? KubbColors.forestGreen : KubbColors.miss)
                } else {
                    Label(
                        String(format: "%.2f kubbs/baton field eff.", eff),
                        systemImage: "flag.2.crossed.fill"
                    )
                    .foregroundStyle(eff >= 2.0 ? KubbColors.forestGreen : KubbColors.miss)
                }
            }

            if let rate = analysis.eightMeterHitRate, analysis.eightMeterAttempts >= 2 {
                if let opp = opponentAnalysis, let oppRate = opp.eightMeterHitRate, opp.eightMeterAttempts >= 2 {
                    Label(
                        String(format: "You %.0f%% | Them %.0f%% 8m rate", rate * 100, oppRate * 100),
                        systemImage: "target"
                    )
                    .foregroundStyle(rate >= 0.40 ? KubbColors.forestGreen : KubbColors.miss)
                } else {
                    Label(
                        String(format: "%.0f%% 8m hit rate", rate * 100),
                        systemImage: "target"
                    )
                    .foregroundStyle(rate >= 0.40 ? KubbColors.forestGreen : KubbColors.miss)
                }
            }

            let kingShots = session.kingOpportunityTurns.count
            if kingShots > 0 {
                Label(
                    "\(kingShots) king shot\(kingShots == 1 ? "" : "s")",
                    systemImage: "crown.fill"
                )
                .foregroundStyle(KubbColors.swedishGold)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.85))
    }

    // MARK: - Personal Bests

    private var personalBestsSection: some View {
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
                ForEach(newPersonalBests, id: \.id) { pb in
                    Text(pb.category.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(KubbColors.celebrationGoldEnd)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Date

    private var dateSection: some View {
        Text(session.createdAt, style: .date)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Main stat

    private var mainStat: String {
        guard session.isComplete, session.winnerSide != nil else {
            return "GAME"
        }
        if session.gameMode == .phantom {
            return "VICTORY"
        }
        if let won = session.userWon {
            return won ? "VICTORY" : "DEFEAT"
        }
        return "FINISHED"
    }

    private var mainStatGradient: LinearGradient {
        let isWin: Bool = {
            if session.gameMode == .phantom { return true }
            return session.userWon ?? false
        }()

        return LinearGradient(
            colors: isWin
                ? [KubbColors.celebrationGoldStart, KubbColors.celebrationGoldEnd]
                : [Color.white.opacity(0.7), Color.white.opacity(0.5)],
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
}
