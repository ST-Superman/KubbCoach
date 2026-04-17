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
        // IMPORTANT — Duplicate-checksum rule:
        // Every schema version in this list references *live* model types (not frozen
        // snapshots). SwiftData computes each version's checksum from the current
        // in-memory model definitions, so two versions that share the same set of model
        // types will always produce the same checksum — causing the
        // "Duplicate version checksums detected" crash at launch.
        //
        // When that happens the newer version must be *collapsed* into the older one:
        // omit the intermediate version from this list and bridge across it with a
        // single lightweight stage. Examples:
        //
        //   V4/V5/V6 collapsed → single V3→V6 stage (covers all three).
        //
        // On watchOS, DailyChallenge and GoalAnalytics are iOS-only, so V7 and V8 have
        // identical model lists and produce duplicate checksums on that platform.
        // V7 is skipped on watchOS: the single V6→V8 stage covers both transitions.
        #if os(watchOS)
        return [SchemaV2.self, SchemaV3.self, SchemaV6.self, SchemaV8.self, SchemaV9.self, SchemaV12.self]
        #else
        return [SchemaV2.self, SchemaV3.self, SchemaV6.self, SchemaV7.self, SchemaV8.self, SchemaV9.self, SchemaV12.self]
        #endif
    }

    static var stages: [MigrationStage] {
        #if os(watchOS)
        return [
            // V2 → V3
            migrateV2toV3,
            // V3 → V6 (covers V4/V5/V6)
            migrateV3toV6,
            // V6 → V8: covers V7 and V8 together on watchOS — DailyChallenge/GoalAnalytics
            //           are iOS-only so V7 and V8 are identical on this platform.
            migrateV6toV8,
            // V8 → V9: Added GameSession + GameTurn (Game Tracker).
            //           xpEarned (GameSession) and batonsToClearField (GameTurn) both have
            //           default values so lightweight migration handles them automatically.
            migrateV8toV9,
            // V9 → V12: Added PressureCookerSession for Pressure Cooker mini-games.
            //            New model with all-default properties; lightweight migration is safe.
            migrateV9toV12,
        ]
        #else
        return [
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
            migrateV7toV8,

            // V8 → V9: Added GameSession + GameTurn (Game Tracker).
            //           xpEarned (GameSession) and batonsToClearField (GameTurn) both have
            //           default values so lightweight migration handles them automatically.
            migrateV8toV9,

            // V9 → V12: Added PressureCookerSession for Pressure Cooker mini-games.
            //            New model with all-default properties; lightweight migration is safe.
            migrateV9toV12,
        ]
        #endif
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

    // watchOS only: V7 and V8 are identical on watchOS (DailyChallenge/GoalAnalytics are
    // iOS-only), so we jump directly from V6 to V8 to avoid duplicate checksum errors.
    static let migrateV6toV8 = MigrationStage.lightweight(
        fromVersion: SchemaV6.self,
        toVersion: SchemaV8.self
    )

    // V8 → V9: Added GameSession + GameTurn for the Game Tracker feature.
    // xpEarned (Double = 0.0) and batonsToClearField (Int?) both have default values,
    // so SwiftData's lightweight migration handles the new properties automatically.
    static let migrateV8toV9 = MigrationStage.lightweight(
        fromVersion: SchemaV8.self,
        toVersion: SchemaV9.self
    )

    // V9 → V12: Added PressureCookerSession for the Pressure Cooker mini-games.
    // All properties have default values; lightweight migration handles this automatically.
    // V10 and V11 were created but never activated in the migration plan, so we jump to V12.
    static let migrateV9toV12 = MigrationStage.lightweight(
        fromVersion: SchemaV9.self,
        toVersion: SchemaV12.self
    )
}
