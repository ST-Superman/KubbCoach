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

    // Game Tracker challenges
    case gameTrackerAny = "game_tracker_any"
    case gameTrackerWin = "game_tracker_win"
    case gameTrackerPositive = "game_tracker_positive"
    case gameTrackerKing = "game_tracker_king"
    case gameTrackerDouble = "game_tracker_double"

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
            return "Complete \(targetCount ?? 3) training sessions"
        case .trainAllPhases:
            return "Train all \(targetCount ?? 3) phases today"
        case .maintainStreak:
            return "Keep your training streak alive"
        case .eightMeterAccuracy:
            return "Hit \(Int(targetValue ?? 70))% accuracy in 8m"
        case .eightMeterRounds:
            return "Complete \(targetCount ?? 5) rounds of 8m"
        case .blastingParOrBetter:
            return "Achieve par or better in blasting"
        case .blastingRounds:
            return "Complete \(targetCount ?? 5) rounds of blasting"
        case .inkastingConsistency:
            return "Achieve tight cluster in inkasting"
        case .inkastingRounds:
            return "Complete \(targetCount ?? 5) rounds of inkasting"
        case .gameTrackerAny:
            return "Play a game (any mode)"
        case .gameTrackerWin:
            return "Win a competitive game"
        case .gameTrackerPositive:
            return "Finish a game with positive avg progress"
        case .gameTrackerKing:
            return "Knock the king in a game"
        case .gameTrackerDouble:
            return "Complete 2 games today"
        case .achieveAccuracy:
            return "Hit \(Int(targetValue ?? 70))% accuracy (deprecated)"
        case .completePhaseSession:
            return "Complete a session (deprecated)"
        case .completeRounds:
            return "Complete \(targetCount ?? 5) rounds (deprecated)"
        }
    }

    var description: String {
        switch self {
        case .completeSession:
            return "Complete any training session today"
        case .completeThreeSessions:
            return "Complete \(targetCount ?? 3) training sessions today"
        case .trainAllPhases:
            return "Practice 8m, 4m Blasting, and Inkasting today"
        case .maintainStreak:
            return "Complete at least one session to keep your streak"
        case .eightMeterAccuracy:
            return "Achieve \(Int(targetValue ?? 70))% or better accuracy in an 8 meter session"
        case .eightMeterRounds:
            return "Complete \(targetCount ?? 5) rounds of 8 meter training today"
        case .blastingParOrBetter:
            if let target = targetValue {
                return "Achieve par or better (score ≤ \(Int(target))) in a blasting session"
            } else {
                return "Achieve par or better in a blasting session"
            }
        case .blastingRounds:
            return "Complete \(targetCount ?? 5) rounds of blasting training today"
        case .inkastingConsistency:
            return "Achieve a core area under \(targetValue ?? 2.0) m² in an inkasting session"
        case .inkastingRounds:
            return "Complete \(targetCount ?? 5) rounds of inkasting training today"
        case .gameTrackerAny:
            return "Complete any Game Tracker game today (phantom or competitive)"
        case .gameTrackerWin:
            return "Win a competitive Game Tracker game today"
        case .gameTrackerPositive:
            return "Finish a game with an average positive progress per turn"
        case .gameTrackerKing:
            return "Knock the king during a game to win"
        case .gameTrackerDouble:
            return "Complete 2 Game Tracker games today"
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
        case .gameTrackerAny:
            return 25
        case .gameTrackerWin:
            return 50
        case .gameTrackerPositive:
            return 40
        case .gameTrackerKing:
            return 50
        case .gameTrackerDouble:
            return 60
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
            return "8.circle"
        case .blastingParOrBetter:
            return "bolt.fill"
        case .blastingRounds:
            return "4.circle"
        case .inkastingConsistency:
            return "scope"
        case .inkastingRounds:
            return "5.circle"
        case .gameTrackerAny:
            return "flag.2.crossed.fill"
        case .gameTrackerWin:
            return "crown.fill"
        case .gameTrackerPositive:
            return "chart.line.uptrend.xyaxis"
        case .gameTrackerKing:
            return "crown.circle.fill"
        case .gameTrackerDouble:
            return "2.circle.fill"
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
        case .gameTrackerAny, .gameTrackerWin, .gameTrackerPositive, .gameTrackerKing, .gameTrackerDouble:
            return nil  // Game tracker challenges are not tied to a TrainingPhase
        case .achieveAccuracy, .completePhaseSession, .completeRounds:
            return nil
        }
    }

    /// Target value for performance-based challenges (e.g., 70% accuracy, 2.0 m² area)
    var targetValue: Double? {
        switch self {
        case .eightMeterAccuracy, .achieveAccuracy:
            return 70.0  // Percentage
        case .inkastingConsistency:
            return 2.0   // Square meters
        case .blastingParOrBetter:
            return 0.0   // Par score
        default:
            return nil
        }
    }

    /// Target count for repetition-based challenges (e.g., complete X rounds/sessions)
    var targetCount: Int? {
        switch self {
        case .completeSession, .maintainStreak:
            return 1
        case .trainAllPhases:
            return 3  // 3 phases
        case .completeThreeSessions:
            return 3
        case .eightMeterRounds, .blastingRounds, .inkastingRounds, .completeRounds:
            return 5
        case .completePhaseSession:
            return 1
        case .gameTrackerAny, .gameTrackerWin, .gameTrackerPositive, .gameTrackerKing:
            return 1
        case .gameTrackerDouble:
            return 2
        default:
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
        // Validate targetProgress
        guard targetProgress > 0 else {
            preconditionFailure("DailyChallenge targetProgress must be positive, got: \(targetProgress)")
        }

        self.id = UUID()
        self.date = date
        self.challengeType = challengeType
        self.targetPhase = targetPhase
        self.currentProgress = 0
        self.targetProgress = targetProgress
        self.isCompleted = false
        self.completedAt = nil
    }

    // MARK: - Computed Properties

    var progressPercentage: Double {
        guard targetProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetProgress), 1.0)
    }

    /// Returns the remaining progress needed to complete the challenge
    var remainingProgress: Int {
        max(0, targetProgress - currentProgress)
    }

    /// Returns true if the challenge has expired (not for today)
    var isExpired: Bool {
        !isForToday()
    }

    // MARK: - Methods

    /// Updates the challenge progress by the specified amount
    /// - Parameter amount: The amount to add to current progress (must be non-negative)
    /// - Note: Automatically marks challenge as completed when target is reached
    func updateProgress(_ amount: Int) {
        guard amount >= 0 else {
            assertionFailure("DailyChallenge progress amount must be non-negative, got: \(amount)")
            return
        }

        currentProgress = max(0, currentProgress + amount)

        if currentProgress >= targetProgress && !isCompleted {
            isCompleted = true
            completedAt = Date()
        }
    }

    /// Resets the challenge progress to zero
    /// - Note: Useful if sessions are deleted or challenge needs to be restarted
    func resetProgress() {
        currentProgress = 0
        isCompleted = false
        completedAt = nil
    }

    /// Checks if the challenge is for today in the device's timezone
    /// - Returns: True if the challenge date is today
    func isForToday() -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
