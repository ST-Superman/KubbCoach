// LeaderboardModels.swift
// Value types for the global leaderboard feature. No SwiftData — pure value types.

import SwiftUI

// MARK: - LeaderboardMode

enum LeaderboardMode: String, CaseIterable, Hashable {
    case eightMeter = "8m"
    case fourMeter  = "4m"
    case inkasting  = "Ink"

    var color: Color {
        switch self {
        case .eightMeter: return Color.Kubb.swedishBlue
        case .fourMeter:  return Color.Kubb.phase4m
        case .inkasting:  return Color.Kubb.forestGreen
        }
    }

    var metrics: [LeaderboardMetric] {
        switch self {
        case .eightMeter: return [.accuracy, .longestStreak, .throwsLogged]
        case .fourMeter:  return [.avgScoreVsPar, .longestStreak, .throwsLogged]
        case .inkasting:  return [.avgClusterRadius, .longestStreak, .throwsLogged]
        }
    }

    var defaultMetric: LeaderboardMetric { metrics[0] }

    var trainingPhase: TrainingPhase {
        switch self {
        case .eightMeter: return .eightMeters
        case .fourMeter:  return .fourMetersBlasting
        case .inkasting:  return .inkastingDrilling
        }
    }
}

// MARK: - LeaderboardMetric

enum LeaderboardMetric: String, Hashable {
    case accuracy         = "Accuracy"
    case longestStreak    = "Longest Streak"
    case throwsLogged     = "Throws Logged"
    case avgScoreVsPar    = "Avg Score vs Par"
    case avgClusterRadius = "Avg Cluster"

    var displayName: String { rawValue }

    // true = lower value ranks higher (e.g. −4 beats −2 for score-vs-par)
    var sortAscending: Bool {
        switch self {
        case .avgScoreVsPar, .avgClusterRadius: return true
        default: return false
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .accuracy:
            return String(format: "%.1f%%", value)
        case .longestStreak:
            return "\(Int(value))"
        case .throwsLogged:
            return "\(Int(value))"
        case .avgScoreVsPar:
            return value < 0
                ? String(format: "%.1f", value)
                : "+\(String(format: "%.1f", value))"
        case .avgClusterRadius:
            return String(format: "%.2fm", value)
        }
    }
}

// MARK: - RecencyWindow

enum RecencyWindow: String, CaseIterable, Hashable {
    case thirty = "30d"
    case ninety = "90d"

    var days: Int {
        switch self {
        case .thirty: return 30
        case .ninety: return 90
        }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

// MARK: - LeaderboardEntry

struct LeaderboardEntry: Identifiable, Hashable {
    let id: UUID
    let rank: Int
    let displayName: String
    let value: Double
    let isCurrentUser: Bool

    var rankLabel: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)) } ?? ""
        let last  = parts.dropFirst().first.map { String($0.prefix(1)) } ?? ""
        return (first + last).uppercased()
    }

    var isMedal: Bool { rank <= 3 }
}
