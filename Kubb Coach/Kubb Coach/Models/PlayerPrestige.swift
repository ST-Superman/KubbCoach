//
//  PlayerPrestige.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import Foundation
import SwiftData

/// Represents a player's prestige system for infinite progression beyond level 60
@Model
final class PlayerPrestige {
    var id: UUID
    var prestigeLevel: Int       // Current level within prestige (1-60)
    var totalPrestiges: Int       // Number of times prestiged
    var lastPrestigedAt: Date?    // When the last prestige occurred

    init(
        id: UUID = UUID(),
        prestigeLevel: Int = 1,
        totalPrestiges: Int = 0,
        lastPrestigedAt: Date? = nil
    ) {
        self.id = id
        self.prestigeLevel = prestigeLevel
        self.totalPrestiges = totalPrestiges
        self.lastPrestigedAt = lastPrestigedAt
    }

    // MARK: - Computed Properties

    /// Returns the prestige title based on total prestiges
    var title: String? {
        switch totalPrestiges {
        case 0:
            return nil
        case 1:
            return "CM"  // Candidate Master
        case 2:
            return "FM"  // FIDE Master
        case 3:
            return "IM"  // International Master
        case 4...:
            return "GM"  // Grandmaster
        default:
            return nil
        }
    }

    /// Returns the full prestige title with stars for GM levels
    var fullTitle: String? {
        guard totalPrestiges > 0 else { return nil }

        if totalPrestiges >= 4 {
            let stars = String(repeating: "⭐", count: totalPrestiges - 3)
            return "GM \(stars)"
        }
        return title
    }

    /// Returns the border tier level for visual styling (0-4)
    var borderLevel: Int {
        return min(totalPrestiges, 4)
    }

    // MARK: - Methods

    /// Returns true if the player can prestige (level 60 reached)
    func canPrestige() -> Bool {
        return prestigeLevel >= 60
    }

    /// Performs the prestige action, resetting level to 1 and incrementing prestige count
    func performPrestige() {
        guard canPrestige() else { return }
        prestigeLevel = 1
        totalPrestiges += 1
        lastPrestigedAt = Date()
    }
}
