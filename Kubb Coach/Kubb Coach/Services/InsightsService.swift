import Foundation
import SwiftData

struct Insight: Identifiable, Hashable {
    let id = UUID()
    let message: String
    let phase: TrainingPhase?  // nil for global insights

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Insight, rhs: Insight) -> Bool {
        lhs.id == rhs.id
    }
}

struct InsightsService {

    static func generateInsights(from sessions: [TrainingSession], context: ModelContext) -> [Insight] {
        var insights: [Insight] = []

        let completedSessions = sessions.filter { $0.isComplete }
        guard !completedSessions.isEmpty else { return [] }

        if let bestDay = bestDayOfWeek(from: completedSessions) {
            insights.append(Insight(message: bestDay, phase: nil))  // Global insight
        }

        if let trend = improvementTrend(from: completedSessions) {
            insights.append(Insight(message: trend, phase: .eightMeters))
        }

        if let roundComparison = firstVsLastRoundPerformance(from: completedSessions) {
            insights.append(Insight(message: roundComparison, phase: .eightMeters))
        }

        if let monthComparison = monthOverMonthComparison(from: completedSessions) {
            insights.append(Insight(message: monthComparison, phase: .eightMeters))
        }

        if let consistencyInsight = consistencyInsight(from: completedSessions) {
            insights.append(Insight(message: consistencyInsight, phase: .eightMeters))
        }

        // Blasting insights
        if let blastingTrend = blastingImprovementTrend(from: completedSessions) {
            insights.append(Insight(message: blastingTrend, phase: .fourMetersBlasting))
        }

        if let blastingConsistency = blastingConsistencyInsight(from: completedSessions) {
            insights.append(Insight(message: blastingConsistency, phase: .fourMetersBlasting))
        }

        // Inkasting insights
        if let inkastingTrend = inkastingImprovementTrend(from: completedSessions, context: context) {
            insights.append(Insight(message: inkastingTrend, phase: .inkastingDrilling))
        }

        if let inkastingConsistency = inkastingConsistencyInsight(from: completedSessions, context: context) {
            insights.append(Insight(message: inkastingConsistency, phase: .inkastingDrilling))
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
        return "You train most often on \(dayName)s — keep up the good work!"
    }

    private static func improvementTrend(from sessions: [TrainingSession]) -> String? {
        let eightMeterSessions = sessions
            .filter { $0.safePhase == .eightMeters }
            .sorted { $0.createdAt < $1.createdAt }

        guard eightMeterSessions.count >= 6 else { return nil }

        // Compare last 5 sessions to all-time average
        let recentCount = min(5, eightMeterSessions.count)
        let recentSessions = Array(eightMeterSessions.suffix(recentCount))

        let recentAvg = recentSessions.reduce(0.0) { $0 + $1.accuracy } / Double(recentSessions.count)
        let allTimeAvg = eightMeterSessions.reduce(0.0) { $0 + $1.accuracy } / Double(eightMeterSessions.count)

        let diff = recentAvg - allTimeAvg
        guard abs(diff) >= 3.0 else { return nil }

        if diff > 0 {
            return "You're \(String(format: "%.0f", diff))% above your all-time average — keep it up!"
        } else {
            return "You're \(String(format: "%.0f", abs(diff)))% below your all-time average — time to refocus!"
        }
    }

    private static func firstVsLastRoundPerformance(from sessions: [TrainingSession]) -> String? {
        let eightMeterSessions = sessions.filter { $0.safePhase == .eightMeters && $0.rounds.count >= 4 }
        guard eightMeterSessions.count >= 3 else { return nil }

        var firstHalfAccuracies: [Double] = []
        var lastHalfAccuracies: [Double] = []

        for session in eightMeterSessions {
            let sortedRounds = session.rounds.sorted { $0.roundNumber < $1.roundNumber }
            let roundCount = sortedRounds.count

            // For 10+ round sessions, compare first 5 to last 5
            // For shorter sessions, compare first half to second half
            let compareCount = roundCount >= 10 ? 5 : roundCount / 2

            guard compareCount >= 2 else { continue }

            let firstRounds = Array(sortedRounds.prefix(compareCount))
            let lastRounds = Array(sortedRounds.suffix(compareCount))

            let firstAvg = firstRounds.reduce(0.0) { $0 + $1.accuracy } / Double(firstRounds.count)
            let lastAvg = lastRounds.reduce(0.0) { $0 + $1.accuracy } / Double(lastRounds.count)

            firstHalfAccuracies.append(firstAvg)
            lastHalfAccuracies.append(lastAvg)
        }

        guard !firstHalfAccuracies.isEmpty, !lastHalfAccuracies.isEmpty else { return nil }

        let firstAvg = firstHalfAccuracies.reduce(0.0, +) / Double(firstHalfAccuracies.count)
        let lastAvg = lastHalfAccuracies.reduce(0.0, +) / Double(lastHalfAccuracies.count)

        let diff = firstAvg - lastAvg
        guard abs(diff) >= 5.0 else { return nil }

        if diff > 0 {
            // Accuracy decreases - normal fatigue
            return "Your accuracy drops \(String(format: "%.0f", diff))% in the later rounds — stay focused and keep building your endurance!"
        } else {
            // Accuracy increases - warming up / endurance
            return "You finish strong — your accuracy improves \(String(format: "%.0f", abs(diff)))% in later rounds! Consider warming up before you start training"
        }
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

    // MARK: - Blasting Insights

    private static func blastingImprovementTrend(from sessions: [TrainingSession]) -> String? {
        let blastingSessions = sessions
            .filter { $0.safePhase == .fourMetersBlasting }
            .sorted { $0.createdAt < $1.createdAt }

        guard blastingSessions.count >= 6 else { return nil }

        // Compare last 5 sessions to all-time average (lower scores are better)
        let recentCount = min(5, blastingSessions.count)
        let recentSessions = Array(blastingSessions.suffix(recentCount))

        let recentScores = recentSessions.compactMap { Double($0.totalSessionScore ?? 0) }
        let allScores = blastingSessions.compactMap { Double($0.totalSessionScore ?? 0) }

        guard !recentScores.isEmpty, !allScores.isEmpty else { return nil }

        let recentAvg = recentScores.reduce(0.0, +) / Double(recentScores.count)
        let allTimeAvg = allScores.reduce(0.0, +) / Double(allScores.count)

        let diff = recentAvg - allTimeAvg
        guard abs(diff) >= 2.0 else { return nil }

        if diff < 0 {
            // Recent scores are lower (better)
            return "Your blasting scores are improving — \(String(format: "%.0f", abs(diff))) strokes better than your average!"
        } else {
            // Recent scores are higher (worse)
            return "Your blasting scores are up \(String(format: "%.0f", diff)) strokes — tighten up that form!"
        }
    }

    private static func blastingConsistencyInsight(from sessions: [TrainingSession]) -> String? {
        let blastingSessions = sessions.filter { $0.safePhase == .fourMetersBlasting }
        guard blastingSessions.count >= 5 else { return nil }

        let recentSessions = Array(blastingSessions.sorted { $0.createdAt > $1.createdAt }.prefix(10))
        let scores = recentSessions.compactMap { $0.totalSessionScore != nil ? Double($0.totalSessionScore!) : nil }

        guard scores.count >= 5 else { return nil }

        let mean = scores.reduce(0.0, +) / Double(scores.count)
        let variance = scores.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(scores.count)
        let stdDev = sqrt(variance)

        if stdDev < 3.0 {
            return "Your blasting scores are rock solid — very consistent!"
        } else if stdDev > 8.0 {
            return "Your blasting scores vary quite a bit — work on consistency"
        }

        return nil
    }

    // MARK: - Inkasting Insights

    private static func inkastingImprovementTrend(from sessions: [TrainingSession], context: ModelContext) -> String? {
        let inkastingSessions = sessions
            .filter { $0.safePhase == .inkastingDrilling }
            .sorted { $0.createdAt < $1.createdAt }

        guard inkastingSessions.count >= 6 else { return nil }

        // Compare last 5 sessions to all-time average (lower area is better)
        let recentCount = min(5, inkastingSessions.count)
        let recentSessions = Array(inkastingSessions.suffix(recentCount))

        // Get average cluster areas for each session
        let recentAreas = recentSessions.compactMap { $0.averageClusterArea(context: context) }
        let allAreas = inkastingSessions.compactMap { $0.averageClusterArea(context: context) }

        guard !recentAreas.isEmpty, !allAreas.isEmpty else { return nil }

        let recentAvg = recentAreas.reduce(0.0, +) / Double(recentAreas.count)
        let allTimeAvg = allAreas.reduce(0.0, +) / Double(allAreas.count)

        // Calculate percentage difference (lower is better, so we need to invert the comparison)
        let percentDiff = ((recentAvg - allTimeAvg) / allTimeAvg) * 100
        guard abs(percentDiff) >= 10.0 else { return nil }

        if percentDiff < 0 {
            // Recent areas are smaller (better)
            return "Your inkasting precision is improving — cluster area \(String(format: "%.0f", abs(percentDiff)))% tighter than your average!"
        } else {
            // Recent areas are larger (worse)
            return "Your inkasting clusters are \(String(format: "%.0f", percentDiff))% larger than average — focus on tighter grouping!"
        }
    }

    private static func inkastingConsistencyInsight(from sessions: [TrainingSession], context: ModelContext) -> String? {
        let inkastingSessions = sessions.filter { $0.safePhase == .inkastingDrilling }
        guard inkastingSessions.count >= 5 else { return nil }

        let recentSessions = Array(inkastingSessions.sorted { $0.createdAt > $1.createdAt }.prefix(10))
        let areas = recentSessions.compactMap { $0.averageClusterArea(context: context) }

        guard areas.count >= 5 else { return nil }

        let mean = areas.reduce(0.0, +) / Double(areas.count)
        let variance = areas.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(areas.count)
        let stdDev = sqrt(variance)

        // Calculate coefficient of variation (stdDev / mean) to get relative consistency
        let coefficientOfVariation = (stdDev / mean) * 100

        if coefficientOfVariation < 15.0 {
            return "Your inkasting precision is very consistent — reliable grouping!"
        } else if coefficientOfVariation > 40.0 {
            return "Your inkasting clusters vary quite a bit — work on consistency"
        }

        return nil
    }
}
