//
//  TrainingSession+ShareCard.swift
//  Kubb Coach
//
//  Maps a `TrainingSession` into the generic `ShareCardData` consumed
//  by `ShareCardView`. One mapper covers all training phases (8m, 4m,
//  Inkasting); branches happen by `safePhase`.
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
            mainStat: shareMainStat(settings: settings, context: context),
            mainStatTint: .gold,
            subtitle: safePhase.displayName,
            subtitleCaption: shareSubtitleCaption(context: context),
            statRows: shareStatRows(settings: settings, context: context),
            personalBests: personalBests,
            date: createdAt
        )
    }

    private func fetchInkastingSettings(in context: ModelContext) -> InkastingSettings {
        let descriptor = FetchDescriptor<InkastingSettings>()
        return (try? context.fetch(descriptor))?.first ?? InkastingSettings()
    }

    private func shareMainStat(settings: InkastingSettings, context: ModelContext) -> String {
        switch safePhase {
        case .fourMetersBlasting:
            if let score = totalSessionScore {
                return score > 0 ? "+\(score)" : "\(score)"
            }
            return "—"
        case .inkastingDrilling:
            if let area = averageClusterArea(context: context) {
                return settings.formatArea(area)
            }
            return "—"
        default:
            return String(format: "%.1f%%", accuracy)
        }
    }

    private func shareSubtitleCaption(context: ModelContext) -> String? {
        if safePhase == .inkastingDrilling, averageClusterArea(context: context) != nil {
            return "avg cluster area"
        }
        return nil
    }

    private func shareStatRows(settings: InkastingSettings, context: ModelContext) -> [ShareCardStatRow] {
        switch safePhase {
        case .eightMeters:
            return eightMeterShareRows()
        case .fourMetersBlasting:
            return fourMeterShareRows()
        case .inkastingDrilling:
            return inkastingShareRows(settings: settings, context: context)
        case .gameTracker, .pressureCooker:
            return []
        }
    }

    private func eightMeterShareRows() -> [ShareCardStatRow] {
        var rows: [ShareCardStatRow] = [
            .pair(
                ShareCardLabel(
                    icon: "checkmark.circle.fill",
                    text: "\(totalHits)/\(totalThrows) hits",
                    tint: Color.Kubb.forestGreen
                ),
                ShareCardLabel(
                    icon: "repeat",
                    text: "\(configuredRounds) rounds"
                )
            )
        ]

        let maxStreak = computeMaxHitStreak()
        if maxStreak > 0 {
            rows.append(.single(ShareCardLabel(
                icon: "flame.fill",
                text: "\(maxStreak) hit streak",
                tint: Color.Kubb.phase4m
            )))
        }

        if kingThrowCount > 0 {
            let suffix = String(format: "%.0f%%", kingThrowAccuracy)
            rows.append(.single(ShareCardLabel(
                icon: "crown.fill",
                text: "\(kingThrowCount) king shot\(kingThrowCount == 1 ? "" : "s") · \(suffix)",
                tint: Color.Kubb.swedishGold
            )))
        }

        return rows
    }

    private func fourMeterShareRows() -> [ShareCardStatRow] {
        var rows: [ShareCardStatRow] = [
            .single(ShareCardLabel(
                icon: "repeat",
                text: "\(configuredRounds) rounds · \(totalThrows) throws"
            )),
            .single(ShareCardLabel(
                icon: "flag.2.crossed.fill",
                text: "\(underParRoundsCount)/\(configuredRounds) rounds under par",
                tint: underParRoundsCount > 0 ? Color.Kubb.forestGreen : Color.white.opacity(0.6)
            ))
        ]

        if let avg = averageRoundScore {
            rows.append(.single(ShareCardLabel(
                icon: "chart.bar.fill",
                text: String(format: "Avg %+.1f per round", avg),
                tint: avg < 0 ? Color.Kubb.forestGreen : Color.white.opacity(0.6)
            )))
        }

        return rows
    }

    private func inkastingShareRows(settings: InkastingSettings, context: ModelContext) -> [ShareCardStatRow] {
        var rows: [ShareCardStatRow] = [
            .single(ShareCardLabel(
                icon: "repeat",
                text: "\(configuredRounds) rounds · \(totalInkastKubbs) kubbs"
            ))
        ]

        if let radius = averageClusterRadius(context: context) {
            rows.append(.single(ShareCardLabel(
                icon: "circle.dashed",
                text: "avg radius \(settings.formatDistance(radius))",
                tint: Color.white.opacity(0.85)
            )))
        }

        let perfect = perfectRoundsCount(context: context)
        rows.append(.single(ShareCardLabel(
            icon: "checkmark.circle.fill",
            text: "\(perfect)/\(configuredRounds) perfect rounds",
            tint: perfect > 0 ? Color.Kubb.forestGreen : Color.white.opacity(0.6)
        )))

        if let totalOutliers = totalOutliers(context: context), configuredRounds > 0 {
            let avg = Double(totalOutliers) / Double(configuredRounds)
            rows.append(.single(ShareCardLabel(
                icon: avg < 1 ? "checkmark.seal.fill" : "xmark.circle.fill",
                text: String(format: "%.1f outliers/round", avg),
                tint: avg < 1 ? Color.Kubb.forestGreen : Color.Kubb.phasePC
            )))
        }

        return rows
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
