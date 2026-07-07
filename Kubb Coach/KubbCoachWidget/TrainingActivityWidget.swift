import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Color tokens (mirrors KubbColorTokens, inlined for widget extension)

private enum AT {
    static let blue   = Color(red: 0/255,   green: 106/255, blue: 167/255) // swedishBlue
    static let green  = Color(red: 45/255,  green: 138/255, blue: 94/255)  // hitBright dark
    static let yellow = Color(red: 230/255, green: 155/255, blue: 40/255)  // mid accuracy
    static let red    = Color(red: 197/255, green: 48/255,  blue: 48/255)  // miss
    static let dim    = Color.white.opacity(0.55)

    static func accuracyColor(_ pct: Double) -> Color {
        if pct >= 80 { return green }
        if pct >= 50 { return yellow }
        return red
    }
}

// MARK: - Progress pips

private struct RoundPips: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...total, id: \.self) { n in
                Capsule()
                    .fill(n < current ? AT.blue : (n == current ? Color.white : Color.white.opacity(0.18)))
                    .frame(maxWidth: .infinity)
                    .frame(height: n == current ? 4 : 3)
            }
        }
    }
}

// MARK: - Lock Screen / Notification Center view

private struct TrainingLockScreenView: View {
    let context: ActivityViewContext<TrainingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(context.attributes.phaseLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(AT.dim)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Round")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AT.dim)
                    Text("\(context.state.currentRound)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .monospacedDigit()
                    Text("/ \(context.attributes.totalRounds)")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(AT.dim)
                        .monospacedDigit()
                }
                Spacer()
                if context.state.isComplete {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AT.green)
                } else {
                    Text(String(format: "%.0f%%", context.state.accuracy))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(AT.accuracyColor(context.state.accuracy))
                        .monospacedDigit()
                }
            }

            RoundPips(current: context.state.currentRound, total: context.attributes.totalRounds)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Dynamic Island expanded view

private struct IslandExpandedView: View {
    let context: ActivityViewContext<TrainingActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.phaseLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AT.dim)
                    .lineLimit(1)
                Text("Round \(context.state.currentRound) / \(context.attributes.totalRounds)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            Spacer()
            if context.state.isComplete {
                Text("Done")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AT.green)
            } else {
                Text(String(format: "%.0f%%", context.state.accuracy))
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(AT.accuracyColor(context.state.accuracy))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Widget

struct TrainingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            TrainingLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    IslandExpandedView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RoundPips(
                        current: context.state.currentRound,
                        total: context.attributes.totalRounds
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "figure.archery")
                    .font(.system(size: 13))
                    .foregroundStyle(AT.blue)
            } compactTrailing: {
                Text("R\(context.state.currentRound)/\(context.attributes.totalRounds)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .monospacedDigit()
            } minimal: {
                Text("\(context.state.currentRound)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .monospacedDigit()
            }
        }
    }
}
