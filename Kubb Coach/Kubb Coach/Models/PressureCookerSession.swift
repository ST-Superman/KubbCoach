//
//  PressureCookerSession.swift
//  Kubb Coach
//
//  SwiftData model for Pressure Cooker mini-game sessions.
//  Supports:
//    - 3-4-3 (gameType "343"): 10 frames, 0–13 pts each.
//    - In the Red (gameType "inTheRed"): 5 or 10 rounds, scores −1/0/+1 per round.
//      Extra stored properties (all with defaults for lightweight migration):
//        itrRoundScenarios  – InTheRedScenario.rawValue for each round
//        itrTotalRounds     – configured session length (5 or 10)
//        itrMode            – "random" or a scenario rawValue
//

import Foundation
import SwiftData

@Model
final class PressureCookerSession {

    // MARK: - Stored Properties

    var id: UUID = UUID()
    /// Identifies which mini-game was played. Use PressureCookerGameType raw values.
    var gameType: String = PressureCookerGameType.threeForThree.rawValue
    var createdAt: Date = Date()
    var completedAt: Date?

    /// Scores for each frame/round in order.
    /// 3-4-3: up to 10 values (0–13 each).
    /// In the Red: up to 10 values (−1, 0, or +1 each).
    var frameScores: [Int] = []

    /// XP awarded when the session completed.
    var xpEarned: Double = 0.0

    // MARK: - In the Red stored properties (defaults allow lightweight migration)

    /// InTheRedScenario.rawValue for each round, in order. Empty for 3-4-3 sessions.
    var itrRoundScenarios: [String] = []

    /// Configured total rounds (5 or 10) for PB tracking by session length. 0 for 3-4-3.
    var itrTotalRounds: Int = 0

    /// Mode raw value: "random" or an InTheRedScenario.rawValue. Empty for 3-4-3.
    var itrMode: String = ""

    // MARK: - Computed Properties

    var totalScore: Int {
        frameScores.reduce(0, +)
    }

    var framesCompleted: Int {
        frameScores.count
    }

    var isComplete: Bool {
        completedAt != nil
    }

    // MARK: - 3-4-3 Specific

    /// Max possible score per frame is 13 (10 kubbs + 3 bonus batons).
    static let maxFrameScore = 13

    /// A game consists of exactly 10 frames.
    static let totalFrames = 10

    /// Max possible total score for a full game.
    static let maxTotalScore = maxFrameScore * totalFrames  // 130

    // MARK: - Init

    init(gameType: PressureCookerGameType = .threeForThree) {
        self.id = UUID()
        self.gameType = gameType.rawValue
        self.createdAt = Date()
    }

    // MARK: - Helpers

    /// Append a 3-4-3 frame score (clamped to 0–13) and return the updated total.
    @discardableResult
    func recordFrame(score: Int) -> Int {
        let clamped = max(0, min(score, PressureCookerSession.maxFrameScore))
        frameScores.append(clamped)
        return totalScore
    }

    /// Append an In the Red round result (−1, 0, or +1) along with its scenario.
    @discardableResult
    func recordITRRound(score: Int, scenario: InTheRedScenario) -> Int {
        let clamped = max(-1, min(1, score))
        frameScores.append(clamped)
        itrRoundScenarios.append(scenario.rawValue)
        return totalScore
    }
}

// MARK: - Game Type

enum PressureCookerGameType: String, Codable {
    case threeForThree = "343"
    case inTheRed      = "inTheRed"

    var displayName: String {
        switch self {
        case .threeForThree: return "3-4-3"
        case .inTheRed:      return "In the Red"
        }
    }
}

// MARK: - In the Red Scenario

enum InTheRedScenario: String, CaseIterable, Codable {
    /// 1 field kubb at 4m + 1 baseline kubb at 8m + king. 3 batons.
    case field4m8mKing = "4m_8m_king"
    /// 2 baseline kubbs at 8m + king. 3 batons.
    case two8mKing     = "8m_8m_king"
    /// 1 baseline kubb at 8m + king. 2 batons.
    case one8mKing     = "8m_king"

    var displayName: String {
        switch self {
        case .field4m8mKing: return "4m · 8m · King"
        case .two8mKing:     return "8m · 8m · King"
        case .one8mKing:     return "8m · King"
        }
    }

    var shortLabel: String {
        switch self {
        case .field4m8mKing: return "4m, 8m, King"
        case .two8mKing:     return "8m, 8m, King"
        case .one8mKing:     return "8m, King"
        }
    }

    var batonCount: Int {
        switch self {
        case .field4m8mKing, .two8mKing: return 3
        case .one8mKing:                 return 2
        }
    }

    var setupDescription: String {
        switch self {
        case .field4m8mKing:
            return "Place 1 field kubb near the 4m line along the sideline (simulating an inkasted kubb). Place 1 baseline kubb at 8m. Attack in order: field kubb → baseline kubb → king."
        case .two8mKing:
            return "Place 2 baseline kubbs at 8m, spread apart. Attack in order: first baseline kubb → second baseline kubb → king."
        case .one8mKing:
            return "Place 1 baseline kubb at 8m. You only have 2 batons. Attack in order: baseline kubb → king."
        }
    }

    var throwingOrderSummary: String {
        switch self {
        case .field4m8mKing: return "Field kubb → Baseline kubb → King"
        case .two8mKing:     return "Baseline kubb → Baseline kubb → King"
        case .one8mKing:     return "Baseline kubb → King"
        }
    }
}

// MARK: - In the Red random sequence generation

extension InTheRedScenario {
    /// Generates a round sequence with no consecutive repeats and each scenario
    /// appearing at least once (in the first 3 slots).
    static func generateRandomSequence(rounds: Int) -> [InTheRedScenario] {
        var seq: [InTheRedScenario] = Array(allCases.shuffled().prefix(min(rounds, 3)))
        while seq.count < rounds {
            let available = allCases.filter { $0 != seq.last }
            if let next = available.randomElement() {
                seq.append(next)
            }
        }
        return seq
    }
}
