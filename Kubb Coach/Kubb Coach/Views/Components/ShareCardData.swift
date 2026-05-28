//
//  ShareCardData.swift
//  Kubb Coach
//
//  Value type that drives the magazine-layout share card. Every session
//  type (8m / 4m / Inkasting / Game Tracker) builds one of these via its
//  own `shareCardData(...)` extension; `ShareCardView` renders it.
//
//  Layout reference: design_handoff_share_image/README.md
//  Canvas:   1080 × 1350
//  Bands:    Swedish-blue masthead → cream paper feature → midnight footer
//

import SwiftUI

struct ShareCardData {
    /// Big hero stat above the pull quote.
    let hero: ShareCardHero

    /// Red eyebrow above the hero (e.g. "FEATURE · ACCURACY").
    let heroEyebrow: String

    /// Two-line italic pull quote. Optional — modes can opt out.
    let pullQuote: ShareCardPullQuote?

    /// Always 4 cells. Mappers pad with date / drill cells when needed.
    let statCells: [ShareCardStatCell]

    /// Masthead tagline middle segment (e.g. "SOLO PRACTICE", "GAME TRACKER").
    let taglineSegment: String

    /// Monotonic-feeling issue number. Hash-fallback if no real counter exists.
    let issueNumber: Int

    /// Personal bests achieved this session (used by cell 4 + pull-quote bucketing).
    let personalBests: [PersonalBest]

    /// Date stamp — masthead meta + "PLAYED" fallback cell.
    let date: Date
}

// MARK: - Hero

/// The big italic Fraunces number above the pull quote.
/// Each case carries its own size + suffix treatment because the visual
/// proportions of a 3-digit percentage, a signed integer, and a measurement
/// with a unit are different enough that one schema can't serve all.
enum ShareCardHero {
    /// 8m + GT. Decimal percent, e.g. 46.7 → "46.7" + small italic "%".
    /// Drops trailing `.0` (50.0 → "50"). Adaptive font: 3-digit integers
    /// drop from 340pt → 300pt so "100" still fits.
    case bigDecimalPercent(value: Double)

    /// 4m. Signed integer par delta, e.g. -3 → "−3" + small "pts".
    /// Always 2-3 glyphs; uses 380pt to compensate for the short string.
    case signedInt(value: Int)

    /// Inkasting. Pre-formatted measurement, e.g. ("0.15", "m").
    /// Number + unit string are separate so the unit can be styled smaller.
    case measurement(value: String, unit: String)
}

// MARK: - Pull quote

struct ShareCardPullQuote {
    let line1: String
    let line2: String
}

// MARK: - Stat cells

struct ShareCardStatCell {
    /// Big italic Fraunces number (e.g. "14/30", "84%", "+3", "DRILL").
    let value: String

    /// Small uppercased mono label below the number (e.g. "KUBBS DOWN").
    let label: String

    /// 8pt color dot to the left of the label.
    let dotColor: Color

    /// Cell-specific styling variant (trophy prefix, date small-caps, etc.).
    let style: Style

    enum Style {
        /// Plain italic number. Default for hits / rounds / streak / field eff.
        case standard
        /// Gold trophy icon prefix, pbInk-colored number. Used for PB cell when present.
        case personalBest
        /// Smaller "PLAYED" date cell — month uppercased, day in italic Fraunces.
        case date
        /// Phantom-game "DRILL" cell — text fills the number slot.
        case drill
    }
}

// MARK: - Share card constants

enum ShareCard {
    static let canvasWidth: CGFloat = 1080
    static let canvasHeight: CGFloat = 1350
    static let appStoreURL = "https://apps.apple.com/us/app/kubb-coach/id6759566850"

    // Footer
    static let pillEyebrow = "· GET KUBB COACH ·"
    static let pillLine1 = "Get Kubb Coach"
    static let pillLine2 = "on iPhone."

    // PB cell label truncation budget (chars after which we ellipsize).
    static let pbLabelMaxChars = 16

    // Hero adaptive font breakpoints.
    // Sizes are tuned so the hero + suffix fit the left column without
    // crashing into the 340pt mascot column. Italic Fraunces is wide;
    // 340pt would overflow ~120pt past the available 572pt for 4-char
    // values like "46.7" / "50.8".
    static let heroBigFontDefault: CGFloat = 260
    static let heroBigFontThreeDigit: CGFloat = 220
    static let heroPercentSuffix: CGFloat = 110
    static let heroSignedIntSize: CGFloat = 320
    static let heroSignedIntSuffix: CGFloat = 70
    static let heroMeasurementSize: CGFloat = 220
    static let heroMeasurementUnit: CGFloat = 80
    static let statNumberFontDefault: CGFloat = 64
    static let statNumberFontLong: CGFloat = 56
    static let statNumberLongThreshold = 6  // char count
}

// MARK: - Pull-quote thresholds (QA-tunable)
//
// Starting points — QA against ~20 historical sessions per mode and adjust.
// Target distributions:
//   8m:  ~20% sharp / ~50% honest / ~25% rough / ~5% PB
//   4m:  bucketing is deterministic from par delta, no tuning needed
//   Ink: target ~40% tight / ~60% loose
//   GT:  ~20% sharp / ~50% honest / ~25% rough / ~5% drill
//

enum EightMeterPullQuoteThreshold {
    static let sharp: Double = 70  // accuracy %
    static let honest: Double = 40
}

enum InkPullQuoteThreshold {
    /// Average cluster radius (meters) at or below which we use the "tucked in" line.
    static let tightRadiusMeters: Double = 0.15
}

enum GTQualityThreshold {
    static let sharpAccuracy: Double = 0.65       // 8m hit rate, 0-1
    static let honestAccuracy: Double = 0.40
    /// Field efficiency in raw kubbs/baton (typical range 0.5–2.5). A ratio
    /// of 1.0 means "one baseline kubb cleared per baton thrown at field" —
    /// solid mid-game performance. Tune after QA.
    static let cleanFieldEff: Double = 1.0
    static let scrappyFieldEff: Double = 0.6
}
