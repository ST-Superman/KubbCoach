//
//  SchemaV5.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/6/26.
//

import SwiftData
import Foundation

enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        var allModels: [any PersistentModel.Type] = [
            TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            // CachedCloudSession models removed - no longer needed
            // Watch sessions are now converted directly to TrainingSession
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
        #endif

        return allModels
    }
}
