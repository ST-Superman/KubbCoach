//
//  CompetitionSettings.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import Foundation
import SwiftData

/// Represents user settings for tracking upcoming competitions
@Model
final class CompetitionSettings {
    var id: UUID
    var nextCompetitionDate: Date?  // Date of the next competition
    var competitionName: String?    // Name of the competition
    var competitionLocation: String? // Location of the competition

    init(
        id: UUID = UUID(),
        nextCompetitionDate: Date? = nil,
        competitionName: String? = nil,
        competitionLocation: String? = nil
    ) {
        self.id = id
        self.nextCompetitionDate = nextCompetitionDate
        self.competitionName = competitionName
        self.competitionLocation = competitionLocation
    }

    // MARK: - Computed Properties

    /// Returns the number of days until the competition, or nil if no date is set
    var daysUntilCompetition: Int? {
        guard let competitionDate = nextCompetitionDate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: competitionDate)
        return components.day
    }

    /// Returns true if the competition date has passed
    var isPast: Bool {
        guard let competitionDate = nextCompetitionDate else { return false }
        return competitionDate < Date()
    }
}
