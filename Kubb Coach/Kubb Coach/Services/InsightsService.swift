import Foundation
import SwiftData

struct InsightsService {

    static func generateInsights(from sessions: [TrainingSession]) -> [String] {
        var insights: [String] = []

        let completedSessions = sessions.filter { $0.isComplete }
        guard !completedSessions.isEmpty else { return [] }

        if let bestDay = bestDayOfWeek(from: completedSessions) {
            insights.append(bestDay)
        }

        if let trend = improvementTrend(from: completedSessions) {
            insights.append(trend)
        }

        if let roundComparison = firstVsLastRoundPerformance(from: completedSessions) {
            insights.append(roundComparison)
        }

        if let kingInsight = kingThrowAccuracyInsight(from: completedSessions) {
            insights.append(kingInsight)
        }

        if let monthComparison = monthOverMonthComparison(from: completedSessions) {
            insights.append(monthComparison)
        }

        if let consistencyInsight = consistencyInsight(from: completedSessions) {
            insights.append(consistencyInsight)
        }

        return insights
    }

    private static func bestDayOfWeek(from sessions: [TrainingSession]) -> String? {
        guard sessions.count >= 3 else { return nil }

        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]
        for session in sessions {
            let weekday = calendar.component(.weekday, from: session.createdAt)
            dayCounts[weekday, default: 0] += 1
        }

        guard let bestDay = dayCounts.max(by: { $0.value < $1.value }),
              bestDay.value >= 2 else { return nil }

        let formatter = DateFormatter()
        let dayName = formatter.weekdaySymbols[bestDay.key - 1]
        return "Your best day for training is \(dayName)"
    }

    private static func improvementTrend(from sessions: [TrainingSession]) -> String? {
        let eightMeterSessions = sessions
            .filter { $0.safePhase == .eightMeters }
            .sorted { $0.createdAt < $1.createdAt }

        guard eightMeterSessions.count >= 6 else { return nil }

        let recentCount = min(5, eightMeterSessions.count / 2)
        let recentSessions = Array(eightMeterSessions.suffix(recentCount))
        let olderSessions = Array(eightMeterSessions.prefix(recentCount))

        let recentAvg = recentSessions.reduce(0.0) { $0 + $1.accuracy } / Double(recentSessions.count)
        let olderAvg = olderSessions.reduce(0.0) { $0 + $1.accuracy } / Double(olderSessions.count)

        let diff = recentAvg - olderAvg
        guard abs(diff) >= 3.0 else { return nil }

        if diff > 0 {
            return "You've improved \(String(format: "%.0f", diff))% compared to your earlier sessions"
        } else {
            return "Your recent accuracy is \(String(format: "%.0f", abs(diff)))% lower than your earlier sessions — time to refocus!"
        }
    }

    private static func firstVsLastRoundPerformance(from sessions: [TrainingSession]) -> String? {
        let eightMeterSessions = sessions.filter { $0.safePhase == .eightMeters && $0.rounds.count >= 3 }
        guard eightMeterSessions.count >= 3 else { return nil }

        var firstRoundAccuracies: [Double] = []
        var lastRoundAccuracies: [Double] = []

        for session in eightMeterSessions {
            let sortedRounds = session.rounds.sorted { $0.roundNumber < $1.roundNumber }
            if let first = sortedRounds.first, !first.throwRecords.isEmpty {
                firstRoundAccuracies.append(first.accuracy)
            }
            if let last = sortedRounds.last, !last.throwRecords.isEmpty {
                lastRoundAccuracies.append(last.accuracy)
            }
        }

        guard !firstRoundAccuracies.isEmpty, !lastRoundAccuracies.isEmpty else { return nil }

        let firstAvg = firstRoundAccuracies.reduce(0.0, +) / Double(firstRoundAccuracies.count)
        let lastAvg = lastRoundAccuracies.reduce(0.0, +) / Double(lastRoundAccuracies.count)

        let diff = firstAvg - lastAvg
        guard abs(diff) >= 5.0 else { return nil }

        if diff > 0 {
            return "Your first round is usually your best — try warming up before starting"
        } else {
            return "You tend to get stronger as sessions go on — great endurance!"
        }
    }

    private static func kingThrowAccuracyInsight(from sessions: [TrainingSession]) -> String? {
        let eightMeterSessions = sessions.filter { $0.safePhase == .eightMeters }

        let allKingThrows = eightMeterSessions.flatMap { $0.kingThrows }
        guard allKingThrows.count >= 5 else { return nil }

        let kingHits = allKingThrows.filter { $0.result == .hit }.count
        let kingAccuracy = Double(kingHits) / Double(allKingThrows.count) * 100

        let allBaselineThrows = eightMeterSessions.flatMap { session in
            session.rounds.flatMap { round in
                round.throwRecords.filter { $0.targetType == .baselineKubb }
            }
        }
        guard !allBaselineThrows.isEmpty else { return nil }

        let baselineHits = allBaselineThrows.filter { $0.result == .hit }.count
        let baselineAccuracy = Double(baselineHits) / Double(allBaselineThrows.count) * 100

        let diff = baselineAccuracy - kingAccuracy
        guard abs(diff) >= 5.0 else { return nil }

        return "You hit \(String(format: "%.0f", baselineAccuracy))% on baseline kubbs but only \(String(format: "%.0f", kingAccuracy))% on king throws"
    }

    private static func monthOverMonthComparison(from sessions: [TrainingSession]) -> String? {
        let calendar = Calendar.current
        let now = Date()

        guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now),
              let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now) else { return nil }

        let thisMonthSessions = sessions.filter { $0.safePhase == .eightMeters && $0.createdAt >= oneMonthAgo }
        let lastMonthSessions = sessions.filter { $0.safePhase == .eightMeters && $0.createdAt >= twoMonthsAgo && $0.createdAt < oneMonthAgo }

        guard thisMonthSessions.count >= 3, lastMonthSessions.count >= 3 else { return nil }

        let thisMonthAvg = thisMonthSessions.reduce(0.0) { $0 + $1.accuracy } / Double(thisMonthSessions.count)
        let lastMonthAvg = lastMonthSessions.reduce(0.0) { $0 + $1.accuracy } / Double(lastMonthSessions.count)

        let diff = thisMonthAvg - lastMonthAvg
        guard abs(diff) >= 2.0 else { return nil }

        if diff > 0 {
            return "You've improved \(String(format: "%.0f", diff))% this month vs last month"
        } else {
            return "Your accuracy dipped \(String(format: "%.0f", abs(diff)))% this month vs last month"
        }
    }

    private static func consistencyInsight(from sessions: [TrainingSession]) -> String? {
        let eightMeterSessions = sessions.filter { $0.safePhase == .eightMeters }
        guard eightMeterSessions.count >= 5 else { return nil }

        let recentSessions = Array(eightMeterSessions.sorted { $0.createdAt > $1.createdAt }.prefix(10))
        let accuracies = recentSessions.map { $0.accuracy }

        let mean = accuracies.reduce(0.0, +) / Double(accuracies.count)
        let variance = accuracies.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(accuracies.count)
        let stdDev = sqrt(variance)

        if stdDev < 5.0 {
            return "Your accuracy is very consistent — you're a reliable thrower!"
        } else if stdDev > 15.0 {
            return "Your accuracy varies a lot between sessions — focus on consistency"
        }

        return nil
    }
}
