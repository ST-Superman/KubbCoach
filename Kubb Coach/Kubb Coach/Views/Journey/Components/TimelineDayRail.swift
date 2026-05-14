// TimelineDayRail.swift
// Left-column day marker: weekday label, day number, dot, and vertical connector.

import SwiftUI

struct TimelineDayRail: View {
    let date: Date
    let isToday: Bool
    let hasConnector: Bool  // false for the last group in the list

    private var weekdayAbbr: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date).uppercased()
    }

    private var dayText: String {
        if isToday { return "NOW" }
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Weekday abbreviation
            Text(weekdayAbbr)
                .font(KubbFont.inter(10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(isToday ? Color.Kubb.swedishBlue : Color.Kubb.textSec)

            // Day number or "NOW"
            Text(dayText)
                .font(isToday
                      ? KubbFont.inter(11, weight: .heavy)
                      : KubbFont.inter(18, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(isToday ? Color.Kubb.swedishBlue : Color.Kubb.midnightNavy)

            // Dot (with ring for today)
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.Kubb.swedishBlue.opacity(0.13))
                        .frame(width: 20, height: 20)
                }
                Circle()
                    .fill(isToday ? Color.Kubb.swedishBlue : Color.Kubb.card)
                    .overlay(
                        isToday ? nil :
                            Circle().strokeBorder(Color.Kubb.sep, lineWidth: 2)
                    )
                    .frame(width: 12, height: 12)
            }
            .padding(.top, KubbSpacing.s)

            // Vertical connector line (fills remaining space)
            if hasConnector {
                Rectangle()
                    .fill(Color.Kubb.swedishBlue.opacity(0.13))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 4)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(width: 48)
    }
}

#Preview {
    HStack(alignment: .top, spacing: 12) {
        TimelineDayRail(date: Date(), isToday: true, hasConnector: true)
        TimelineDayRail(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, isToday: false, hasConnector: true)
        TimelineDayRail(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, isToday: false, hasConnector: false)
    }
    .padding()
    .background(Color(.systemBackground))
}
