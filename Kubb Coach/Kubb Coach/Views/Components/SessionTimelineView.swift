import SwiftUI

struct SessionTimelineView: View {
    let sessions: [SessionDisplayItem]

    private var groupedSessions: [(String, Date, [SessionDisplayItem])] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.createdAt)
        }

        return grouped.map { date, items in
            let label = formatDate(date)
            let sorted = items.sorted { $0.createdAt > $1.createdAt }
            return (label, date, sorted)
        }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedSessions.enumerated()), id: \.element.1) { index, group in
                let (label, _, items) = group
                let isLast = index == groupedSessions.count - 1

                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(KubbColors.swedishBlue)
                            .frame(width: 10, height: 10)

                        if !isLast {
                            Rectangle()
                                .fill(KubbColors.swedishBlue.opacity(0.2))
                                .frame(width: 2)
                        }
                    }
                    .frame(width: 10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ForEach(items) { item in
                            SessionTimelineCard(session: item)
                        }
                    }
                    .padding(.bottom, isLast ? 0 : 24)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(.dateTime.month().day().year())
        }
    }
}

struct SessionTimelineCard: View {
    let session: SessionDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                phaseBadge

                Spacer()

                Text(session.createdAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                keyStat

                Spacer()

                if session.roundCount > 0 {
                    sparkline
                }
            }

            HStack(spacing: 12) {
                Label("\(session.roundCount)/\(session.configuredRounds)", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let duration = session.durationFormatted {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if session.kingThrowCount > 0 {
                    Label("\(session.kingThrowCount)", systemImage: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(KubbColors.swedishGold)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(DesignConstants.smallRadius)
        .lightShadow()
    }

    private var phaseBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(phaseColor)
                .frame(width: 8, height: 8)

            Text(phaseLabel)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(phaseColor.opacity(0.15))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var keyStat: some View {
        switch session.phase {
        case .eightMeters:
            HStack(spacing: 4) {
                Text(String(format: "%.1f%%", session.accuracy))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(KubbColors.accuracyColor(for: session.accuracy))

                Text("accuracy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .fourMetersBlasting:
            HStack(spacing: 4) {
                Text(String(format: "%.1f%%", session.accuracy))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(KubbColors.accuracyColor(for: session.accuracy))

                Text("accuracy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .inkastingDrilling:
            HStack(spacing: 4) {
                Text(String(format: "%.1f%%", session.accuracy))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(KubbColors.accuracyColor(for: session.accuracy))

                Text("accuracy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .gameTracker:
            EmptyView()
        }
    }

    private var sparkline: some View {
        SparklineView(values: roundAccuracies, color: phaseColor)
            .frame(width: 60, height: 24)
    }

    private var roundAccuracies: [Double] {
        if let localSession = session.localSession {
            return localSession.rounds
                .sorted { $0.roundNumber < $1.roundNumber }
                .map { $0.accuracy }
        }
        return []
    }

    private var phaseLabel: String {
        switch session.phase {
        case .eightMeters: return "8M"
        case .fourMetersBlasting: return "4M"
        case .inkastingDrilling: return "INK"
        case .gameTracker: return "GAME"
        }
    }

    private var phaseColor: Color {
        switch session.phase {
        case .eightMeters: return KubbColors.phase8m
        case .fourMetersBlasting: return KubbColors.phase4m
        case .inkastingDrilling: return KubbColors.phaseInkasting
        case .gameTracker: return KubbColors.swedishBlue
        }
    }
}

#Preview {
    SessionTimelineView(sessions: [])
        .padding()
}
