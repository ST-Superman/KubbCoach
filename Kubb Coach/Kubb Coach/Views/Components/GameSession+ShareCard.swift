//
//  GameSession+ShareCard.swift
//  Kubb Coach
//
//  Maps a `GameSession` into the generic `ShareCardData` consumed by
//  `ShareCardView`. Handles Game Tracker (competitive + phantom).
//

import SwiftUI

extension GameSession {
    func shareCardData(personalBests: [PersonalBest] = []) -> ShareCardData {
        let analysis = GamePerformanceAnalyzer.analyze(session: self)
        let opponentAnalysis: GamePerformanceAnalysis? = {
            guard gameMode == .competitive,
                  userWon == false,
                  let winnerSide = winnerSide else { return nil }
            return GamePerformanceAnalyzer.analyze(session: self, forSide: winnerSide)
        }()

        return ShareCardData(
            mainStat: shareMainStat,
            mainStatTint: shareMainStatTint,
            subtitle: gameMode.displayName,
            subtitleCaption: nil,
            statRows: shareStatRows(analysis: analysis, opponentAnalysis: opponentAnalysis),
            personalBests: personalBests,
            date: createdAt
        )
    }

    private var shareMainStat: String {
        guard isComplete, winnerSide != nil else { return "GAME" }
        if gameMode == .phantom { return "VICTORY" }
        if let won = userWon { return won ? "VICTORY" : "DEFEAT" }
        return "FINISHED"
    }

    private var shareMainStatTint: ShareCardData.MainStatTint {
        let isWin: Bool = {
            if gameMode == .phantom { return true }
            return userWon ?? false
        }()
        return isWin ? .gold : .dim
    }

    private func shareStatRows(
        analysis: GamePerformanceAnalysis,
        opponentAnalysis: GamePerformanceAnalysis?
    ) -> [ShareCardStatRow] {
        var rows: [ShareCardStatRow] = []

        let avg = averageUserProgress
        rows.append(.single(ShareCardLabel(
            icon: "chart.bar.fill",
            text: String(format: "%+.1f avg progress/turn", avg),
            tint: avg >= 0 ? Color.Kubb.forestGreen : Color.Kubb.phasePC
        )))

        if let eff = analysis.fieldEfficiency, analysis.fieldTurnsWithData >= 1 {
            if let opp = opponentAnalysis,
               let oppEff = opp.fieldEfficiency,
               opp.fieldTurnsWithData >= 1 {
                rows.append(.single(ShareCardLabel(
                    icon: "flag.2.crossed.fill",
                    text: String(format: "You %.2f | Them %.2f kubbs/baton", eff, oppEff),
                    tint: eff >= 2.0 ? Color.Kubb.forestGreen : Color.Kubb.phasePC
                )))
            } else {
                rows.append(.single(ShareCardLabel(
                    icon: "flag.2.crossed.fill",
                    text: String(format: "%.2f kubbs/baton field eff.", eff),
                    tint: eff >= 2.0 ? Color.Kubb.forestGreen : Color.Kubb.phasePC
                )))
            }
        }

        if let rate = analysis.eightMeterHitRate, analysis.eightMeterAttempts >= 2 {
            if let opp = opponentAnalysis,
               let oppRate = opp.eightMeterHitRate,
               opp.eightMeterAttempts >= 2 {
                rows.append(.single(ShareCardLabel(
                    icon: "target",
                    text: String(format: "You %.0f%% | Them %.0f%% 8m rate", rate * 100, oppRate * 100),
                    tint: rate >= 0.40 ? Color.Kubb.forestGreen : Color.Kubb.phasePC
                )))
            } else {
                rows.append(.single(ShareCardLabel(
                    icon: "target",
                    text: String(format: "%.0f%% 8m hit rate", rate * 100),
                    tint: rate >= 0.40 ? Color.Kubb.forestGreen : Color.Kubb.phasePC
                )))
            }
        }

        let kingShots = kingOpportunityTurns.count
        if kingShots > 0 {
            rows.append(.single(ShareCardLabel(
                icon: "crown.fill",
                text: "\(kingShots) king shot\(kingShots == 1 ? "" : "s")",
                tint: Color.Kubb.swedishGold
            )))
        }

        return rows
    }
}
