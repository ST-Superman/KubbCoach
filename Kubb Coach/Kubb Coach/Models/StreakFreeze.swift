//
//  StreakFreeze.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import Foundation
import SwiftData

/// Represents a streak freeze that protects a player's training streak from breaking
@Model
final class StreakFreeze {
    var id: UUID
    var availableFreeze: Bool  // Whether a freeze is currently available to use
    var earnedAt: Date?        // When the freeze was earned
    var usedAt: Date?          // When the freeze was used (nil if not used)

    init(
        id: UUID = UUID(),
        availableFreeze: Bool = false,
        earnedAt: Date? = nil,
        usedAt: Date? = nil
    ) {
        self.id = id
        self.availableFreeze = availableFreeze
        self.earnedAt = earnedAt
        self.usedAt = usedAt
    }

    // MARK: - Methods

    /// Earns a new streak freeze
    func earnFreeze() {
        availableFreeze = true
        earnedAt = Date()
        usedAt = nil
    }

    /// Uses the streak freeze, returns true if successful
    @discardableResult
    func useFreeze() -> Bool {
        guard availableFreeze else { return false }
        availableFreeze = false
        usedAt = Date()
        return true
    }
}
