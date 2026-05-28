//
//  TrainingSession+ShareCard.swift
//  Kubb Coach
//
//  Maps a `TrainingSession` into the magazine-layout `ShareCardData`
//  consumed by `ShareCardView`. One mapper covers 8m, 4m, and Inkasting;
//  branches happen by `safePhase`.
//
//  Pull-quote copy and threshold constants live in ShareCardData.swift.
//

import SwiftUI
import SwiftData

extension TrainingSession {
    func shareCardData(
        context: ModelContext,
        personalBests: [PersonalBest]
    ) -> ShareCardData {
        let settings = fetchInkastingSettings(in: context)
        return ShareCardData(
            hero: heroValue(settings: settings, context: context),
            heroEyebrow: heroEyebrow,
            pullQuote: pullQuote(settings: settings, context: context, hasPB: !personalBests.isEmpty),
            statCells: statCells(settings: settings, context: context, personalBests: personalBests),
            taglineSegment: taglineSegment,
            issueNumber: issueNumber,
            personalBests: personalBests,
            date: createdAt
        )
    }

    // MARK: - Settings fetch

    private func fetchInkastingSettings(in context: ModelContext) -> InkastingSettings {
        let descriptor = FetchDescriptor<InkastingSettings>()
        return (try? context.fetch(descriptor))?.first ?? InkastingSettings()
    }

    // MARK: - Hero

    private func heroValue(settings: InkastingSettings, context: ModelContext) -> ShareCardHero {
        switch safePhase {
        case .eightMeters, .pressureCooker, .gameTracker:
            return .bigDecimalPercent(value: accuracy)
        case .fourMetersBlasting:
            return .signedInt(value: totalSessionScore ?? 0)
        case .inkastingDrilling:
            guard let radiusMeters = averageClusterRadius(context: context) else {
                return .measurement(value: "—", unit: "")
            }
            return measurementHero(radiusMeters: radiusMeters, settings: settings)
        }
    }

    private func measurementHero(radiusMeters: Double, settings: InkastingSettings) -> ShareCardHero {
        let formatted = settings.formatDistance(radiusMeters)
        let parts = formatted.split(separator: " ", maxSplits: 1).map(String.init)
        let value = parts.first ?? formatted
        let unit = parts.count > 1 ? parts[1] : ""
        return .measurement(value: value, unit: unit)
    }

    private var heroEyebrow: String {
        switch safePhase {
        case .eightMeters:         return "FEATURE · ACCURACY"
        case .fourMetersBlasting:  return "FEATURE · PAR DELTA"
        case .inkastingDrilling:   return "FEATURE · CLUSTER"
        case .gameTracker:         return "FEATURE · 8M ACCURACY"
        case .pressureCooker:      return "FEATURE · ACCURACY"
        }
    }

    private var taglineSegment: String {
        switch safePhase {
        case .eightMeters:         return "SOLO PRACTICE"
        case .fourMetersBlasting:  return "BLASTING"
        case .inkastingDrilling:   return "INKASTING"
        case .gameTracker:         return "GAME TRACKER"
        case .pressureCooker:      return "PRESSURE COOKER"
        }
    }

    // MARK: - Pull quote

    private func pullQuote(
        settings: InkastingSettings,
        context: ModelContext,
        hasPB: Bool
    ) -> ShareCardPullQuote? {
        switch safePhase {
        case .eightMeters:
            return eightMeterPullQuote(hasPB: hasPB)
        case .fourMetersBlasting:
            return fourMeterPullQuote(hasPB: hasPB)
        case .inkastingDrilling:
            return inkastingPullQuote(context: context, hasPB: hasPB)
        case .gameTracker, .pressureCooker:
            return nil
        }
    }

    private func eightMeterPullQuote(hasPB: Bool) -> ShareCardPullQuote {
        if hasPB {
            return ShareCardPullQuote(line1: "Eight meters,", line2: "best yet.")
        }
        if accuracy >= EightMeterPullQuoteThreshold.sharp {
            return ShareCardPullQuote(line1: "Eight meters,", line2: "locked in.")
        }
        if accuracy >= EightMeterPullQuoteThreshold.honest {
            return ShareCardPullQuote(line1: "Eight meters,", line2: "\(totalHits) hits.")
        }
        return ShareCardPullQuote(line1: "Reps in.", line2: "\(configuredRounds) rounds.")
    }

    private func fourMeterPullQuote(hasPB: Bool) -> ShareCardPullQuote {
        if hasPB {
            return ShareCardPullQuote(line1: "Four meters,", line2: "new low.")
        }
        let score = totalSessionScore ?? 0
        if score < 0 {
            return ShareCardPullQuote(line1: "Four meters,", line2: "played down.")
        }
        if score == 0 {
            return ShareCardPullQuote(line1: "Four meters,", line2: "clean lines.")
        }
        return ShareCardPullQuote(line1: "Reps in.", line2: "\(configuredRounds) rounds.")
    }

    private func inkastingPullQuote(context: ModelContext, hasPB: Bool) -> ShareCardPullQuote {
        if hasPB {
            return ShareCardPullQuote(line1: "Inkasting,", line2: "best yet.")
        }
        let radius = averageClusterRadius(context: context) ?? .greatestFiniteMagnitude
        if radius <= InkPullQuoteThreshold.tightRadiusMeters {
            return ShareCardPullQuote(line1: "Inkasting,", line2: "tucked in.")
        }
        return ShareCardPullQuote(line1: "Reps in.", line2: "\(configuredRounds) rounds.")
    }

    // MARK: - Stat cells

    private func statCells(
        settings: InkastingSettings,
        context: ModelContext,
        personalBests: [PersonalBest]
    ) -> [ShareCardStatCell] {
        let firstThree: [ShareCardStatCell]
        switch safePhase {
        case .eightMeters, .pressureCooker, .gameTracker:
            firstThree = eightMeterStatCells()
        case .fourMetersBlasting:
            firstThree = fourMeterStatCells()
        case .inkastingDrilling:
            firstThree = inkastingStatCells(context: context)
        }
        return firstThree + [fourthCell(personalBests: personalBests)]
    }

    private func eightMeterStatCells() -> [ShareCardStatCell] {
        [
            ShareCardStatCell(
                value: "\(totalHits)/\(totalThrows)",
                label: "KUBBS DOWN",
                dotColor: Color.Kubb.darkForest,
                style: .standard
            ),
            ShareCardStatCell(
                value: "\(configuredRounds)",
                label: "ROUNDS",
                dotColor: Color.Kubb.swedishBlue,
                style: .standard
            ),
            ShareCardStatCell(
                value: "\(computeMaxHitStreak())",
                label: "STREAK",
                dotColor: Color.Kubb.phase4m,
                style: .standard
            )
        ]
    }

    private func fourMeterStatCells() -> [ShareCardStatCell] {
        [
            ShareCardStatCell(
                value: "\(totalThrows)",
                label: "THROWS",
                dotColor: Color.Kubb.darkForest,
                style: .standard
            ),
            ShareCardStatCell(
                value: "\(configuredRounds)",
                label: "ROUNDS",
                dotColor: Color.Kubb.swedishBlue,
                style: .standard
            ),
            ShareCardStatCell(
                value: "\(underParRoundsCount)/\(configuredRounds)",
                label: "UNDER PAR",
                dotColor: Color.Kubb.phase4m,
                style: .standard
            )
        ]
    }

    private func inkastingStatCells(context: ModelContext) -> [ShareCardStatCell] {
        [
            ShareCardStatCell(
                value: "\(totalInkastKubbs)",
                label: "KUBBS",
                dotColor: Color.Kubb.darkForest,
                style: .standard
            ),
            ShareCardStatCell(
                value: "\(configuredRounds)",
                label: "ROUNDS",
                dotColor: Color.Kubb.swedishBlue,
                style: .standard
            ),
            ShareCardStatCell(
                value: "\(perfectRoundsCount(context: context))/\(configuredRounds)",
                label: "PERFECT",
                dotColor: Color.Kubb.phase4m,
                style: .standard
            )
        ]
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
        let dayMonth = createdAt
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

    // MARK: - Helpers

    private var issueNumber: Int {
        // Hash-stable fallback — README permits this. Not load-bearing.
        let h = abs(id.hashValue)
        return (h % 999) + 1
    }

    private func computeMaxHitStreak() -> Int {
        var maxStreak = 0
        var currentStreak = 0
        for round in rounds.sorted(by: { $0.roundNumber < $1.roundNumber }) {
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
