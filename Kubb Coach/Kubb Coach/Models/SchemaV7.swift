//
//  SchemaV7.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/6/26.
//

import SwiftData
import Foundation

enum SchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(7, 0, 0)

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
        allModels.append(SyncMetadata.self)  // NEW: CloudKit sync metadata
        #endif

        return allModels
    }
}
