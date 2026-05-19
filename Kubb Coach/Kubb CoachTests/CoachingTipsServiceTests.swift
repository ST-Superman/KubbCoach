//
//  CoachingTipsServiceTests.swift
//  Kubb CoachTests
//

import Testing
import Foundation
@testable import Kubb_Coach

@Suite("CoachingTipsService Tests")
struct CoachingTipsServiceTests {

    private func makeService(suiteName: String = UUID().uuidString) -> (CoachingTipsService, UserDefaults) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let service = CoachingTipsService(userDefaults: defaults, bundle: .main)
        return (service, defaults)
    }

    // MARK: - Loading

    @Test("Loads tips from bundled CoachingTips.json")
    func loadsBundledTips() {
        let (service, _) = makeService()
        #expect(service.tips.isEmpty == false, "CoachingTips.json should ship in the app bundle")
        #expect(service.tips.count >= 40, "Curated library should contain at least 40 tips")
    }

    @Test("Every loaded tip has required fields populated")
    func tipsHaveRequiredFields() {
        let (service, _) = makeService()
        for tip in service.tips {
            #expect(tip.id.isEmpty == false, "Tip id must not be empty")
            #expect(tip.body.isEmpty == false, "Tip body must not be empty")
            #expect(tip.attributionShort.isEmpty == false, "attributionShort required for inline display")
            #expect(tip.attributionLong.isEmpty == false, "attributionLong required for source sheet")
            #expect(tip.sourceTitle.isEmpty == false, "sourceTitle required for source sheet")
        }
    }

    @Test("Tip ids are unique across the library")
    func tipIdsAreUnique() {
        let (service, _) = makeService()
        let ids = service.tips.map(\.id)
        let unique = Set(ids)
        #expect(ids.count == unique.count, "Duplicate tip ids would break recency tracking")
    }

    @Test("Every category has at least one tip")
    func everyCategoryHasTips() {
        let (service, _) = makeService()
        for category in TipCategory.allCases {
            let pool = service.tips.filter { $0.category == category }
            #expect(pool.isEmpty == false, "Category \(category) has no tips — integration surfaces will show nothing")
        }
    }

    @Test("Tip bodies stay under 280 characters for in-card display")
    func tipBodiesAreShortEnough() {
        let (service, _) = makeService()
        for tip in service.tips {
            #expect(tip.body.count <= 280, "Tip \(tip.id) body is \(tip.body.count) chars — too long for card")
        }
    }

    // MARK: - Selection

    @Test("tip(for:) returns a tip matching the requested category")
    func tipForCategoryMatches() {
        let (service, _) = makeService()
        let pick = service.tip(for: .inkasting, excludingRecent: false)
        #expect(pick != nil)
        #expect(pick?.category == .inkasting)
    }

    @Test("tip(id:) round-trips a known id")
    func tipByIdRoundTrips() {
        let (service, _) = makeService()
        guard let first = service.tips.first else {
            Issue.record("No tips loaded")
            return
        }
        let found = service.tip(id: first.id)
        #expect(found == first)
    }

    // MARK: - Recency

    @Test("recordShown adds an id to recently-shown")
    func recordShownAddsId() {
        let (service, _) = makeService()
        service.clearRecentlyShown()
        service.recordShown("test-tip-1")
        #expect(service.recentlyShown().contains("test-tip-1"))
    }

    @Test("Recently-shown list caps at the recency window")
    func recencyListCaps() {
        let (service, _) = makeService()
        service.clearRecentlyShown()
        for i in 0..<25 {
            service.recordShown("tip-\(i)")
        }
        let recent = service.recentlyShown()
        #expect(recent.count <= 10, "Recency window should cap the list at 10")
        // The most recent additions should be retained.
        #expect(recent.contains("tip-24"))
        #expect(recent.contains("tip-23"))
        // Oldest should be evicted.
        #expect(recent.contains("tip-0") == false)
    }

    @Test("Selection prefers tips not in the recently-shown list")
    func selectionPrefersUnseen() {
        let (service, _) = makeService()
        service.clearRecentlyShown()

        let pool = service.tips.filter { $0.category == .eightMeter }
        guard pool.count >= 2 else {
            Issue.record("Need at least 2 eightMeter tips to test recency preference")
            return
        }

        // Mark all but one as recently shown.
        let preserved = pool.last!
        for tip in pool.dropLast() {
            service.recordShown(tip.id)
        }

        let picked = service.tip(for: .eightMeter)
        #expect(picked?.id == preserved.id, "Should select the only tip not in the recent list")
    }

    @Test("Selection still returns a tip when all are recently shown")
    func selectionFallsBackWhenAllSeen() {
        let (service, _) = makeService()
        service.clearRecentlyShown()
        let pool = service.tips.filter { $0.category == .general }
        for tip in pool {
            service.recordShown(tip.id)
        }
        let picked = service.tip(for: .general)
        #expect(picked != nil, "Service must always return a tip if the pool is non-empty")
    }

    @Test("Recording the same id twice does not duplicate entries")
    func recordShownDeduplicates() {
        let (service, _) = makeService()
        service.clearRecentlyShown()
        service.recordShown("dup-id")
        service.recordShown("dup-id")
        let recent = service.recentlyShown()
        #expect(recent.filter { $0 == "dup-id" }.count == 1)
    }
}
