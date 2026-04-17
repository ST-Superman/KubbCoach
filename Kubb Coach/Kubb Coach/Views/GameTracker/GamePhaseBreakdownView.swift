//
//  GamePhaseBreakdownView.swift
//  Kubb Coach
//
//  Displays a three-column Early / Mid / Late breakdown of field efficiency
//  and 8m hit rate for a single completed game.
//

import SwiftUI

// MARK: - GamePhase View Extensions

extension GamePhase {
    /// Accent color used in charts and breakdown cards.
    var color: Color {
        switch self {
        case .early: return KubbColors.meadowGreen
        case .mid:   return KubbColors.swedishBlue
        case .late:  return KubbColors.phase4m
        }
    }

    /// Short label for chart legends.
    var chartLabel: String {
        switch self {
        case .early: return "Early (0–4)"
        case .mid:   return "Mid (5–7)"
        case .late:  return "Late (8+)"
        }
    }
}

// MARK: - GamePhaseBreakdownView

/// A card showing field efficiency and 8m hit rate broken down by game phase.
/// Used in GameTrackerSummaryView for single-game analysis.
struct GamePhaseBreakdownView: View {
    let phaseBreakdown: [GamePhase: GamePhaseMetrics]

    /// True if none of the three phases have any data at all.
    private var hasNoData: Bool {
        GamePhase.allCases.allSatisfy {
            let m = phaseBreakdown[$0]
            return m == nil || (!m!.hasFieldData && !m!.has8mData)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if hasNoData {
                Text("Record baton counts during games to see phase-level analysis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                phaseColumns
                legend
            }
        }
        .compactCardPadding
        .elevatedCard(cornerRadius: DesignConstants.mediumRadius)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.split.3x1")
                .font(.subheadline)
                .foregroundStyle(KubbColors.swedishBlue)
            Text("Phase Breakdown")
                .headlineStyle()
        }
    }

    private var phaseColumns: some View {
        HStack(spacing: 8) {
            ForEach(GamePhase.allCases) { phase in
                phaseColumn(phase)
            }
        }
    }

    private func phaseColumn(_ phase: GamePhase) -> some View {
        let metrics = phaseBreakdown[phase]
        let hasData = metrics?.hasFieldData == true || metrics?.has8mData == true

        return VStack(spacing: 10) {
            // Phase name + kubb range
            VStack(spacing: 2) {
                Text(phase.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(phase.color)
                Text(phase.fieldKubbRange)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Field efficiency
            metricRow(
                label: "Field",
                value: metrics?.fieldEfficiency,
                unit: "k/b",
                threshold: 2.0,
                higherIsBetter: true,
                available: metrics?.hasFieldData ?? false
            )

            // 8m hit rate (stored as 0–1, display as %)
            metricRow(
                label: "8m",
                value: metrics?.eightMeterHitRate.map { $0 * 100 },
                unit: "%",
                threshold: 40.0,
                higherIsBetter: true,
                available: metrics?.has8mData ?? false
            )

            // Turn count badge
            if let count = metrics?.turnCount, count > 0, hasData {
                Text("\(count) rounds")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(phase.color.opacity(0.1)))
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(hasData ? phase.color.opacity(0.06) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(phase.color.opacity(hasData ? 0.15 : 0.08), lineWidth: 1)
                )
        )
    }

    private func metricRow(
        label: String,
        value: Double?,
        unit: String,
        threshold: Double,
        higherIsBetter: Bool,
        available: Bool
    ) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let v = value {
                let meetsGoal = higherIsBetter ? v >= threshold : v <= threshold
                let formatted = unit == "%" ? String(format: "%.0f%", v) : String(format: "%.1f", v)
                Text(formatted)
                    .font(.subheadline.bold())
                    .foregroundStyle(meetsGoal ? KubbColors.forestGreen : KubbColors.miss)
            } else if available {
                Text("—")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .font(.subheadline.bold())
                    .foregroundStyle(.quaternary)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendDot(KubbColors.forestGreen, "≥ goal")
            legendDot(KubbColors.miss, "< goal")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
