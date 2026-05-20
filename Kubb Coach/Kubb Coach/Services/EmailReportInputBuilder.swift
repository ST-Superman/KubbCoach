//
//  EmailReportInputBuilder.swift
//  Kubb Coach
//

import Foundation
import SwiftData

/// Assembles the inputs needed to generate an `EmailReport`. Used by both the
/// Settings preview/test-send path and the notification-driven send path so
/// the two cannot drift apart on filtering or streak logic.
///
/// Filtering rules (must match what the Lodge displays):
/// - Local TrainingSessions: completed only, plus Watch sessions which may not
///   stamp `completedAt` the same way iOS does (mirrors TimelineView).
/// - GameSessions and PressureCookerSessions: completed only.
@MainActor
struct EmailReportInputBuilder {

    struct Inputs {
        let sessions: [SessionDisplayItem]
        let gameSessions: [GameSession]
        let pcSessions: [PressureCookerSession]
        let playerLevel: PlayerLevel
        let streak: Int
        let competitionSettings: CompetitionSettings?
        let inkastingSettings: InkastingSettings
    }

    /// Builds inputs by fetching everything fresh from the model context.
    /// Use this from contexts that don't already have @Query-backed data.
    static func build(from context: ModelContext) -> Inputs {
        let localSessions = fetchAll(TrainingSession.self, context: context)
        let gameSessions = fetchAll(GameSession.self, context: context)
        let pcSessions = fetchAll(PressureCookerSession.self, context: context)
        let prestige = fetchAll(PlayerPrestige.self, context: context).first
        let competitionSettings = fetchAll(CompetitionSettings.self, context: context).first
        let inkastingSettings = fetchAll(InkastingSettings.self, context: context).first

        return build(
            localSessions: localSessions,
            gameSessions: gameSessions,
            pressureCookerSessions: pcSessions,
            prestige: prestige,
            competitionSettings: competitionSettings,
            inkastingSettings: inkastingSettings,
            context: context
        )
    }

    /// Builds inputs from already-fetched data. Use this from views that have
    /// @Query-backed properties to avoid re-fetching.
    static func build(
        localSessions: [TrainingSession],
        gameSessions: [GameSession],
        pressureCookerSessions: [PressureCookerSession],
        prestige: PlayerPrestige?,
        competitionSettings: CompetitionSettings?,
        inkastingSettings: InkastingSettings?,
        context: ModelContext
    ) -> Inputs {
        let completedLocal = localSessions.filter { $0.completedAt != nil || $0.deviceType == "Watch" }
        let sessions = completedLocal.map { SessionDisplayItem.local($0) }
        let completedGames = gameSessions.filter { $0.completedAt != nil }
        let completedPC = pressureCookerSessions.filter { $0.completedAt != nil }

        let playerLevel = PlayerLevelService.computeLevel(
            from: sessions,
            context: context,
            prestige: prestige ?? PlayerPrestige()
        )
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            gameSessions: completedGames,
            pcSessions: completedPC
        )

        return Inputs(
            sessions: sessions,
            gameSessions: completedGames,
            pcSessions: completedPC,
            playerLevel: playerLevel,
            streak: streak,
            competitionSettings: competitionSettings,
            inkastingSettings: inkastingSettings ?? InkastingSettings()
        )
    }

    private static func fetchAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) -> [T] {
        let descriptor = FetchDescriptor<T>()
        return (try? context.fetch(descriptor)) ?? []
    }
}
