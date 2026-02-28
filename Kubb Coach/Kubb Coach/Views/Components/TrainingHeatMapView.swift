import SwiftUI

struct TrainingHeatMapView: View {
    let sessions: [SessionDisplayItem]
    let weeksToShow: Int

    init(sessions: [SessionDisplayItem], weeksToShow: Int = 13) {
        self.sessions = sessions
        self.weeksToShow = weeksToShow
    }

    private var calendar: Calendar { Calendar.current }

    private var sessionCountByDay: [Date: Int] {
        var counts: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.createdAt)
            counts[day, default: 0] += 1
        }
        return counts
    }

    private var personalBestDays: Set<Date> {
        var best: [TrainingPhase: (Date, Double)] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.createdAt)
            let phase = session.phase
            if let existing = best[phase] {
                if session.accuracy > existing.1 {
                    best[phase] = (day, session.accuracy)
                }
            } else {
                best[phase] = (day, session.accuracy)
            }
        }
        return Set(best.values.map { $0.0 })
    }

    private var dayGrid: [[Date]] {
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today)

        guard let startDate = calendar.date(byAdding: .day, value: -(weeksToShow * 7 + todayWeekday - 1), to: today) else {
            return []
        }

        var weeks: [[Date]] = []
        var currentDate = startDate
        var currentWeek: [Date] = []

        while currentDate <= today {
            currentWeek.append(currentDate)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }

        return weeks
    }

    private var monthLabels: [(String, Int)] {
        var labels: [(String, Int)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var lastMonth = -1

        for (weekIndex, week) in dayGrid.enumerated() {
            if let firstDay = week.first {
                let month = calendar.component(.month, from: firstDay)
                if month != lastMonth {
                    labels.append((formatter.string(from: firstDay), weekIndex))
                    lastMonth = month
                }
            }
        }
        return labels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(monthLabels, id: \.1) { label, weekIndex in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(dayGrid.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(week, id: \.self) { day in
                                dayCell(for: day)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(0..<4) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForCount(level))
                        .frame(width: 10, height: 10)
                }

                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let count = sessionCountByDay[date] ?? 0
        let isPB = personalBestDays.contains(date)
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()

        RoundedRectangle(cornerRadius: 2)
            .fill(isFuture ? Color.clear : colorForCount(count))
            .frame(width: 12, height: 12)
            .overlay(
                Group {
                    if isPB && count > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(KubbColors.swedishGold, lineWidth: 1.5)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                    }
                }
            )
    }

    private func colorForCount(_ count: Int) -> Color {
        switch count {
        case 0: return Color(.systemGray5)
        case 1: return KubbColors.meadowGreen.opacity(0.4)
        case 2: return KubbColors.meadowGreen.opacity(0.7)
        default: return KubbColors.forestGreen
        }
    }
}

#Preview {
    TrainingHeatMapView(sessions: [])
        .padding()
}
