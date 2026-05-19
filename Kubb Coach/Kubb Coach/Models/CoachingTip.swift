//
//  CoachingTip.swift
//  Kubb Coach
//
//  Curated coaching tips with source attribution. Loaded from the bundled
//  `CoachingTips.json` resource by `CoachingTipsService`.
//

import Foundation

struct CoachingTip: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let category: TipCategory
    let subcategory: String?
    let body: String
    let quote: String?
    let attributionShort: String
    let attributionLong: String
    let sourceTitle: String
    let sourceURL: URL?
    let tags: [String]
}

enum TipCategory: String, Codable, CaseIterable, Hashable {
    case eightMeter
    case fourMeter
    case inkasting
    case mental
    case practiceDrill
    case general

    /// Unknown JSON values decode to `.general` so the app degrades gracefully
    /// when new categories ship in `CoachingTips.json` ahead of a Swift change.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TipCategory(rawValue: raw) ?? .general
    }

    /// Map a training phase to the most relevant tip category for that surface.
    static func from(phase: TrainingPhase) -> TipCategory {
        switch phase {
        case .eightMeters:        return .eightMeter
        case .fourMetersBlasting: return .fourMeter
        case .inkastingDrilling:  return .inkasting
        case .pressureCooker:     return .fourMeter
        case .gameTracker:        return .general
        }
    }
}

/// Top-level shape of `CoachingTips.json`.
struct CoachingTipsLibrary: Codable {
    let version: Int
    let lastCurated: String?
    let tips: [CoachingTip]
}
