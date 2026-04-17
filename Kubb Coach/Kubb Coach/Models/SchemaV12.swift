//
//  SchemaV12.swift
//  Kubb Coach
//
//  Schema version 12 — adds PressureCookerSession for Pressure Cooker mini-games
//  (initial game: 3-4-3). Lightweight migration from V9; no existing data is changed.
//

import SwiftData
import Foundation

enum SchemaV12: VersionedSchema {
    static var versionIdentifier = Schema.Version(12, 0, 0)

    static var models: [any PersistentModel.Type] {
        var allModels: [any PersistentModel.Type] = [
            TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            PressureCookerSession.self,
        ]

        #if os(iOS)
        allModels.append(InkastingAnalysis.self)
        allModels.append(CalibrationSettings.self)
        allModels.append(InkastingSettings.self)
        allModels.append(LastTrainingConfig.self)
        allModels.append(PersonalBest.self)
        allModels.append(EarnedMilestone.self)
        allModels.append(PlayerPrestige.self)
        allModels.append(StreakFreeze.self)
        allModels.append(EmailReportSettings.self)
        allModels.append(CompetitionSettings.self)
        allModels.append(SessionStatisticsAggregate.self)
        allModels.append(SyncMetadata.self)
        allModels.append(TrainingGoal.self)
        allModels.append(DailyChallenge.self)
        allModels.append(GoalAnalytics.self)
        allModels.append(GameSession.self)
        allModels.append(GameTurn.self)
        #endif

        return allModels
    }
}
