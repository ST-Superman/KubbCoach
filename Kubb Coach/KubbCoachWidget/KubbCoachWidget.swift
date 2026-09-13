//
//  KubbCoachWidget.swift
//  KubbCoachWidget
//
//  A configurable two-slot widget: the user picks any two of three metrics
//  (training streak, competition countdown, live match status) via
//  SelectMetricsIntent. Each metric renders through a shared `MetricDisplay`. On
//  medium, a `.matches` slot with active matches becomes a tappable queue.
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
                currentStreak: 7, daysUntilCompetition: 15, competitionName: "Tournament",
                lastUpdated: Date(), trainedToday: true,
                matchesAwaitingYou: 1, matchesAwaitingOpponent: 2, activeMatches: nil
            ),
            primary: .streak, secondary: .competition
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
            date: now, widgetData: data,
            primary: configuration.primary, secondary: configuration.secondary
        )
        let calendar = Calendar.current
        // A live match queue needs to stay fresh; a streak/competition only rolls
        // over at midnight. (The app also force-reloads on every match change.)
        let hasActiveMatches = !(data.activeMatches?.isEmpty ?? true)
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let refresh = hasActiveMatches
            ? (calendar.date(byAdding: .minute, value: 30, to: now) ?? midnight)
            : midnight
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

// MARK: - Design Tokens (home screen only — lock screen uses system tint)

private enum WT {
    static let bgTop    = Color(red: 14/255.0,  green: 26/255.0,  blue: 46/255.0)
    static let bgBottom = Color(red: 26/255.0,  green: 47/255.0,  blue: 77/255.0)
    static let orange   = Color(red: 255/255.0, green: 138/255.0, blue: 61/255.0)
    static let blue     = Color(red: 91/255.0,  green: 163/255.0, blue: 208/255.0)
    static let match    = Color(red: 63/255.0,  green: 182/255.0, blue: 194/255.0)  // #3FB6C2 — 7.4:1 on the navy gradient
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
    let heroValue: String
    let heroUnit: String
    let caption: String
    let secondaryCaption: String?   // small third line, e.g. "1 WITH OPPONENT"
    let pillLabel: String
    let pillValue: String
    let eyebrow: String
    let isEmpty: Bool
    let emptyText: String
    let emptyCTA: String?           // accent CTA line under an empty state
}

extension WidgetMetric {
    func display(_ d: WidgetData) -> MetricDisplay {
        switch self {
        case .streak:
            return MetricDisplay(
                icon: "flame.fill", tint: WT.orange,
                heroValue: "\(d.currentStreak)", heroUnit: "days", caption: "training streak",
                secondaryCaption: nil, pillLabel: "Streak", pillValue: "\(d.currentStreak)",
                eyebrow: "STREAK", isEmpty: false, emptyText: "", emptyCTA: nil
            )

        case .competition:
            if let days = d.daysUntilCompetition, let comp = d.competitionName {
                return MetricDisplay(
                    icon: "flag.fill", tint: WT.blue,
                    heroValue: "\(days)", heroUnit: days == 1 ? "day" : "days", caption: "to \(comp)",
                    secondaryCaption: nil, pillLabel: comp, pillValue: "\(days)d",
                    eyebrow: "NEXT EVENT", isEmpty: false, emptyText: "", emptyCTA: nil
                )
            }
            return MetricDisplay(
                icon: "flag", tint: WT.blue, heroValue: "", heroUnit: "", caption: "",
                secondaryCaption: nil, pillLabel: "", pillValue: "",
                eyebrow: "NEXT EVENT", isEmpty: true, emptyText: "No upcoming event", emptyCTA: nil
            )

        case .matches:
            let you = d.matchesAwaitingYou ?? 0
            let opp = d.matchesAwaitingOpponent ?? 0
            let icon = "point.3.connected.trianglepath.dotted"
            if you > 0 {
                return MetricDisplay(
                    icon: icon, tint: WT.match,
                    heroValue: "\(you)", heroUnit: you == 1 ? "game" : "games", caption: "waiting for your turn",
                    secondaryCaption: opp > 0 ? "\(opp) WITH OPPONENT" : nil,
                    pillLabel: "Your turn", pillValue: "\(you)",
                    eyebrow: "MATCHES", isEmpty: false, emptyText: "", emptyCTA: nil
                )
            } else if opp > 0 {
                return MetricDisplay(
                    icon: icon, tint: WT.match,
                    heroValue: "\(opp)", heroUnit: opp == 1 ? "game" : "games", caption: "waiting for opponent",
                    secondaryCaption: nil, pillLabel: "Opponent", pillValue: "\(opp)",
                    eyebrow: "MATCHES", isEmpty: false, emptyText: "", emptyCTA: nil
                )
            }
            return MetricDisplay(
                icon: icon, tint: WT.match, heroValue: "", heroUnit: "", caption: "",
                secondaryCaption: nil, pillLabel: "", pillValue: "",
                eyebrow: "MATCHES", isEmpty: true, emptyText: "No games in play", emptyCTA: "Start a match →"
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2).minimumScaleFactor(0.6)
                if let cta = d.emptyCTA {
                    Text(cta).font(.system(size: 11, weight: .semibold)).foregroundStyle(WT.match).padding(.top, 3)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(d.heroValue)
                        .font(.system(size: valueSize, weight: .heavy)).monospacedDigit().tracking(-2.5)
                        .foregroundStyle(d.tint).lineLimit(1).minimumScaleFactor(0.45)
                    Text(d.heroUnit)
                        .font(.system(size: 12, weight: .bold)).tracking(0.4)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                Text(d.caption)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1).truncationMode(.tail).padding(.top, 2)
                if let s = d.secondaryCaption {
                    Text(s).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(0.6)
                        .foregroundStyle(Color.white.opacity(0.40)).padding(.top, 2)
                }
            }
        }
    }
}

private struct MetricPill: View {
    let d: MetricDisplay

    var body: some View {
        if d.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: d.icon).font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.55))
                Text(d.emptyText).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55)).lineLimit(1)
            }
        } else {
            HStack(spacing: 5) {
                Image(systemName: d.icon).font(.system(size: 10)).foregroundStyle(d.tint)
                Text(d.pillLabel).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85)).lineLimit(1).truncationMode(.tail).layoutPriority(1)
                Spacer(minLength: 4)
                Text(d.pillValue).font(.system(size: 11, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(d.tint).fixedSize()
            }
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)))
        }
    }
}

private struct MetricPanel: View {
    let d: MetricDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: d.icon).font(.system(size: 9)).foregroundStyle(d.tint)
                Text(d.eyebrow).font(.system(size: 9, weight: .heavy)).tracking(0.8).foregroundStyle(d.tint.opacity(0.85))
            }
            Spacer()
            if d.isEmpty {
                Text(d.emptyText).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.white.opacity(0.9)).lineLimit(2)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(d.heroValue).font(.system(size: 40, weight: .heavy)).monospacedDigit().tracking(-1.5)
                        .foregroundStyle(d.tint).lineLimit(1).minimumScaleFactor(0.6)
                    Text(d.heroUnit).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.white.opacity(0.6))
                }
                Text(d.caption).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(2).padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Match queue (medium only)

private struct MatchQueue: View {
    let data: WidgetData
    let maxRows: Int

    private var rows: [WidgetMatchRow] { data.activeMatches ?? [] }
    private var yourTurn: Int { rows.filter { $0.turn == "you" }.count }
    private var waiting: Int { rows.count - yourTurn }

    private var extraLabel: String {
        if yourTurn > maxRows { return "+\(yourTurn - maxRows) MORE" }
        return "\(waiting) WAITING"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("YOUR TURN · \(yourTurn)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced)).tracking(0.8).foregroundStyle(WT.match)
                Spacer(minLength: 4)
                Text(extraLabel).font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white.opacity(0.38))
            }
            ForEach(rows.prefix(maxRows)) { row in queueRow(row) }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func queueRow(_ row: WidgetMatchRow) -> some View {
        Link(destination: URL(string: "kubbcoach://matches/\(row.matchId)")!) {
            HStack(spacing: 6) {
                Circle().fill(row.isLag ? Color(red: 254/255, green: 204/255, blue: 2/255) : WT.match)
                    .frame(width: 7, height: 7)
                Text(row.opponentFirstName).font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: 4)
                if row.isLag {
                    Text("LAG").font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Color(red: 254/255, green: 204/255, blue: 2/255))
                } else {
                    Text(row.scoreLine).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 11).fill(WT.match.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(WT.match.opacity(0.28), lineWidth: 0.5)))
        }
    }
}

// MARK: - Home Screen slot layouts

private struct SlotSmallView: View {
    let entry: KubbCoachWidgetEntry
    private var primary: MetricDisplay { entry.primary.display(entry.widgetData) }
    private var secondary: MetricDisplay { entry.secondary.display(entry.widgetData) }
    private var duplicate: Bool { entry.primary == entry.secondary }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("KUBB COACH").font(.system(size: 9, weight: .heavy)).tracking(1)
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Image(systemName: primary.icon).font(.system(size: 14)).foregroundStyle(primary.tint)
            }
            Spacer()
            MetricHero(d: primary, valueSize: 56)
            Spacer()
            if !duplicate { MetricPill(d: secondary) }
        }
        .padding(14)
        .containerBackground(WT.gradient, for: .widget)
    }
}

private struct SlotMediumView: View {
    let entry: KubbCoachWidgetEntry
    private var primary: MetricDisplay { entry.primary.display(entry.widgetData) }
    private var secondary: MetricDisplay { entry.secondary.display(entry.widgetData) }
    private var duplicate: Bool { entry.primary == entry.secondary }
    private var hasQueue: Bool { !(entry.widgetData.activeMatches?.isEmpty ?? true) }

    var body: some View {
        HStack(spacing: 0) {
            if entry.primary == .matches && hasQueue {
                // Matches is the hero → wide queue on the left, other metric right.
                MatchQueue(data: entry.widgetData, maxRows: 3).frame(width: 200)
                divider
                MetricPanel(d: secondary).padding(.leading, 16)
            } else {
                heroColumn.frame(width: 118)
                divider
                if entry.secondary == .matches && hasQueue {
                    MatchQueue(data: entry.widgetData, maxRows: 2).padding(.leading, 16)
                } else if !duplicate {
                    MetricPanel(d: secondary).padding(.leading, 16)
                } else {
                    Spacer()
                }
            }
        }
        .padding(14)
        .containerBackground(WT.gradient, for: .widget)
    }

    private var heroColumn: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 5) {
                Image(systemName: primary.icon).font(.system(size: 11)).foregroundStyle(primary.tint)
                Text("KUBB COACH").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(Color.white.opacity(0.55))
            }
            Spacer()
            MetricHero(d: primary, valueSize: 58)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.5).padding(.vertical, 6)
    }
}

private struct SlotLockView: View {
    let entry: KubbCoachWidgetEntry
    private var primary: MetricDisplay { entry.primary.display(entry.widgetData) }
    private var secondary: MetricDisplay { entry.secondary.display(entry.widgetData) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if primary.isEmpty {
                    Text(primary.emptyText).font(.system(size: 14, weight: .bold)).lineLimit(2)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(primary.heroValue).font(.system(size: 30, weight: .bold)).monospacedDigit().tracking(-1.5)
                        Text(primary.heroUnit.uppercased()).font(.system(size: 11, weight: .semibold)).opacity(0.72).tracking(0.6)
                    }
                    Text(primary.caption).font(.system(size: 11, weight: .semibold)).opacity(0.72)
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
                    Text(secondary.eyebrow).font(.system(size: 8, weight: .bold)).opacity(0.72).tracking(0.8)
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

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:       SlotSmallView(entry: entry)
            case .systemMedium:      SlotMediumView(entry: entry)
            case .accessoryRectangular: SlotLockView(entry: entry)
            default:                 SlotSmallView(entry: entry)
            }
        }
        .widgetURL(deepLink)
    }

    /// If either slot shows matches, tapping opens the Virtual Matches tab; else
    /// the log-training flow. (Medium queue rows deep-link to their own match.)
    private var deepLink: URL {
        if entry.primary == .matches || entry.secondary == .matches {
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
    trained: Bool = true, you: Int? = nil, opp: Int? = nil, queue: [WidgetMatchRow]? = nil
) -> WidgetData {
    WidgetData(
        currentStreak: streak, daysUntilCompetition: days, competitionName: comp,
        lastUpdated: Date(), trainedToday: trained,
        matchesAwaitingYou: you, matchesAwaitingOpponent: opp, activeMatches: queue
    )
}

private let sampleQueue = [
    WidgetMatchRow(matchId: "1", opponentFirstName: "Erik", scoreLine: "1–1", isLag: false, turn: "you"),
    WidgetMatchRow(matchId: "2", opponentFirstName: "Kubb Coach", scoreLine: "0–0", isLag: true, turn: "you"),
    WidgetMatchRow(matchId: "3", opponentFirstName: "Anna", scoreLine: "0–1", isLag: false, turn: "opponent"),
]

#Preview("Small — Streak + Competition", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(streak: 10, days: 17, comp: "Beloit Open"),
                         primary: .streak, secondary: .competition)
}

#Preview("Small — Matches (both counts)", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(you: 2, opp: 1),
                         primary: .matches, secondary: .streak)
}

#Preview("Small — Matches (none)", as: .systemSmall) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(you: 0, opp: 0),
                         primary: .matches, secondary: .streak)
}

#Preview("Medium — Streak + Match queue", as: .systemMedium) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(streak: 33, you: 2, opp: 1, queue: sampleQueue),
                         primary: .streak, secondary: .matches)
}

#Preview("Medium — Match queue hero", as: .systemMedium) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(you: 2, opp: 1, queue: sampleQueue),
                         primary: .matches, secondary: .streak)
}

#Preview("Lock — Streak + Competition", as: .accessoryRectangular) {
    KubbCoachWidget()
} timeline: {
    KubbCoachWidgetEntry(date: Date(), widgetData: sampleData(streak: 22, days: 8, comp: "Regional Cup"),
                         primary: .streak, secondary: .competition)
}
