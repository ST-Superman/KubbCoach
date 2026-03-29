//
//  KubbCoachMigrationPlan.swift
//  Kubb Coach
//
//  Migration plan for safe SwiftData schema upgrades
//

import SwiftData
import Foundation

/// Migration plan that defines safe upgrade paths through all schema versions
/// This ensures users can upgrade from any previous version without data loss
enum KubbCoachMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self, SchemaV8.self]
    }

    static var stages: [MigrationStage] {
        [
            // V2 → V3: Added PersonalBest, EarnedMilestone, PlayerPrestige
            migrateV2toV3,

            // V3 → V4: Added StreakFreeze
            migrateV3toV4,

            // V4 → V5: Added EmailReportSettings, CompetitionSettings
            migrateV4toV5,

            // V5 → V6: Added deviceType field to TrainingSession
            migrateV5toV6,

            // V6 → V7: Added SyncMetadata, TrainingGoal
            migrateV6toV7,

            // V7 → V8: Added DailyChallenge
            migrateV7toV8
        ]
    }

    // MARK: - Migration Stages

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self
    )

    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )

    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: SchemaV5.self,
        toVersion: SchemaV6.self
    )

    static let migrateV6toV7 = MigrationStage.lightweight(
        fromVersion: SchemaV6.self,
        toVersion: SchemaV7.self
    )

    static let migrateV7toV8 = MigrationStage.lightweight(
        fromVersion: SchemaV7.self,
        toVersion: SchemaV8.self
    )
}
