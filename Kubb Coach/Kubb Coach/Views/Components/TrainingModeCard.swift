import SwiftUI

struct TrainingModeCard: View {
    let phase: TrainingPhase
    let sessionCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(phaseColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(phase.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .foregroundStyle(phaseColor)
                    }

                    Spacer()

                    if sessionCount > 0 {
                        Text("\(sessionCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(phaseColor.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(phaseName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text(phaseDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if sessionCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(phaseColor)

                        Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(16)
            .frame(width: 200)
            .background(Color(.systemBackground))
            .cornerRadius(DesignConstants.mediumRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                    .strokeBorder(phaseColor.opacity(0.2), lineWidth: 1.5)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
        .pressableCard()
    }

    private var phaseName: String {
        switch phase {
        case .eightMeters: return "8 Meters"
        case .fourMetersBlasting: return "4m Blasting"
        case .inkastingDrilling: return "Inkasting"
        }
    }

    private var phaseDescription: String {
        switch phase {
        case .eightMeters: return "Precision throwing from the baseline"
        case .fourMetersBlasting: return "Close-range power clearing"
        case .inkastingDrilling: return "Field throwing accuracy"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .eightMeters: return KubbColors.phase8m
        case .fourMetersBlasting: return KubbColors.phase4m
        case .inkastingDrilling: return KubbColors.phaseInkasting
        }
    }
}

struct TrainingModeCardsRow: View {
    let sessions: [SessionDisplayItem]
    let playerLevel: Int
    let onSelectPhase: (TrainingPhase) -> Void

    // Filter training phases based on player level
    private var availablePhases: [TrainingPhase] {
        switch playerLevel {
        case 1:
            return [.eightMeters]
        case 2:
            return [.eightMeters, .fourMetersBlasting]
        default: // Level 3+
            return TrainingPhase.allCases
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availablePhases) { phase in
                    TrainingModeCard(
                        phase: phase,
                        sessionCount: sessionCount(for: phase),
                        action: { onSelectPhase(phase) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func sessionCount(for phase: TrainingPhase) -> Int {
        sessions.filter { $0.phase == phase && $0.completedAt != nil }.count
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            TrainingModeCard(
                phase: .eightMeters,
                sessionCount: 23,
                action: {}
            )

            TrainingModeCard(
                phase: .fourMetersBlasting,
                sessionCount: 12,
                action: {}
            )

            TrainingModeCard(
                phase: .inkastingDrilling,
                sessionCount: 0,
                action: {}
            )
        }
        .padding()
    }
}
