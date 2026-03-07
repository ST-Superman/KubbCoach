//
//  SchemaV2.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftData
import Foundation

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

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
        #endif

        return allModels
    }
}
