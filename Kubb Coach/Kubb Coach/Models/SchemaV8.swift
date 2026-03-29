//
//  SchemaV8.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/19/26.
//

import SwiftData
import Foundation

enum SchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(8, 1, 0)  // Minor version bump for bestEightMeterAccuracy property

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
        #endif

        return allModels
    }
}
