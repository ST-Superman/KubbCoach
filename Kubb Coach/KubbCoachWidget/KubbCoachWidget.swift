//
//  KubbCoachWidget.swift
//  KubbCoachWidget
//
//  A configurable two-slot widget: the user picks any two of three metrics
//  (training streak, competition countdown, live match status) via
//  SelectMetricsIntent. Each metric renders through a shared `MetricDisplay`, so
//  the small hero / secondary pill, medium hero / panel, and lock layouts are
//  metric-agnostic. Data comes from the App Group store (WidgetDataService).
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct KubbCoachWidgetEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
    let primary: WidgetMetric
    let secondary: WidgetMetric
}

// MARK: - Timeline Provider

struct KubbCoachWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = KubbCoachWidgetEntry
    typealias Intent = SelectMetricsIntent

    func placeholder(in context: Context) -> KubbCoachWidgetEntry {
        KubbCoachWidgetEntry(
            date: Date(),
            widgetData: WidgetData(
                currentStreak: 7,
                daysUntilCompetition: 15,
                competitionName: "Tournament",
                lastUpdated: Date(),
                trainedToday: true,
                matchesAwaitingYou: 1,
                matchesAwaitingOpponent: 2
            ),
            primary: .streak,
            secondary: .competition
        )
    }

    func snapshot(for configuration: SelectMetricsIntent, in context: Context) async -> KubbCoachWidgetEntry {
        KubbCoachWidgetEntry(
            date: Date(),
            widgetData: WidgetDataService.shared.loadWidgetData(),
            primary: configuration.primary,
            secondary: configuration.secondary
        )
    }

    func timeline(for configuration: SelectMetricsIntent, in context: Context) async -> Timeline<KubbCoachWidgetEntry> {
        let data = WidgetDataService.shared.loadWidgetData()
        let now = Date()
        let entry = KubbCoachWidgetEntry(
            date: now,
            widgetData: data,
            primary: configuration.primary,
            secondary: configuration.secondary
        )
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        return Timeline(entries: [entry], policy: .after(midnight))
    }
}

// MARK: - Design Tokens (home screen only — lock screen uses system tint)

private enum WT {
    static let bgTop    = Color(red: 14/255.0,  green: 26/255.0,  blue: 46/255.0)
    static let bgBottom = Color(red: 26/255.0,  green: 47/255.0,  blue: 77/255.0)
    static let orange   = Color(red: 255/255.0, green: 138/255.0, blue: 61/255.0)
    static let blue     = Color(red: 91/255.0,  green: 163/255.0, blue: 208/255.0)
    static let match    = Color(red: 14/255.0,  green: 124/255.0, blue: 134/255.0)  // Color.Kubb.matchAccent
    static let gradient = LinearGradient(
        colors: [bgTop, bgBottom],
        startPoint: UnitPoint(x: 0.6, y: 0),
        endPoint: UnitPoint(x: 0.4, y: 1)
    )
}

// MARK: - Metric display model

/// The rendered pieces of one metric, so the layout views stay metric-agnostic.
struct MetricDisplay {
    let icon: String
    let tint: Color
    let heroValue: String   // big number, e.g. "7"
    let heroUnit: String    // "days" / "games"
    let caption: String     // "training streak" / "to US Nationals" / "waiting for your turn"
    let pillLabel: String   // short label for the pill: "Streak" / comp name / "Your turn"
    let pillValue: String   // pill trailing value: "7" / "15d" / "2"
    let eyebrow: String     // panel eyebrow: "STREAK" / "NEXT EVENT" / "MATCHES"
    let isEmpty: Bool        // true → show emptyText instead of a value
    let emptyText: String
}

extension WidgetMetric {
    func display(_ d: WidgetData) -> MetricDisplay {
        switch self {
        case .streak:
            return MetricDisplay(
                icon: "flame.fill", tint: WT.orange,
                heroValue: "\(d.currentStreak)", heroUnit: "days",
                caption: "training streak",
                pillLabel: "Streak", pillValue: "\(d.currentStreak)",
                eyebrow: "STREAK", isEmpty: false, emptyText: ""
            )

        case .competition:
            if let days = d.daysUntilCompetition, let comp = d.competitionName {
                return MetricDisplay(
                    icon: "flag.fill", tint: WT.blue,
                    heroValue: "\(days)", heroUnit: days == 1 ? "day" : "days",
                    caption: "to \(comp)",
                    pillLabel: comp, pillValue: "\(days)d",
                    eyebrow: "NEXT EVENT", isEmpty: false, emptyText: ""
                )
            }
            return MetricDisplay(
                icon: "flag", tint: WT.blue,
                heroValue: "", heroUnit: "", caption: "",
                pillLabel: "", pillValue: "",
                eyebrow: "NEXT EVENT", isEmpty: true, emptyText: "No upcoming event"
            )

        case .matches:
            let you = d.matchesAwaitingYou ?? 0
            let opp = d.matchesAwaitingOpponent ?? 0
            let icon = "point.3.connected.trianglepath.dotted"
            if you > 0 {
                return MetricDisplay(
                    icon: icon, tint: WT.match,
                    heroValue: "\(you)", heroUnit: you == 1 ? "game" : "games",
                    caption: "waiting for your turn",
                    pillLabel: "Your turn", pillValue: "\(you)",
                    eyebrow: "MATCHES", isEmpty: false, emptyText: ""
                )
            } else if opp > 0 {
                return MetricDisplay(
                    icon: icon, tint: WT.match,
                    heroValue: "\(opp)", heroUnit: opp == 1 ? "game" : "games",
                    caption: "waiting for opponent",
                    pillLabel: "Opponent", pillValue: "\(opp)",
                    eyebrow: "MATCHES", isEmpty: false, emptyText: ""
                )
            }
            return MetricDisplay(
                icon: icon, tint: WT.match,
                heroValue: "", heroUnit: "", caption: "",
                pillLabel: "", pillValue: "",
                eyebrow: "MATCHES", isEmpty: true, emptyText: "No active games"
            )
        }
    }
}

// MARK: - Generic metric views

private struct MetricHero: View {
    let d: MetricDisplay
    var valueSize: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if d.isEmpty {
                Text(d.emptyText)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(d.tint)
                    .lineLimit(2).minimumScaleFactor(0.6)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(d.heroValue)
                        .font(.system(size: valueSize, weight: .heavy))
                        .monospacedDigit().tracking(-2.5)
                        .foregroundStyle(d.tint)
                        .lineLimit(1).minimumScaleFactor(0.45)
                    Text(d.heroUnit)
                        .font(.system(size: 12, weight: .bold)).tracking(0.4)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                Text(d.caption)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1).truncationMode(.tail)
                    .padding(.top, 2)
            }
        }
    }
}

private struct MetricPill: View {
    let d: MetricDisplay

    var body: some View {
        if d.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: d.icon)
                    .font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.55))
                Text(d.emptyText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55)).lineLimit(1)
            }
        } else {
            HStack(spacing: 5) {
                Image(systemName: d.icon).font(.system(size: 10)).foregroundStyle(d.tint)
                Text(d.pillLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1).truncationMode(.tail).layoutPriority(1)
                Spacer(minLength: 4)
                Text(d.pillValue)
                    .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(d.tint).fixedSize()
            }
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
            )
        }
    }
}

private struct MetricPanel: View {
    let d: MetricDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: d.icon).font(.system(size: 9)).foregroundStyle(d.tint)
                Text(d.eyebrow)
                    .font(.system(size: 9, weight: .heavy)).tracking(0.8)
                    .foregroundStyle(d.tint.opacity(0.85))
            }
            Spacer()
            if d.isEmpty {
                Text(d.emptyText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9)).lineLimit(2)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(d.heroValue)
                        .font(.system(size: 40, weight: .heavy)).monospacedDigit().tracking(-1.5)
                        .foregroundStyle(d.tint)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(d.heroUnit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Text(d.caption)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(2).padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Home Screen slot layouts

private struct SlotSmallView: View {
    let primary: MetricDisplay
    let secondary: MetricDisplay

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("KUBB COACH")
                    .font(.system(size: 9, weight: .heavy)).tracking(1)
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Image(systemName: primary.icon).font(.system(size: 14)).foregroundStyle(primary.tint)
            }
            Spacer()
            MetricHero(d: primary, valueSize: 56)
            Spacer()
            MetricPill(d: secondary)
        }
        .padding(14)
        .containerBackground(WT.gradient, for: .widget)
    }
}

private struct SlotMediumView: View {
    let primary: MetricDisplay
    let secondary: MetricDisplay

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading) {
                HStack(spacing: 5) {
                    Image(systemName: primary.icon).font(.system(size: 11)).foregroundStyle(primary.tint)
                    Text("KUBB COACH")
                        .font(.system(size: 9, weight: .heavy)).tracking(1)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
                MetricHero(d: primary, valueSize: 64)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.5).padding(.vertical, 6)

            MetricPanel(d: secondary).padding(.leading, 16)
        }
        .padding(14)
        .containerBackground(WT.gradient, for: .widget)
    }
}

// MARK: - Lock Screen slot layout (accessoryRectangular)

private struct SlotLockView: View {
    let primary: MetricDisplay
    let secondary: MetricDisplay

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if primary.isEmpty {
                    Text(primary.emptyText).font(.system(size: 14, weight: .bold)).lineLimit(2)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(primary.heroValue)
                            .font(.system(size: 30, weight: .bold)).monospacedDigit().tracking(-1.5)
                        Text(primary.heroUnit.uppercased())
                            .font(.system(size: 11, weight: .semibold)).opacity(0.72).tracking(0.6)
                    }
                    Text(primary.caption)
                        .font(.system(size: 11, weight: .semibold)).opacity(0.72)
                        .lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer()
            if !secondary.isEmpty {
                VStack(spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: secondary.icon).font(.system(size: 11))
                        Text(secondary.pillValue).font(.system(size: 13, weight: .bold)).monospacedDigit()
                    }
                    Text(secondary.eyebrow)
                        .font(.system(size: 8, weight: .bold)).opacity(0.72).tracking(0.8)
                }
                .padding(.vertical, 6).padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.16)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget View

struct KubbCoachWidgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: KubbCoachWidgetEntry

    private var primary: MetricDisplay { entry.primary.display(entry.widgetData) }
    private var secondary: MetricDisplay { entry.secondary.display(entry.widgetData) }

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                SlotSmallView(primary: primary, secondary: secondary)
            case .systemMedium:
                SlotMediumView(primary: primary, secondary: secondary)
            case .accessoryRectangular:
                SlotLockView(primary: primary, secondary: secondary)
            default:
                SlotSmallView(primary: primary, secondary: secondary)
            }
        }
        .widgetURL(deepLink)
    }

    /// Route to the Virtual Matches tab when a shown match metric has games
    /// awaiting the user; otherwise the log-training flow.
    private var deepLink: URL {
        let showsMatches = entry.primary == .matches || entry.secondary == .matches
        if showsMatches, (entry.widgetData.matchesAwaitingYou ?? 0) > 0 {
            return URL(string: "kubbcoach://matches")!
        }
        return URL(string: "kubbcoach://log-training")!
    }
}

// MARK: - Widget Configuration

struct KubbCoachWidget: Widget {
    let kind: String = "KubbCoachWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectMetricsIntent.self, provider: KubbCoachWidgetProvider()) { entry in
            KubbCoachWidgetView(entry: entry)
        }
        .configurationDisplayName("Kubb Coach")
        .description("Show two stats of your choice: training streak, competition countdown, or live match status.")
        .supportedFamilies([.accessoryRectangular, .systemSmall, .systemMedium])
    }
}

// MARK: - Previews

private func sampleData(
    streak: Int = 7, days: Int? = 15, comp: String? = "US Nationals",
    trained: Bool = true, you: Int? = nil, opp: Int? = nil
) -> WidgetData {
    WidgetData(
        currentStreak: streak, daysUntilCompetition: days, competitionName: comp,
        lastUpdated: Date(), trainedToday: trained,
        matchesAwaitingYou: you, matchesAwaitingOpponent: opp
    )
}

#Preview("Small — Streak + Competition", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(streak: 10, days: 17, comp: "Beloit Open"),
                         primary: .streak, secondary: .competition)
}

#Preview("Small — Matches + Streak", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(streak: 12, you: 2, opp: 1),
                         primary: .matches, secondary: .streak)
}

#Preview("Small — Matches (opponent) + Comp", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(days: 5, comp: "Regional Cup", you: 0, opp: 3),
                         primary: .matches, secondary: .competition)
}

#Preview("Small — Matches (none)", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(you: 0, opp: 0),
                         primary: .matches, secondary: .streak)
}

#Preview("Medium — Streak + Matches", as: .systemMedium) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(streak: 33, you: 1, opp: 2),
                         primary: .streak, secondary: .matches)
}

#Preview("Medium — Matches + Competition", as: .systemMedium) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(days: 3, comp: "World Championships", you: 2, opp: 0),
                         primary: .matches, secondary: .competition)
}

#Preview("Lock — Streak + Competition", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(streak: 22, days: 8, comp: "Regional Cup"),
                         primary: .streak, secondary: .competition)
}

#Preview("Lock — Matches + Streak", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(streak: 45, you: 2, opp: 1),
                         primary: .matches, secondary: .streak)
}
