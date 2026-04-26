//
//  KubbCoachWidget.swift
//  KubbCoachWidget
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
                lastUpdated: Date(),
                trainedToday: true
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KubbCoachWidgetEntry) -> Void) {
        let data = WidgetDataService.shared.loadWidgetData()
        completion(KubbCoachWidgetEntry(date: Date(), widgetData: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KubbCoachWidgetEntry>) -> Void) {
        let data = WidgetDataService.shared.loadWidgetData()
        let currentDate = Date()
        let entry = KubbCoachWidgetEntry(date: currentDate, widgetData: data)
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
}

// MARK: - Design Tokens (home screen only — lock screen uses system tint)

private enum WT {
    static let bgTop    = Color(red: 14/255.0,  green: 26/255.0,  blue: 46/255.0)
    static let bgBottom = Color(red: 26/255.0,  green: 47/255.0,  blue: 77/255.0)
    static let orange   = Color(red: 255/255.0, green: 138/255.0, blue: 61/255.0)
    static let blue     = Color(red: 91/255.0,  green: 163/255.0, blue: 208/255.0)
}

// MARK: - Lock Screen: Empty State

private struct LockEmptyStateView: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Start a streak")
                    .font(.system(size: 13, weight: .bold))
                Text("Tap to log today's training")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.72)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen: Hero Countdown (comp < 14 days)

private struct LockHeroCountdownView: View {
    let streak: Int
    let days: Int
    let comp: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(days)")
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .tracking(-1.5)
                    Text("DAYS")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.72)
                        .tracking(0.6)
                }
                Text("to \(comp)")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.72)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                    Text("\(streak)")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                }
                Text("STREAK")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.72)
                    .tracking(0.8)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.16))
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen: Today CTA (default)

private struct LockTodayCTAView: View {
    let streak: Int
    let days: Int?
    let comp: String?
    let trainedToday: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                HStack(spacing: 4) {
                    if trainedToday {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Trained today")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.4)
                    } else {
                        Circle()
                            .frame(width: 7, height: 7)
                        Text("Not trained yet")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.4)
                    }
                }
                Spacer()
                Text("×\(streak)")
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .opacity(0.72)
            }

            Spacer()

            if let days, let comp {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(days)")
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .tracking(-1)
                    Text("days to \(comp)")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.72)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(streak)")
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .tracking(-1)
                    Text("day streak")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.72)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Home Screen: Streak Hero (systemSmall)

private struct StreakHeroSmallView: View {
    let streak: Int
    let days: Int?
    let comp: String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("KUBB COACH")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(WT.orange)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 56, weight: .heavy))
                        .monospacedDigit()
                        .tracking(-2.5)
                        .foregroundStyle(WT.orange)
                    Text("days")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                Text("training streak")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.top, 2)
            }

            Spacer()

            if let days, let comp {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(WT.blue)
                        Text(comp)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                    Text("\(days)d")
                        .font(.system(size: 11, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(WT.blue)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                )
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Text("Tap to set a goal")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .padding(14)
        .containerBackground(
            LinearGradient(
                colors: [WT.bgTop, WT.bgBottom],
                startPoint: UnitPoint(x: 0.6, y: 0),
                endPoint: UnitPoint(x: 0.4, y: 1)
            ),
            for: .widget
        )
    }
}

// MARK: - Widget View

struct KubbCoachWidgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: KubbCoachWidgetEntry

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                StreakHeroSmallView(
                    streak: entry.widgetData.currentStreak,
                    days: entry.widgetData.daysUntilCompetition,
                    comp: entry.widgetData.competitionName
                )
            case .accessoryRectangular:
                lockBody(entry.widgetData)
            default:
                StreakHeroSmallView(
                    streak: entry.widgetData.currentStreak,
                    days: entry.widgetData.daysUntilCompetition,
                    comp: entry.widgetData.competitionName
                )
            }
        }
        .widgetURL(URL(string: "kubbcoach://log-training")!)
    }

    @ViewBuilder
    private func lockBody(_ data: WidgetData) -> some View {
        if data.currentStreak == 0 && data.daysUntilCompetition == nil {
            LockEmptyStateView()
        } else if let days = data.daysUntilCompetition, days < 14 {
            LockHeroCountdownView(
                streak: data.currentStreak,
                days: days,
                comp: data.competitionName ?? ""
            )
        } else {
            LockTodayCTAView(
                streak: data.currentStreak,
                days: data.daysUntilCompetition,
                comp: data.competitionName,
                trainedToday: data.trainedToday
            )
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
        .supportedFamilies([.accessoryRectangular, .systemSmall])
    }
}

// MARK: - Previews

#Preview("Lock — Today CTA, trained, comp 15d", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 7, daysUntilCompetition: 15,
        competitionName: "US Nationals", lastUpdated: Date(), trainedToday: true))
}

#Preview("Lock — Today CTA, not trained, no comp", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 12, daysUntilCompetition: nil,
        competitionName: nil, lastUpdated: Date(), trainedToday: false))
}

#Preview("Lock — Hero Countdown, comp 8d", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 22, daysUntilCompetition: 8,
        competitionName: "Regional Cup", lastUpdated: Date(), trainedToday: true))
}

#Preview("Lock — Hero Countdown, comp TODAY", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 45, daysUntilCompetition: 0,
        competitionName: "Local Tournament", lastUpdated: Date(), trainedToday: true))
}

#Preview("Lock — Empty State", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 0, daysUntilCompetition: nil,
        competitionName: nil, lastUpdated: Date(), trainedToday: false))
}

#Preview("Lock — High streak, long comp name", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 365, daysUntilCompetition: 22,
        competitionName: "Midwest Regional Championship", lastUpdated: Date(), trainedToday: false))
}

#Preview("Home — Streak + comp", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 7, daysUntilCompetition: 15,
        competitionName: "US Nationals", lastUpdated: Date(), trainedToday: true))
}

#Preview("Home — High streak, no comp", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 365, daysUntilCompetition: nil,
        competitionName: nil, lastUpdated: Date(), trainedToday: true))
}

#Preview("Home — Long comp name", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: WidgetData(
        currentStreak: 33, daysUntilCompetition: 5,
        competitionName: "Midwest Regional Championship", lastUpdated: Date(), trainedToday: false))
}
