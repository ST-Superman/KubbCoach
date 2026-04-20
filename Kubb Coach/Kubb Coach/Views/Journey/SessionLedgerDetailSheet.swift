// SessionLedgerDetailSheet.swift
// Tapping a ledger row opens this sheet — phase-tinted header + phase-specific body.

import SwiftUI

struct SessionLedgerDetailSheet: View {
    let row: LedgerRow
    @Environment(\.dismiss) private var dismiss

    private var phaseColor: Color { Color.Kubb.phase(row.phase) }

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle
            Capsule()
                .fill(Color.Kubb.sep)
                .frame(width: 40, height: 4)
                .padding(.top, KubbSpacing.s2)
                .padding(.bottom, KubbSpacing.s)

            // Phase-tinted header
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [phaseColor, phaseColor.shaded(by: -0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea(edges: .top)

                // Decorative circle
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 160, height: 160)
                    .offset(x: 40, y: -40)

                VStack(alignment: .leading, spacing: 0) {
                    // Caption
                    HStack {
                        Text("SESSION · \(row.dateLabel) · \(row.timeLabel)")
                            .font(KubbType.monoXS)
                            .tracking(KubbTracking.monoS)
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }

                    Text(row.phase.fullName)
                        .font(KubbFont.fraunces(28, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.top, KubbSpacing.xs)

                    HStack(alignment: .lastTextBaseline, spacing: KubbSpacing.xxl) {
                        VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
                            Text(row.statLine)
                                .font(KubbType.displayXL)
                                .tracking(KubbTracking.displayXL)
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: KubbSpacing.xxs) {
                            Text(row.subLine)
                                .font(KubbType.monoXS)
                                .tracking(0.4)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(row.row.deviceType)
                                .font(KubbType.monoXS)
                                .tracking(0.4)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.top, KubbSpacing.m2)
                }
                .padding(.horizontal, KubbSpacing.l2)
                .padding(.vertical, KubbSpacing.l)
            }

            // Phase-specific body
            ScrollView(showsIndicators: false) {
                VStack(spacing: KubbSpacing.m) {
                    phaseBody
                }
                .padding(KubbSpacing.l2)
                .padding(.bottom, 40)
            }
            .background(Color.Kubb.paper)
        }
        .background(Color.Kubb.paper)
    }

    @ViewBuilder
    private var phaseBody: some View {
        switch row.phase {
        case .eightMeter:
            EightMeterDetailBody(session: row.session, phaseColor: phaseColor)
        case .fourMeter:
            FourMeterDetailBody(session: row.session, phaseColor: phaseColor)
        case .inkasting:
            InkastingDetailBody(session: row.session, phaseColor: phaseColor)
        case .pressureCooker:
            PCDetailBody(session: row.session, phaseColor: phaseColor)
        }
    }
}

// Helper to expose session on LedgerRow
private extension LedgerRow {
    var row: SessionDisplayItem { session }
}

// MARK: – 8m detail body

private struct EightMeterDetailBody: View {
    let session: SessionDisplayItem
    let phaseColor: Color

    var body: some View {
        VStack(spacing: KubbSpacing.m) {
            DetailMetricRow(items: [
                ("Accuracy", String(format: "%.1f%%", session.accuracy), phaseColor),
                ("Hits", "\(session.totalHits)/\(session.totalThrows)", Color.Kubb.forestGreen),
                ("King throws", "\(session.kingThrowCount)", Color.Kubb.swedishGold),
            ])

            DetailCard(title: "Round accuracy") {
                AccuracyBarRow(accuracy: session.accuracy, color: phaseColor)
            }
        }
    }
}

// MARK: – 4m detail body

private struct FourMeterDetailBody: View {
    let session: SessionDisplayItem
    let phaseColor: Color

    var body: some View {
        VStack(spacing: KubbSpacing.m) {
            let scoreStr = session.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
            DetailMetricRow(items: [
                ("Score", scoreStr, session.sessionScore.map { $0 < 0 } == true ? Color.Kubb.forestGreen : phaseColor),
                ("Rounds", "\(session.roundCount)", phaseColor),
                ("Throws", "\(session.totalThrows)", Color.Kubb.textSec),
            ])
        }
    }
}

// MARK: – Inkasting detail body

private struct InkastingDetailBody: View {
    let session: SessionDisplayItem
    let phaseColor: Color

    var body: some View {
        VStack(spacing: KubbSpacing.m) {
            DetailMetricRow(items: [
                ("Accuracy", String(format: "%.1f%%", session.accuracy), phaseColor),
                ("Kubbs", "\(session.totalThrows)", phaseColor),
                ("Rounds", "\(session.roundCount)", Color.Kubb.textSec),
            ])

            DetailCard(title: "Throw placement") {
                // Reuse the field map from PhaseAnalysisView with placeholder data
                PAInkastingClusterMap(
                    throwPoints: placeholderThrows,
                    targetRadiusNorm: 0.04,
                    targetRadiusLabel: "—",
                    outlierCount: 0,
                    phaseColor: phaseColor
                )
                .aspectRatio(4/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: KubbRadius.m))
            }
        }
    }

    private let placeholderThrows: [InkastingThrow] = [
        InkastingThrow(xRel:  0.000, yRel:  0.000, isOutlier: false),
        InkastingThrow(xRel:  0.018, yRel:  0.012, isOutlier: false),
        InkastingThrow(xRel: -0.015, yRel: -0.010, isOutlier: false),
        InkastingThrow(xRel:  0.022, yRel: -0.008, isOutlier: false),
        InkastingThrow(xRel: -0.008, yRel:  0.020, isOutlier: false),
        InkastingThrow(xRel:  0.010, yRel:  0.018, isOutlier: false),
        InkastingThrow(xRel: -0.020, yRel:  0.005, isOutlier: false),
        InkastingThrow(xRel:  0.005, yRel: -0.022, isOutlier: false),
    ]
}

// MARK: – PC detail body

private struct PCDetailBody: View {
    let session: SessionDisplayItem
    let phaseColor: Color

    var body: some View {
        DetailMetricRow(items: [
            ("Score", session.sessionScore.map { "\($0)" } ?? "—", phaseColor),
            ("Rounds", "\(session.roundCount)", phaseColor),
            ("Throws", "\(session.totalThrows)", Color.Kubb.textSec),
        ])
    }
}

// MARK: – Shared detail components

private struct DetailCard<Content: View>: View {
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            Text(title)
                .font(KubbFont.inter(12, weight: .bold))
                .foregroundStyle(Color.Kubb.textSec)
            content()
        }
        .padding(KubbSpacing.m2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .kubbCardShadow()
    }
}

private struct DetailMetricRow: View {
    let items: [(String, String, Color)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
                    Text(item.0)
                        .font(KubbType.monoXS)
                        .tracking(0.8)
                        .foregroundStyle(Color.Kubb.textSec)
                    Text(item.1)
                        .font(KubbFont.fraunces(22, weight: .medium))
                        .tracking(KubbTracking.title)
                        .foregroundStyle(item.2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(KubbSpacing.m2)
                .background(Color.Kubb.card)
                .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
                .kubbCardShadow()

                if idx < items.count - 1 {
                    Spacer().frame(width: KubbSpacing.s)
                }
            }
        }
    }
}

private struct AccuracyBarRow: View {
    let accuracy: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(accuracy / 100), height: 8)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.1f%%", accuracy))
                .font(KubbType.monoXS)
                .foregroundStyle(color)
        }
    }
}
