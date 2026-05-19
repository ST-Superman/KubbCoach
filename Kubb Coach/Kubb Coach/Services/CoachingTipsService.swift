//
//  CoachingTipsService.swift
//  Kubb Coach
//
//  Loads curated coaching tips from `CoachingTips.json` and serves
//  category-matched tips while avoiding short-term repetition.
//

import Foundation
import OSLog

final class CoachingTipsService {
    static let shared = CoachingTipsService()

    /// `@AppStorage` key for the user-facing "Show pro tips" toggle.
    /// Defaults to `true` when unset.
    static let showProTipsDefaultsKey = "coachingTipsShowProTips"

    private let logger = Logger(subsystem: "com.sathomps.kubbcoach", category: "CoachingTips")
    private let recentlyShownKey = "coachingTipsRecentlyShown"
    private let recencyWindow = 10
    private let userDefaults: UserDefaults

    private(set) var tips: [CoachingTip] = []
    private var byCategory: [TipCategory: [CoachingTip]] = [:]

    init(userDefaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.userDefaults = userDefaults
        loadTips(from: bundle)
    }

    // MARK: - Loading

    private func loadTips(from bundle: Bundle) {
        guard let url = bundle.url(forResource: "CoachingTips", withExtension: "json") else {
            logger.error("CoachingTips.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let library = try JSONDecoder().decode(CoachingTipsLibrary.self, from: data)
            self.tips = library.tips
            self.byCategory = Dictionary(grouping: library.tips, by: { $0.category })
            logger.info("Loaded \(library.tips.count, privacy: .public) coaching tips (v\(library.version, privacy: .public))")
        } catch {
            logger.error("Failed to decode CoachingTips.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Selection

    /// Returns a tip for the given category, preferring ones not recently shown.
    /// Returns nil only if the category has zero tips.
    func tip(for category: TipCategory, excludingRecent: Bool = true) -> CoachingTip? {
        let pool = byCategory[category] ?? []
        guard !pool.isEmpty else { return nil }

        if excludingRecent {
            let recent = Set(recentlyShown())
            let fresh = pool.filter { !recent.contains($0.id) }
            if let picked = fresh.randomElement() {
                recordShown(picked.id)
                return picked
            }
        }

        // Either recency was disabled or every tip in the pool has been shown
        // recently. Fall back to a random pick; still record it so the rotation
        // continues to evolve.
        let picked = pool.randomElement()
        if let picked { recordShown(picked.id) }
        return picked
    }

    /// Look up a tip by id. Used for previews and deep links.
    func tip(id: String) -> CoachingTip? {
        tips.first { $0.id == id }
    }

    // MARK: - Recency tracking

    func recentlyShown() -> [String] {
        userDefaults.array(forKey: recentlyShownKey) as? [String] ?? []
    }

    func recordShown(_ id: String) {
        var list = recentlyShown()
        list.removeAll { $0 == id }
        list.append(id)
        if list.count > recencyWindow {
            list.removeFirst(list.count - recencyWindow)
        }
        userDefaults.set(list, forKey: recentlyShownKey)
    }

    func clearRecentlyShown() {
        userDefaults.removeObject(forKey: recentlyShownKey)
    }
}
