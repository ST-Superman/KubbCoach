// VolumeMiniBar.swift
// Condensed weekly-volume bar chart shown at the top of TimelineView.

import SwiftUI

struct VolumeMiniBar: View {
    let sessions: [SessionDisplayItem]

    private struct WeekData: Identifiable {
        let id: Int  // offset from today, 0 = current week
        let count: Int
        let isCurrent: Bool
    }

    private var weekData: [WeekData] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Find start of current week (Sunday)
        let currentWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

        return (0..<13).map { offset in
            let weekStart = cal.date(byAdding: .weekOfYear, value: -(12 - offset), to: currentWeekStart)!
            let weekEnd   = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            let count = sessions.filter { $0.createdAt >= weekStart && $0.createdAt < weekEnd }.count
            return WeekData(id: offset, count: count, isCurrent: offset == 12)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            HStack {
                Text("WEEKLY VOLUME · 13 WKS")
                    .font(KubbFont.inter(11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.Kubb.textSec)
                Spacer()
                Text("\(sessions.count) total")
                    .font(KubbFont.inter(11, weight: .semibold))
                    .foregroundStyle(Color.Kubb.textSec)
            }

            let maxCount = max(1, weekData.map(\.count).max() ?? 1)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(weekData) { week in
                    let height: CGFloat = week.count == 0
                        ? 4
                        : max(4, CGFloat(week.count) / CGFloat(maxCount) * 36)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(week: week))
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                }
            }
            .frame(height: 36)
        }
        .padding(.horizontal, KubbSpacing.m2)
        .padding(.vertical, KubbSpacing.m)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.04), radius: 2, x: 0, y: 1)
        .shadow(color: Color(red: 13/255, green: 23/255, blue: 38/255, opacity: 0.04), radius: 10, x: 0, y: 4)
    }

    private func barColor(week: WeekData) -> Color {
        if week.isCurrent { return Color.Kubb.swedishBlue }
        if week.count == 0 { return Color.Kubb.sep.opacity(0.5) }
        return Color.Kubb.swedishBlue.opacity(0.33)
    }
}

#Preview {
    // Build sample sessions spread across recent weeks without needing a container
    let sampleSessions: [SessionDisplayItem] = [0, 1, 3, 5, 8, 9, 14, 21, 28, 35].compactMap { daysAgo in
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let s = TrainingSession(
            createdAt: date,
            completedAt: date,
            configuredRounds: 10,
            startingBaseline: .north
        )
        return SessionDisplayItem.local(s)
    }
    return VolumeMiniBar(sessions: sampleSessions)
        .padding()
        .background(Color(.systemBackground))
}
