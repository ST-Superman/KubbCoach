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
        case .fourMeter:  return [.bestScore, .underParPercent, .sessionCount]
        case .inkasting:  return [.tightestCluster, .spreadRatio, .inkastCount]
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
    case bestScore        = "Best Score"
    case underParPercent  = "% Under Par"
    case sessionCount     = "Sessions"
    case tightestCluster  = "Tightest Cluster"
    case spreadRatio      = "Spread Ratio"
    case inkastCount      = "Inkasts"

    var displayName: String {
        switch self {
        case .accuracy: return "Best Session"
        default: return rawValue
        }
    }

    // true = lower value ranks higher (e.g. −4 beats −2 for score-vs-par)
    var sortAscending: Bool {
        switch self {
        case .avgScoreVsPar, .avgClusterRadius, .bestScore, .tightestCluster, .spreadRatio: return true
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
        case .avgScoreVsPar, .bestScore:
            return value < 0
                ? String(format: "%.1f", value)
                : "+\(String(format: "%.1f", value))"
        case .avgClusterRadius:
            return String(format: "%.2fm", value)
        case .underParPercent:
            return String(format: "%.1f%%", value)
        case .sessionCount:
            return "\(Int(value))"
        case .tightestCluster:
            return String(format: "%.3fm", value)
        case .spreadRatio:
            return String(format: "%.2f×", value)
        case .inkastCount:
            return "\(Int(value))"
        }
    }

    // Returns a formatted secondary label (e.g. avg shown alongside a best value),
    // or nil when this metric has no secondary display.
    func formatSecondary(_ value: Double) -> String? {
        switch self {
        case .accuracy:
            return "(Avg \(String(format: "%.1f%%", value)))"
        case .bestScore:
            let s = value < 0
                ? String(format: "%.1f", value)
                : "+\(String(format: "%.1f", value))"
            return "(Avg: \(s))"
        default:
            return nil
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
    let secondaryValue: Double?   // e.g. average accuracy shown alongside best-session value
    let isCurrentUser: Bool

    init(id: UUID, rank: Int, displayName: String, value: Double,
         secondaryValue: Double? = nil, isCurrentUser: Bool) {
        self.id = id
        self.rank = rank
        self.displayName = displayName
        self.value = value
        self.secondaryValue = secondaryValue
        self.isCurrentUser = isCurrentUser
    }

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
