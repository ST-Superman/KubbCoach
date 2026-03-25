//
//  LastTrainingConfig.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import Foundation
import SwiftData

@Model
final class LastTrainingConfig {
    var phase: TrainingPhase
    var sessionType: SessionType
    var configuredRounds: Int
    var lastUsedAt: Date

    init(phase: TrainingPhase, sessionType: SessionType, configuredRounds: Int) {
        self.phase = phase
        self.sessionType = sessionType

        // Validate configuredRounds is one of the allowed values
        let validRounds = [5, 10, 15, 20]
        if validRounds.contains(configuredRounds) {
            self.configuredRounds = configuredRounds
        } else {
            AppLogger.database.warning("Invalid configuredRounds: \(configuredRounds). Defaulting to 10.")
            self.configuredRounds = 10
        }

        self.lastUsedAt = Date()
    }
}
