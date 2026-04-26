import SwiftUI

struct TrainingHeatMapView: View {
    let sessions: [SessionDisplayItem]
    let weeksToShow: Int

    // MARK: - Memoized Data

    @State private var memoizedSessionCountByDay: [Date: Int] = [:]
    @State private var memoizedPersonalBestDays: Set<Date> = []
    @State private var memoizedDayGrid: [[Date]] = []
    @State private var memoizedMonthLabels: [(String, Int)] = []
    @State private var lastSessionCount: Int = 0

    init(sessions: [SessionDisplayItem], weeksToShow: Int = 13) {
        self.sessions = sessions
        self.weeksToShow = weeksToShow
    }

    private var calendar: Calendar { Calendar.current }

    private var sessionCountByDay: [Date: Int] {
        memoizedSessionCountByDay
    }

    private var personalBestDays: Set<Date> {
        memoizedPersonalBestDays
    }

    private var dayGrid: [[Date]] {
        memoizedDayGrid
    }

    private var monthLabels: [(String, Int)] {
        memoizedMonthLabels
    }

    // MARK: - Calculation Methods

    private func calculateSessionCountByDay() -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.createdAt)
            counts[day, default: 0] += 1
        }
        return counts
    }

    private func calculatePersonalBestDays() -> Set<Date> {
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

    private func calculateDayGrid() -> [[Date]] {
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

    private func calculateMonthLabels(from grid: [[Date]]) -> [(String, Int)] {
        var labels: [(String, Int)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var lastMonth = -1

        for (weekIndex, week) in grid.enumerated() {
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

    private func updateMemoizedData() {
        // Only recalculate if session count changed
        guard sessions.count != lastSessionCount else { return }

        memoizedSessionCountByDay = calculateSessionCountByDay()
        memoizedPersonalBestDays = calculatePersonalBestDays()
        memoizedDayGrid = calculateDayGrid()
        memoizedMonthLabels = calculateMonthLabels(from: memoizedDayGrid)

        lastSessionCount = sessions.count
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
        .onAppear {
            if memoizedDayGrid.isEmpty {
                updateMemoizedData()
            }
        }
        .onChange(of: sessions.count) {
            updateMemoizedData()
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
                            .strokeBorder(Color.Kubb.swedishGold, lineWidth: 1.5)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                    }
                }
            )
    }

    private func colorForCount(_ count: Int) -> Color {
        switch count {
        case 0: return Color.Kubb.sep
        case 1: return Color.Kubb.forestGreen.opacity(0.35)
        case 2: return Color.Kubb.forestGreen.opacity(0.65)
        default: return Color.Kubb.forestGreen
        }
    }
}

#Preview {
    TrainingHeatMapView(sessions: [])
        .padding()
}
