import SwiftData
import Foundation

// SchemaV15 — adds VirtualMatchRecord (iOS-only), the local snapshot of a
// finished online match that feeds progression (XP/milestones/streaks) and the
// Records/Journey surfaces.
//
// Additive lightweight migration from V14: VirtualMatchRecord has all-default
// properties, so SwiftData migrates V14 → V15 automatically.
//
// iOS-only on purpose. VirtualMatchRecord is not compiled into / registered on
// watchOS, and SchemaV15 is kept OUT of the watchOS branch of
// KubbCoachMigrationPlan — on watch its model set would equal V14's and trigger
// a duplicate-checksum crash. The watch app builds its container without a
// versioned schema or migration plan, so it is unaffected.

enum SchemaV15: VersionedSchema {
    static var versionIdentifier = Schema.Version(15, 0, 0)

    static var models: [any PersistentModel.Type] {
        var allModels: [any PersistentModel.Type] = [
            TrainingSession.self,
            TrainingRound.self,
            ThrowRecord.self,
            PressureCookerSession.self,
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
        allModels.append(VirtualMatchRecord.self)
        #endif

        return allModels
    }
}
