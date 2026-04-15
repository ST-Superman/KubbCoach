//
//  SchemaV11.swift
//  Kubb Coach
//
//  Schema version 11 — adds xpEarned to GameSession so Game Tracker
//  sessions participate in the XP / level progression system.
//

import SwiftData
import Foundation

enum SchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(11, 0, 0)

    static var models: [any PersistentModel.Type] {
        var allModels: [any PersistentModel.Type] = [
            TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
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
