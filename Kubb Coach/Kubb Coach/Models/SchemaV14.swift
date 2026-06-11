import SwiftData
import Foundation

// SchemaV14 — re-anchors the schema to the current live model state and
// formally introduces AppMetadata.
//
// Why this version exists:
// V13 was frozen as the schema identifier in the App Store 1.x build, but
// later changes added live @Model properties (notably TrainingSession's
// `needsCloudUpload` / `cloudUploadedAt` fields, plus Conditions fields)
// without bumping the schema version. SwiftData's checksum for V13 then
// drifted from what 1.x users wrote to disk, leaving every upgrade-from-1.x
// install in a "permanently unrecoverable" staged-migration state — which
// the catastrophic fallback in `Kubb_CoachApp.swift` was wiping silently.
//
// V14 introduces a new `AppMetadata` model. Adding a new model type changes
// the checksum, which gives SwiftData a clean target to migrate V13 → V14
// via lightweight migration. Any field additions that drifted V13's
// definition are absorbed here.

enum SchemaV14: VersionedSchema {
    static var versionIdentifier = Schema.Version(14, 0, 0)

    static var models: [any PersistentModel.Type] {
        var allModels: [any PersistentModel.Type] = [
            TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            PressureCookerSession.self,
            // AppMetadata is intentionally included on BOTH platforms so the
            // V14 model list differs from V13 on watchOS too. Without this,
            // the watchOS V13 list (which excludes all iOS-only models)
            // would be identical to V14's, producing a duplicate-checksum
            // crash on the Watch app at launch.
            AppMetadata.self,
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
        allModels.append(FocusAreaPreference.self)
        #endif

        return allModels
    }
}
