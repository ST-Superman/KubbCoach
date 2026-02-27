//
//  SchemaV3.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftData
import Foundation

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        var allModels: [any PersistentModel.Type] = [
            TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            CachedCloudSession.self,
            CachedCloudRound.self,
            CachedCloudThrow.self,
        ]

        #if os(iOS)
        allModels.append(InkastingAnalysis.self)
        allModels.append(CalibrationSettings.self)
        allModels.append(InkastingSettings.self)
        allModels.append(LastTrainingConfig.self)
        allModels.append(PersonalBest.self)
        allModels.append(EarnedMilestone.self)
        #endif

        return allModels
    }
}
