//
//  KubbCoachWidget.swift
//  KubbCoachWidget
//
//  Created by Claude Code on 3/13/26.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct KubbCoachWidgetEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}

// MARK: - Timeline Provider

struct KubbCoachWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> KubbCoachWidgetEntry {
        KubbCoachWidgetEntry(
            date: Date(),
            widgetData: WidgetData(
                currentStreak: 7,
                daysUntilCompetition: 15,
                competitionName: "Tournament",
                lastUpdated: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KubbCoachWidgetEntry) -> Void) {
        let data = WidgetDataService.shared.loadWidgetData()
        let entry = KubbCoachWidgetEntry(date: Date(), widgetData: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KubbCoachWidgetEntry>) -> Void) {
        let data = WidgetDataService.shared.loadWidgetData()
        let currentDate = Date()

        // Create entry for now
        let entry = KubbCoachWidgetEntry(date: currentDate, widgetData: data)

        // Refresh timeline at midnight to update "days until competition"
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)

        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
}

// MARK: - Widget View

struct KubbCoachWidgetView: View {
    let entry: KubbCoachWidgetEntry

    var body: some View {
        VStack(spacing: 0) {
            // Streak section
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)

                Text("\(entry.widgetData.currentStreak)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Text(entry.widgetData.currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Competition section (if set)
            if let days = entry.widgetData.daysUntilCompetition, days >= 0 {
                Divider()
                    .padding(.vertical, 6)

                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(competitionColor(days: days))

                    if days == 0 {
                        Text("TODAY!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(competitionColor(days: days))
                    } else {
                        Text("\(days)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(days == 1 ? "day left" : "days left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(12)
    }

    private func competitionColor(days: Int) -> Color {
        switch days {
        case 0...3:
            return .red
        case 4...7:
            return .orange
        default:
            return .blue
        }
    }
}

// MARK: - Widget Configuration

struct KubbCoachWidget: Widget {
    let kind: String = "KubbCoachWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KubbCoachWidgetProvider()) { entry in
            KubbCoachWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Training Streak")
        .description("Keep track of your training streak and upcoming competitions")
        .supportedFamilies([.accessoryRectangular])  // Lock screen only
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(
        date: Date(),
        widgetData: WidgetData(
            currentStreak: 7,
            daysUntilCompetition: 15,
            competitionName: "US Nationals",
            lastUpdated: Date()
        )
    )
    KubbCoachWidgetEntry(
        date: Date(),
        widgetData: WidgetData(
            currentStreak: 45,
            daysUntilCompetition: 0,
            competitionName: "Local Tournament",
            lastUpdated: Date()
        )
    )
    KubbCoachWidgetEntry(
        date: Date(),
        widgetData: WidgetData(
            currentStreak: 12,
            daysUntilCompetition: nil,
            competitionName: nil,
            lastUpdated: Date()
        )
    )
}
