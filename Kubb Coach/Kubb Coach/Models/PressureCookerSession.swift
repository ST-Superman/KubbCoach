//
//  PressureCookerSession.swift
//  Kubb Coach
//
//  SwiftData model for Pressure Cooker mini-game sessions.
//  Currently supports the 3-4-3 game type (10 frames, 0–13 pts each).
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

    /// Scores for each frame in order. For 3-4-3, this is up to 10 values (0–13 each).
    var frameScores: [Int] = []

    /// XP awarded when the session completed. Stored so level computation remains accurate
    /// even if the XP formula changes later.
    var xpEarned: Double = 0.0

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

    /// Append a frame score and return the updated total.
    @discardableResult
    func recordFrame(score: Int) -> Int {
        let clamped = max(0, min(score, PressureCookerSession.maxFrameScore))
        frameScores.append(clamped)
        return totalScore
    }
}

// MARK: - Game Type

enum PressureCookerGameType: String, Codable {
    case threeForThree = "343"

    var displayName: String {
        switch self {
        case .threeForThree: return "3-4-3"
        }
    }
}
