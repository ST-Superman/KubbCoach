//
//  WidgetDataService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/13/26.
//

import Foundation
import WidgetKit

/// Shared data structure for widget display. The widget can show any two of these
/// metrics (streak / competition countdown / live match status) per its config.
struct WidgetData: Codable {
    let currentStreak: Int
    let daysUntilCompetition: Int?
    let competitionName: String?
    let lastUpdated: Date
    let trainedToday: Bool
    // Live match status. OPTIONAL so blobs written by older builds (which lacked
    // these keys) still decode — a new non-optional field would fail decoding and
    // silently fall back to `.empty`.
    var matchesAwaitingYou: Int?
    var matchesAwaitingOpponent: Int?

    static let empty = WidgetData(
        currentStreak: 0,
        daysUntilCompetition: nil,
        competitionName: nil,
        lastUpdated: Date(),
        trainedToday: false,
        matchesAwaitingYou: nil,
        matchesAwaitingOpponent: nil
    )
}

/// Service for sharing data between the main app and widget extension via App Groups
final class WidgetDataService {
    static let shared = WidgetDataService()

    // MARK: - App Group Configuration
    // This must match the App Group identifier in your entitlements file
    // You'll create this in Xcode: Signing & Capabilities → App Groups → group.com.sathomps.kubbcoach
    private let appGroupIdentifier = "group.com.sathomps.kubbcoach"
    private let widgetDataKey = "widgetData"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}

    // MARK: - Save Data (Called from main app)
    //
    // Writes are load-modify-save: each writer updates only its own fields and
    // preserves the rest, so the streak/competition writers and the match-status
    // writer never clobber each other's slice of `WidgetData`.

    /// Save streak + competition data. Preserves any existing match status.
    func saveWidgetData(streak: Int, daysUntilCompetition: Int?, competitionName: String?, trainedToday: Bool = false) {
        let existing = loadWidgetData()
        let data = WidgetData(
            currentStreak: streak,
            daysUntilCompetition: daysUntilCompetition,
            competitionName: competitionName,
            lastUpdated: Date(),
            trainedToday: trainedToday,
            matchesAwaitingYou: existing.matchesAwaitingYou,
            matchesAwaitingOpponent: existing.matchesAwaitingOpponent
        )
        write(data, debug: "streak=\(streak), competition=\(daysUntilCompetition ?? -1) days")
    }

    /// Save live match status (counts of active matches awaiting each side).
    /// Preserves the existing streak/competition data.
    func saveMatchStatus(awaitingYou: Int, awaitingOpponent: Int) {
        let existing = loadWidgetData()
        let data = WidgetData(
            currentStreak: existing.currentStreak,
            daysUntilCompetition: existing.daysUntilCompetition,
            competitionName: existing.competitionName,
            lastUpdated: Date(),
            trainedToday: existing.trainedToday,
            matchesAwaitingYou: awaitingYou,
            matchesAwaitingOpponent: awaitingOpponent
        )
        write(data, debug: "matches you=\(awaitingYou) opp=\(awaitingOpponent)")
    }

    private func write(_ data: WidgetData, debug: String) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            AppLogger.general.error("Failed to encode widget data")
            return
        }
        userDefaults?.set(encoded, forKey: widgetDataKey)
        AppLogger.general.debug("📊 Widget data saved: \(debug)")

        // Notify WidgetKit to reload timelines
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Load Data (Called from widget)

    /// Load widget data from shared container
    func loadWidgetData() -> WidgetData {
        guard let data = userDefaults?.data(forKey: widgetDataKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .empty
        }
        return decoded
    }
}
