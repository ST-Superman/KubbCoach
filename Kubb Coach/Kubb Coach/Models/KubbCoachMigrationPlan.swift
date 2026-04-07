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
        // V4, V5, and V6 all reference identical live model types (same stored properties),
        // so they produce the same checksum. Including all three causes
        // "Duplicate version checksums across stages" at runtime.
        // V4/V5/V6 are collapsed: the single V3→V6 stage covers all three transitions.
        [SchemaV2.self, SchemaV3.self, SchemaV6.self, SchemaV7.self, SchemaV8.self]
    }

    static var stages: [MigrationStage] {
        [
            // V2 → V3: Added PersonalBest, EarnedMilestone, PlayerPrestige, StreakFreeze,
            //          EmailReportSettings, CompetitionSettings
            migrateV2toV3,

            // V3 → V6: Added SessionStatisticsAggregate + deviceType on TrainingSession.
            //          Covers V4/V5/V6 — collapsed because all three reference the same
            //          live model types and produce identical checksums.
            migrateV3toV6,

            // V6 → V7: Added SyncMetadata, TrainingGoal
            migrateV6toV7,

            // V7 → V8: Added DailyChallenge, GoalAnalytics
            migrateV7toV8
        ]
    }

    // MARK: - Migration Stages

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    static let migrateV3toV6 = MigrationStage.lightweight(
        fromVersion: SchemaV3.self,
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
