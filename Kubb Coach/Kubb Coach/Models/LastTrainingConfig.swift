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
        self.configuredRounds = configuredRounds
        self.lastUsedAt = Date()
    }
}
