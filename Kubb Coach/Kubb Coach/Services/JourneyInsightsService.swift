//
//  JourneyInsightsService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import Foundation
import SwiftData

/// Provides insights and metrics for the Journey tab
struct JourneyInsightsService {

    // MARK: - Training Frequency

    /// Calculates training frequency in days per week (rolling 4-week average)
    static func trainingFrequency(from sessions: [SessionDisplayItem]) -> Double {
        guard !sessions.isEmpty else { return 0.0 }

        let calendar = Calendar.current
        let today = Date()
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: today)!

        // Get sessions from last 4 weeks
        let recentSessions = sessions.filter { $0.createdAt >= fourWeeksAgo }

        // Count unique training days
        let uniqueDays = Set(recentSessions.map { calendar.startOfDay(for: $0.createdAt) })

        // Calculate days per week (28 days = 4 weeks)
        return Double(uniqueDays.count) / 4.0
    }

    /// Returns a descriptive text for training frequency
    static func trainingFrequencyText(frequency: Double) -> String {
        return String(format: "%.1f days/week", frequency)
    }

    /// Returns a trend indicator (improving, stable, declining)
    static func trainingFrequencyTrend(from sessions: [SessionDisplayItem]) -> FrequencyTrend {
        guard sessions.count >= 8 else { return .stable }

        let calendar = Calendar.current
        let today = Date()

        // Last 4 weeks
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: today)!
        let recentSessions = sessions.filter { $0.createdAt >= fourWeeksAgo }
        let recentDays = Set(recentSessions.map { calendar.startOfDay(for: $0.createdAt) }).count

        // Previous 4 weeks (weeks 5-8)
        let eightWeeksAgo = calendar.date(byAdding: .day, value: -56, to: today)!
        let previousSessions = sessions.filter { $0.createdAt >= eightWeeksAgo && $0.createdAt < fourWeeksAgo }
        let previousDays = Set(previousSessions.map { calendar.startOfDay(for: $0.createdAt) }).count

        // Compare
        if recentDays > previousDays + 1 {
            return .improving
        } else if recentDays < previousDays - 1 {
            return .declining
        } else {
            return .stable
        }
    }

    // MARK: - This Week Progress

    /// Calculates how many days this week the user has trained
    static func thisWeekTrainingDays(from sessions: [SessionDisplayItem]) -> Int {
        let calendar = Calendar.current
        let today = Date()

        // Get start of current week (Sunday)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return 0
        }

        let thisWeekSessions = sessions.filter { $0.createdAt >= weekStart }
        let uniqueDays = Set(thisWeekSessions.map { calendar.startOfDay(for: $0.createdAt) })

        return uniqueDays.count
    }

    // MARK: - Phase Reminders

    /// Returns days since last session for each phase
    static func daysSinceLastSession(for phase: TrainingPhase, from sessions: [SessionDisplayItem]) -> Int? {
        let phaseSessions = sessions.filter { $0.phase == phase }
        guard let lastSession = phaseSessions.first else { return nil }

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastSession.createdAt, to: Date()).day
        return days
    }

    /// Returns phases that haven't been trained recently (5+ days)
    static func phasesThatNeedAttention(from sessions: [SessionDisplayItem]) -> [PhaseReminder] {
        var reminders: [PhaseReminder] = []

        for phase in TrainingPhase.allCases {
            if let days = daysSinceLastSession(for: phase, from: sessions), days >= 5 {
                reminders.append(PhaseReminder(phase: phase, daysSince: days))
            }
        }

        // Sort by days (most overdue first)
        return reminders.sorted { $0.daysSince > $1.daysSince }
    }

    // MARK: - Next Session Suggestion

    /// Suggests which phase to train next based on recency and balance
    static func suggestNextSession(from sessions: [SessionDisplayItem]) -> SessionSuggestion {
        guard !sessions.isEmpty else {
            // Default to 8M for new users
            return SessionSuggestion(
                phase: .eightMeters,
                reason: "Start with accuracy fundamentals"
            )
        }

        // Calculate days since last session for each phase
        var phaseDays: [(TrainingPhase, Int)] = []
        for phase in TrainingPhase.allCases {
            if let days = daysSinceLastSession(for: phase, from: sessions) {
                phaseDays.append((phase, days))
            } else {
                // Never trained this phase - high priority
                return SessionSuggestion(
                    phase: phase,
                    reason: "Time to try \(phase.displayName)"
                )
            }
        }

        // Sort by days (most overdue first)
        phaseDays.sort { $0.1 > $1.1 }

        guard let (mostOverduePhase, days) = phaseDays.first else {
            return SessionSuggestion(phase: .eightMeters, reason: "Keep up your training")
        }

        // Generate reason based on days
        let reason: String
        if days >= 7 {
            reason = "It's been \(days) days since your last \(mostOverduePhase.displayName) session"
        } else if days >= 5 {
            reason = "Balance your training with \(mostOverduePhase.displayName)"
        } else {
            // All phases are recent, suggest based on performance
            reason = "Continue improving your \(mostOverduePhase.displayName)"
        }

        return SessionSuggestion(phase: mostOverduePhase, reason: reason)
    }

    // MARK: - Personal Records

    /// Fetches all personal records by finding the best sessions for each phase
    @MainActor
    static func getPersonalRecords(context: ModelContext) -> PersonalRecordsSummary {
        var records: [PhaseRecord] = []

        for phase in TrainingPhase.allCases {
            // Fetch aggregate to get session IDs
            if let aggregate = StatisticsAggregator.getAggregate(
                for: phase,
                timeRange: .allTime,
                context: context
            ) {
                switch phase {
                case .eightMeters:
                    if let sessionId = aggregate.bestEightMeterAccuracySessionId,
                       let session = try? context.fetch(FetchDescriptor<TrainingSession>(
                           predicate: #Predicate { $0.id == sessionId }
                       )).first {
                        let record = PhaseRecord(
                            phase: phase,
                            value: session.accuracy,
                            formattedValue: String(format: "%.1f%%", session.accuracy),
                            achievedDate: session.createdAt
                        )
                        records.append(record)
                    }

                case .fourMetersBlasting:
                    if let sessionId = aggregate.bestBlastingScoreSessionId,
                       let session = try? context.fetch(FetchDescriptor<TrainingSession>(
                           predicate: #Predicate { $0.id == sessionId }
                       )).first,
                       let score = aggregate.bestBlastingScore {
                        let record = PhaseRecord(
                            phase: phase,
                            value: Double(score),
                            formattedValue: String(format: "%+d", score),
                            achievedDate: session.createdAt
                        )
                        records.append(record)
                    }

                case .inkastingDrilling:
                    if let sessionId = aggregate.bestClusterAreaSessionId,
                       let session = try? context.fetch(FetchDescriptor<TrainingSession>(
                           predicate: #Predicate { $0.id == sessionId }
                       )).first,
                       let area = aggregate.bestClusterArea {
                        // Format area using InkastingSettings
                        let descriptor = FetchDescriptor<InkastingSettings>()
                        let settings = (try? context.fetch(descriptor).first) ?? InkastingSettings()
                        let formatted = settings.formatArea(area)

                        let record = PhaseRecord(
                            phase: phase,
                            value: area,
                            formattedValue: formatted,
                            achievedDate: session.createdAt
                        )
                        records.append(record)
                    }

                case .gameTracker:
                    break  // Game sessions don't have personal bests in training aggregates
                }
            }
        }

        return PersonalRecordsSummary(records: records)
    }
}

// MARK: - Supporting Types

enum FrequencyTrend {
    case improving
    case stable
    case declining

    var color: String {
        switch self {
        case .improving: return "green"
        case .stable: return "primary"
        case .declining: return "red"
        }
    }

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }
}

struct PhaseReminder: Identifiable {
    let id = UUID()
    let phase: TrainingPhase
    let daysSince: Int

    var message: String {
        "You haven't trained \(phase.displayName) in \(daysSince) days"
    }
}

struct SessionSuggestion {
    let phase: TrainingPhase
    let reason: String
}

struct PhaseRecord: Identifiable {
    let id = UUID()
    let phase: TrainingPhase
    let value: Double
    let formattedValue: String
    let achievedDate: Date

    var daysSinceAchieved: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: achievedDate, to: Date()).day ?? 0
        return days
    }

    var relativeTimeText: String {
        let days = daysSinceAchieved
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: achievedDate)
        }
    }
}

struct PersonalRecordsSummary {
    let records: [PhaseRecord]

    var isEmpty: Bool {
        records.isEmpty
    }
}
