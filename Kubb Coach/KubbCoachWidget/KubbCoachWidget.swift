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
    @Environment(\.widgetFamily) var widgetFamily
    let entry: KubbCoachWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            lockScreenView
        default:
            smallView
        }
    }

    // MARK: Home screen — small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon + app name
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Streak count
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(entry.widgetData.currentStreak)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.primary)
                Text(entry.widgetData.currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Competition countdown (if set)
            if let days = entry.widgetData.daysUntilCompetition, days >= 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(competitionColor(days: days))
                    Text(days == 0 ? "TODAY!" : "\(days)d left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(days == 0 ? competitionColor(days: days) : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Home screen — medium

    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left: streak
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("Training Streak")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.widgetData.currentStreak)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(entry.widgetData.currentStreak == 1 ? "day" : "days")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .padding(.vertical, 8)

            // Right: competition countdown or encouragement
            VStack(alignment: .leading, spacing: 6) {
                if let days = entry.widgetData.daysUntilCompetition, days >= 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(competitionColor(days: days))
                        Text(entry.widgetData.competitionName ?? "Competition")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if days == 0 {
                        Text("TODAY!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(competitionColor(days: days))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(days)")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(days == 1 ? "day left" : "days left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "target")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                    Text("Keep training!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Lock screen

    private var lockScreenView: some View {
        VStack(spacing: 0) {
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
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Helpers

    private func competitionColor(days: Int) -> Color {
        switch days {
        case 0...3: return .red
        case 4...7: return .orange
        default:    return .blue
        }
    }
}

// MARK: - Widget Configuration

struct KubbCoachWidget: Widget {
    let kind: String = "KubbCoachWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KubbCoachWidgetProvider()) { entry in
            KubbCoachWidgetView(entry: entry)
        }
        .configurationDisplayName("Training Streak")
        .description("Keep track of your training streak and upcoming competitions")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
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
}

#Preview(as: .systemMedium) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(
        date: Date(),
        widgetData: WidgetData(
            currentStreak: 12,
            daysUntilCompetition: 5,
            competitionName: "Regional Cup",
            lastUpdated: Date()
        )
    )
    KubbCoachWidgetEntry(
        date: Date(),
        widgetData: WidgetData(
            currentStreak: 3,
            daysUntilCompetition: nil,
            competitionName: nil,
            lastUpdated: Date()
        )
    )
}

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
}
