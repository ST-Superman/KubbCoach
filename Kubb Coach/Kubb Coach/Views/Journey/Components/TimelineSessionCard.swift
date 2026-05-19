// TimelineSessionCard.swift
// Rich session card used in the Timeline vertical-rail list.

import SwiftUI
import SwiftData

struct TimelineSessionCard: View {
    let session: SessionDisplayItem
    let isPersonalBest: Bool
    let onTap: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var kubbPhase: KubbPhase {
        switch session.phase {
        case .eightMeters:        return .eightMeter
        case .fourMetersBlasting: return .fourMeter
        case .inkastingDrilling:  return .inkasting
        case .pressureCooker:     return .pressureCooker
        case .gameTracker:        return .eightMeter
        }
    }

    private var phaseColor: Color { Color.Kubb.phase(kubbPhase) }

    private var heroStat: String {
        switch session.phase {
        case .eightMeters:
            return String(format: "%.1f%%", session.accuracy)
        case .inkastingDrilling:
            return session.averageClusterRadius(context: modelContext)
                .map { String(format: "%.2fm", $0) } ?? "—"
        case .fourMetersBlasting:
            return session.sessionScore.map { $0 >= 0 ? "+\($0)" : "\($0)" } ?? "—"
        case .pressureCooker:
            return session.sessionScore.map { "\($0)" } ?? "—"
        case .gameTracker:
            return "—"
        }
    }

    private var heroSubLabel: String {
        switch session.phase {
        case .eightMeters:                     return "accuracy"
        case .inkastingDrilling:               return "cluster radius"
        case .fourMetersBlasting:              return "score"
        case .pressureCooker:                  return "points"
        case .gameTracker:                     return "—"
        }
    }

    private var isPartial: Bool {
        session.roundCount < session.configuredRounds
    }

    private var sparkValues: [Double] {
        switch session.phase {
        case .eightMeters:
            return session.roundSummaries.map { $0.accuracy }
        default:
            return session.roundSummaries.map { Double($0.score) }
        }
    }

    private var showSparkline: Bool {
        guard !sparkValues.isEmpty else { return false }
        switch session.phase {
        case .eightMeters, .inkastingDrilling, .fourMetersBlasting: return true
        default: return false
        }
    }

    private var useBarSparkline: Bool { session.phase == .fourMetersBlasting }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: session.createdAt).lowercased()
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left phase stripe — clipped naturally by card corner radius
                phaseColor.frame(width: 3)

                VStack(alignment: .leading, spacing: 0) {
                    topRow
                    heroRow.padding(.bottom, 0)
                    footerRow
                }
                .padding(KubbSpacing.m2)
            }
        }
        .buttonStyle(.plain)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.04), radius: 2, x: 0, y: 1)
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.06), radius: 8, x: 0, y: 3)
    }

    // MARK: – Top row: phase badge · watch chip · PB chip · time

    private var topRow: some View {
        HStack(spacing: KubbSpacing.s) {
            // Phase badge
            HStack(spacing: 4) {
                Image(systemName: kubbPhase.symbol)
                    .font(.system(size: 10, weight: .bold))
                Text(kubbPhase.fullName)
                    .font(KubbFont.inter(11, weight: .bold))
            }
            .padding(.horizontal, KubbSpacing.s)
            .padding(.vertical, 4)
            .background(phaseColor.opacity(0.1))
            .foregroundStyle(phaseColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Watch chip
            if session.deviceType == "Watch" {
                HStack(spacing: 3) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 8, weight: .bold))
                    Text("Watch")
                        .font(KubbFont.inter(10, weight: .bold))
                }
                .foregroundStyle(Color.Kubb.phase4m)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.Kubb.phase4m.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            // Partial chip
            if isPartial {
                Text("PARTIAL")
                    .font(KubbFont.inter(10, weight: .heavy))
                    .foregroundStyle(Color.Kubb.textSec)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.Kubb.sep.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            // PB chip
            if isPersonalBest {
                HStack(spacing: 3) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("PB")
                        .font(KubbFont.inter(10, weight: .heavy))
                }
                .foregroundStyle(Color.Kubb.pbInk)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.Kubb.swedishGold.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            Spacer()

            Text(timeString)
                .font(KubbFont.inter(11, weight: .regular))
                .foregroundStyle(Color.Kubb.textSec)
        }
        .padding(.bottom, KubbSpacing.s)
    }

    // MARK: – Hero row: big stat + sparkline

    private var heroRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(heroStat)
                    .font(KubbFont.inter(26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(phaseColor)
                    .lineLimit(1)
                Text(heroSubLabel)
                    .font(KubbFont.inter(11, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
            }

            if showSparkline {
                Spacer()
                if useBarSparkline {
                    MiniBarSparkline(values: sparkValues, color: phaseColor)
                        .frame(width: 70, height: 26)
                } else {
                    MiniSparkline(values: sparkValues, color: phaseColor)
                        .frame(width: 70, height: 26)
                }
            }
        }
    }

    // MARK: – Footer row: rounds · duration · king · Detail ›

    private var footerRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .semibold))
                Text("\(session.roundCount)/\(session.configuredRounds)")
                    .font(KubbFont.inter(11, weight: .medium))
            }
            .foregroundStyle(Color.Kubb.textSec)

            if let dur = session.durationFormatted {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                    Text(dur)
                        .font(KubbFont.inter(11, weight: .medium))
                }
                .foregroundStyle(Color.Kubb.textSec)
            }

            if session.kingThrowCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.Kubb.swedishGold)
                    Text("\(session.kingThrowCount)")
                        .font(KubbFont.inter(11, weight: .bold))
                        .foregroundStyle(Color.Kubb.swedishGold)
                }
            }

            Spacer()

            HStack(spacing: 3) {
                Text("Detail")
                    .font(KubbFont.inter(11, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Color.Kubb.swedishBlue)
        }
        .padding(.top, KubbSpacing.s2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.Kubb.sep)
                .frame(height: 0.5)
        }
    }
}

#Preview {
    let s8m = TrainingSession(
        createdAt: Date(),
        completedAt: Date(),
        phase: .eightMeters,
        configuredRounds: 10,
        startingBaseline: .north
    )
    let s4m = TrainingSession(
        createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
        completedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
        phase: .fourMetersBlasting,
        configuredRounds: 5,
        startingBaseline: .north
    )
    return VStack(spacing: 12) {
        TimelineSessionCard(session: .local(s8m), isPersonalBest: true, onTap: {})
        TimelineSessionCard(session: .local(s4m), isPersonalBest: false, onTap: {})
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

// MARK: – Bar sparkline (used for 4m blasting rounds)

struct MiniBarSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard !values.isEmpty else { return }
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 0.001)
            let barW = max(1, (size.width - CGFloat(values.count - 1) * 2) / CGFloat(values.count))

            for (i, val) in values.enumerated() {
                let x = CGFloat(i) * (barW + 2)
                let barH = max(3, CGFloat(val - minV) / CGFloat(range) * size.height)
                let rect = CGRect(x: x, y: size.height - barH, width: barW, height: barH)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
            }
        }
    }
}
