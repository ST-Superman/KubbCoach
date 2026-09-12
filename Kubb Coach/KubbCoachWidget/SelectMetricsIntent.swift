//
//  SelectMetricsIntent.swift
//  KubbCoachWidget
//
//  Widget configuration: the user picks which two metrics the widget shows, in
//  two slots (primary = hero, secondary = pill/panel). Defaults reproduce the
//  original hardcoded layout (streak + competition) so already-placed widgets
//  keep their look after the StaticConfiguration → AppIntentConfiguration switch.
//

import AppIntents
import WidgetKit

/// A stat the widget can display in one of its two slots.
enum WidgetMetric: String, AppEnum {
    case streak
    case competition
    case matches

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Metric" }

    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] {
        [
            .streak: "Training Streak",
            .competition: "Competition Countdown",
            .matches: "Live Match Status",
        ]
    }
}

/// Configuration for the Kubb Coach widget — two metric slots.
struct SelectMetricsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Metrics" }
    static var description: IntentDescription {
        IntentDescription("Pick which two stats the widget shows.")
    }

    @Parameter(title: "Top / Left", default: .streak)
    var primary: WidgetMetric

    @Parameter(title: "Bottom / Right", default: .competition)
    var secondary: WidgetMetric
}
