//
//  GameSession+ShareCard.swift
//  Kubb Coach
//
//  Maps a `GameSession` into the magazine-layout `ShareCardData` consumed
//  by `ShareCardView`. The GT card is visually a sibling of the 8m card:
//  hero = 8m accuracy %, stat cells = FieldEff / Result / Streak / PB.
//
//  Pull-quote bucket thresholds (sharp / honest / clean / scrappy) live
//  in ShareCardData.swift's `GTQualityThreshold` enum — tune those after
//  QA against ~20 historical GT sessions.
//

import SwiftUI

extension GameSession {
    func shareCardData(personalBests: [PersonalBest] = []) -> ShareCardData {
        let analysis = GamePerformanceAnalyzer.analyze(session: self)
        return ShareCardData(
            hero: heroValue(analysis: analysis),
            heroEyebrow: "FEATURE · 8M ACCURACY",
            pullQuote: pullQuote(analysis: analysis, hasPB: !personalBests.isEmpty),
            statCells: statCells(analysis: analysis, personalBests: personalBests),
            taglineSegment: "GAME TRACKER",
            issueNumber: issueNumber,
            personalBests: personalBests,
            date: completedAt ?? createdAt
        )
    }

    // MARK: - Hero

    private func heroValue(analysis: GamePerformanceAnalysis) -> ShareCardHero {
        let rate = (analysis.eightMeterHitRate ?? 0) * 100
        return .bigDecimalPercent(value: rate)
    }

    // MARK: - Stat cells

    private func statCells(
        analysis: GamePerformanceAnalysis,
        personalBests: [PersonalBest]
    ) -> [ShareCardStatCell] {
        [
            fieldEfficiencyCell(analysis: analysis),
            resultCell(),
            streakCell(),
            fourthCell(personalBests: personalBests)
        ]
    }

    private func fieldEfficiencyCell(analysis: GamePerformanceAnalysis) -> ShareCardStatCell {
        let value: String
        if let eff = analysis.fieldEfficiency {
            value = String(format: "%.1f", eff)
        } else {
            value = "—"
        }
        return ShareCardStatCell(
            value: value,
            label: "FIELD EFF",
            dotColor: Color.Kubb.darkForest,
            style: .standard
        )
    }

    private func resultCell() -> ShareCardStatCell {
        if gameMode == .phantom {
            return ShareCardStatCell(
                value: "DRILL",
                label: "MODE",
                dotColor: Color.Kubb.swedishGold,
                style: .drill
            )
        }

        let (userKubbs, oppKubbs) = scorePair()
        let didWin = userWon ?? false
        let prefix = didWin ? "W" : "L"
        let dotColor = didWin ? Color.Kubb.swedishBlue : Color.Kubb.miss
        return ShareCardStatCell(
            value: "\(prefix) \(userKubbs)-\(oppKubbs)",
            label: "RESULT",
            dotColor: dotColor,
            style: .standard
        )
    }

    /// Kubbs cleared per side at game end. Derived from the final turn's
    /// `baselineAfter` snapshots — each side starts with 5 baseline kubbs.
    private func scorePair() -> (user: Int, opponent: Int) {
        let initial = 5
        guard let lastTurn = sortedTurns.last,
              let userSide = userGameSide else {
            return (0, 0)
        }
        let (userBaselineAfter, oppBaselineAfter): (Int, Int)
        switch userSide {
        case .sideA:
            userBaselineAfter = lastTurn.sideABaselineAfter
            oppBaselineAfter = lastTurn.sideBBaselineAfter
        case .sideB:
            userBaselineAfter = lastTurn.sideBBaselineAfter
            oppBaselineAfter = lastTurn.sideABaselineAfter
        }
        let userKubbs = max(0, initial - oppBaselineAfter)
        let oppKubbs = max(0, initial - userBaselineAfter)
        return (userKubbs, oppKubbs)
    }

    private func streakCell() -> ShareCardStatCell {
        ShareCardStatCell(
            value: "\(longestUserProgressStreak())",
            label: "STREAK",
            dotColor: Color.Kubb.phase4m,
            style: .standard
        )
    }

    /// Longest run of consecutive user turns where the user made any positive
    /// progress. Mirrors the 8m "hit streak" concept at the turn level.
    private func longestUserProgressStreak() -> Int {
        var maxStreak = 0
        var current = 0
        for turn in userTurns {
            if turn.progress > 0 {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 0
            }
        }
        return maxStreak
    }

    private func fourthCell(personalBests: [PersonalBest]) -> ShareCardStatCell {
        if personalBests.isEmpty {
            return playedDateCell()
        }
        if personalBests.count > 1 {
            return ShareCardStatCell(
                value: "+\(personalBests.count)",
                label: "PERSONAL BESTS",
                dotColor: Color.Kubb.swedishGold,
                style: .personalBest
            )
        }
        return ShareCardStatCell(
            value: "PB",
            label: truncatedPBLabel(personalBests[0].category.displayName),
            dotColor: Color.Kubb.swedishGold,
            style: .personalBest
        )
    }

    private func playedDateCell() -> ShareCardStatCell {
        let dayMonth = (completedAt ?? createdAt)
            .formatted(.dateTime.month(.abbreviated).day())
            .uppercased()
        return ShareCardStatCell(
            value: dayMonth,
            label: "PLAYED",
            dotColor: Color.Kubb.textSec,
            style: .date
        )
    }

    private func truncatedPBLabel(_ raw: String) -> String {
        let upper = raw.uppercased()
        if upper.count <= ShareCard.pbLabelMaxChars { return upper }
        return String(upper.prefix(ShareCard.pbLabelMaxChars - 1)) + "…"
    }

    // MARK: - Pull quote bucketing

    private func pullQuote(analysis: GamePerformanceAnalysis, hasPB: Bool) -> ShareCardPullQuote? {
        if gameMode == .phantom {
            return ShareCardPullQuote(line1: "Drill game,", line2: "called good.")
        }

        let didWin = userWon ?? false
        if hasPB {
            return ShareCardPullQuote(
                line1: "Game called.",
                line2: didWin ? "Best run." : "Best yet."
            )
        }

        let accuracy = analysis.eightMeterHitRate ?? 0
        let fieldEff = analysis.fieldEfficiency ?? 0

        if accuracy >= GTQualityThreshold.sharpAccuracy {
            if didWin {
                if fieldEff >= GTQualityThreshold.cleanFieldEff {
                    return ShareCardPullQuote(line1: "Clean field.", line2: "Won.")
                }
                return ShareCardPullQuote(line1: "Sharp throws.", line2: "Earned it.")
            }
            return ShareCardPullQuote(line1: "Sharp throws.", line2: "Next time.")
        }

        if accuracy >= GTQualityThreshold.honestAccuracy {
            if didWin {
                if fieldEff < GTQualityThreshold.scrappyFieldEff {
                    return ShareCardPullQuote(
                        line1: "Scrappy win.",
                        line2: "\(totalTurns) turns."
                    )
                }
                return ShareCardPullQuote(line1: "Game called.", line2: "Took it.")
            }
            return ShareCardPullQuote(line1: "Game called.", line2: "Next time.")
        }

        // Rough bucket (accuracy < honestAccuracy)
        if didWin {
            return ShareCardPullQuote(line1: "Long game.", line2: "Took it.")
        }
        return ShareCardPullQuote(line1: "Reps in.", line2: "\(totalTurns) turns.")
    }

    // MARK: - Helpers

    private var issueNumber: Int {
        let h = abs(id.hashValue)
        return (h % 999) + 1
    }
}
