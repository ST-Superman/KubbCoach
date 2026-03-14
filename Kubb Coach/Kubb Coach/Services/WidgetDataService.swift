//
//  WidgetDataService.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/13/26.
//

import Foundation
import WidgetKit

/// Shared data structure for widget display
struct WidgetData: Codable {
    let currentStreak: Int
    let daysUntilCompetition: Int?
    let competitionName: String?
    let lastUpdated: Date

    static let empty = WidgetData(
        currentStreak: 0,
        daysUntilCompetition: nil,
        competitionName: nil,
        lastUpdated: Date()
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

    /// Save widget data to shared container. Call this after session completion or settings changes.
    func saveWidgetData(streak: Int, daysUntilCompetition: Int?, competitionName: String?) {
        let data = WidgetData(
            currentStreak: streak,
            daysUntilCompetition: daysUntilCompetition,
            competitionName: competitionName,
            lastUpdated: Date()
        )

        guard let encoded = try? JSONEncoder().encode(data) else {
            AppLogger.general.error("Failed to encode widget data")
            return
        }

        userDefaults?.set(encoded, forKey: widgetDataKey)
        AppLogger.general.debug("📊 Widget data saved: streak=\(streak), competition=\(daysUntilCompetition ?? -1) days")

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
