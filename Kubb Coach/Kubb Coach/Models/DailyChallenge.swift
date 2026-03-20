//
//  DailyChallenge.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import Foundation
import SwiftData

enum ChallengeType: String, Codable {
    // General challenges (any session type)
    case completeSession = "complete_session"
    case completeThreeSessions = "complete_three_sessions"
    case trainAllPhases = "train_all_phases"
    case maintainStreak = "maintain_streak"

    // 8 Meter specific challenges
    case eightMeterAccuracy = "eight_meter_accuracy"
    case eightMeterRounds = "eight_meter_rounds"

    // Blasting specific challenges
    case blastingParOrBetter = "blasting_par_or_better"
    case blastingRounds = "blasting_rounds"

    // Inkasting specific challenges
    case inkastingConsistency = "inkasting_consistency"
    case inkastingRounds = "inkasting_rounds"

    // Deprecated - kept for backward compatibility with existing challenges
    @available(*, deprecated, message: "Use phase-specific challenges instead")
    case achieveAccuracy = "achieve_accuracy"
    @available(*, deprecated, message: "Use phase-specific challenges instead")
    case completePhaseSession = "complete_phase_session"
    @available(*, deprecated, message: "Use phase-specific challenges instead")
    case completeRounds = "complete_rounds"

    var displayName: String {
        switch self {
        case .completeSession:
            return "Complete any training session"
        case .completeThreeSessions:
            return "Complete 3 training sessions"
        case .trainAllPhases:
            return "Train all 3 phases today"
        case .maintainStreak:
            return "Keep your training streak alive"
        case .eightMeterAccuracy:
            return "Hit 70% accuracy in 8m"
        case .eightMeterRounds:
            return "Complete 5 rounds of 8m"
        case .blastingParOrBetter:
            return "Achieve par or better in blasting"
        case .blastingRounds:
            return "Complete 5 rounds of blasting"
        case .inkastingConsistency:
            return "Achieve tight cluster in inkasting"
        case .inkastingRounds:
            return "Complete 5 rounds of inkasting"
        case .achieveAccuracy:
            return "Hit 70% accuracy (deprecated)"
        case .completePhaseSession:
            return "Complete a session (deprecated)"
        case .completeRounds:
            return "Complete 5 rounds (deprecated)"
        }
    }

    var description: String {
        switch self {
        case .completeSession:
            return "Complete any training session today"
        case .completeThreeSessions:
            return "Complete 3 training sessions today"
        case .trainAllPhases:
            return "Practice 8m, 4m Blasting, and Inkasting today"
        case .maintainStreak:
            return "Complete at least one session to keep your streak"
        case .eightMeterAccuracy:
            return "Achieve 70% or better accuracy in an 8 meter session"
        case .eightMeterRounds:
            return "Complete 5 rounds of 8 meter training today"
        case .blastingParOrBetter:
            return "Achieve par or better (score ≤ 0) in a blasting session"
        case .blastingRounds:
            return "Complete 5 rounds of blasting training today"
        case .inkastingConsistency:
            return "Achieve a core area under 2.0 m² in an inkasting session"
        case .inkastingRounds:
            return "Complete 5 rounds of inkasting training today"
        case .achieveAccuracy:
            return "Complete any training session (old challenge, will refresh tomorrow)"
        case .completePhaseSession:
            return "Complete any training session (old challenge, will refresh tomorrow)"
        case .completeRounds:
            return "Complete any training session (old challenge, will refresh tomorrow)"
        }
    }

    var xpReward: Int {
        switch self {
        case .completeSession, .maintainStreak:
            return 25
        case .eightMeterRounds, .blastingRounds, .inkastingRounds:
            return 40
        case .eightMeterAccuracy, .blastingParOrBetter, .inkastingConsistency:
            return 50
        case .trainAllPhases:
            return 60
        case .completeThreeSessions:
            return 75
        case .achieveAccuracy, .completePhaseSession:
            return 25
        case .completeRounds:
            return 25
        }
    }

    var icon: String {
        switch self {
        case .completeSession, .completeThreeSessions:
            return "checkmark.circle.fill"
        case .trainAllPhases:
            return "flame.fill"
        case .maintainStreak:
            return "calendar.badge.clock"
        case .eightMeterAccuracy:
            return "target"
        case .eightMeterRounds:
            return "arrow.clockwise"
        case .blastingParOrBetter:
            return "bolt.fill"
        case .blastingRounds:
            return "arrow.clockwise"
        case .inkastingConsistency:
            return "scope"
        case .inkastingRounds:
            return "arrow.clockwise"
        case .achieveAccuracy:
            return "target"
        case .completePhaseSession:
            return "checkmark.circle.fill"
        case .completeRounds:
            return "arrow.clockwise"
        }
    }

    var requiredPhase: TrainingPhase? {
        switch self {
        case .eightMeterAccuracy, .eightMeterRounds:
            return .eightMeters
        case .blastingParOrBetter, .blastingRounds:
            return .fourMetersBlasting
        case .inkastingConsistency, .inkastingRounds:
            return .inkastingDrilling
        case .completeSession, .completeThreeSessions, .trainAllPhases, .maintainStreak:
            return nil
        case .achieveAccuracy, .completePhaseSession, .completeRounds:
            return nil
        }
    }
}

@Model
final class DailyChallenge {
    var id: UUID
    var date: Date
    var challengeType: ChallengeType
    var targetPhase: TrainingPhase?
    var currentProgress: Int
    var targetProgress: Int
    var isCompleted: Bool
    var completedAt: Date?

    init(
        date: Date = Date(),
        challengeType: ChallengeType,
        targetPhase: TrainingPhase? = nil,
        targetProgress: Int = 1
    ) {
        self.id = UUID()
        self.date = date
        self.challengeType = challengeType
        self.targetPhase = targetPhase
        self.currentProgress = 0
        self.targetProgress = targetProgress
        self.isCompleted = false
        self.completedAt = nil
    }

    var progressPercentage: Double {
        guard targetProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetProgress), 1.0)
    }

    func updateProgress(_ amount: Int) {
        currentProgress += amount
        if currentProgress >= targetProgress && !isCompleted {
            isCompleted = true
            completedAt = Date()
        }
    }

    func isForToday() -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
