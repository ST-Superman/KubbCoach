// SessionBriefingView.swift
// Reusable pre-session briefing screen.
// Pattern: gradient hero card (target · last · PB) → rules → coach cue → setup → start button.

import SwiftUI

// MARK: - Theme

struct BriefingTheme {
    let heroColors: [Color]
    let accent: Color
    let ink: Color
    let cueBg: Color
    let cueBadgeBg: Color
    let cueBadgeInk: Color
    let cueCaption: Color

    static let training = BriefingTheme(
        heroColors: [Color(hex: "13254A"), Color(hex: "006AA7")],
        accent: Color(hex: "006AA7"),
        ink: Color(hex: "13254A"),
        cueBg: Color(hex: "FFF7D6"),
        cueBadgeBg: Color(hex: "FECC02"),
        cueBadgeInk: Color(hex: "13254A"),
        cueCaption: Color(hex: "8A6700")
    )

    static let game = BriefingTheme(
        heroColors: [Color(hex: "0F3524"), Color(hex: "1F7A4D")],
        accent: Color(hex: "1F7A4D"),
        ink: Color(hex: "0F3524"),
        cueBg: Color(hex: "E9F5ED"),
        cueBadgeBg: Color(hex: "1F7A4D"),
        cueBadgeInk: .white,
        cueCaption: Color(hex: "0F5A36")
    )

    static let pressure = BriefingTheme(
        heroColors: [Color(hex: "4A1014"), Color(hex: "B3261E")],
        accent: Color(hex: "B3261E"),
        ink: Color(hex: "4A1014"),
        cueBg: Color(hex: "FBEBE9"),
        cueBadgeBg: Color(hex: "B3261E"),
        cueBadgeInk: .white,
        cueCaption: Color(hex: "7A1A15")
    )
}

// MARK: - Config

struct BriefingRule: Identifiable {
    var id = UUID()
    let key: String
    let value: String
}

struct BriefingConfig {
    let theme: BriefingTheme
    let modeLabel: String
    let chip: String
    let title: String
    let tagline: String
    let rules: [BriefingRule]
    let rulesLabel: String
    let coachCue: String
    let startLabel: String

    // MARK: Static configs

    static let inTheRed = BriefingConfig(
        theme: .pressure,
        modeLabel: "PRESSURE · PC",
        chip: "CHALLENGE",
        title: "In the Red",
        tagline: "Late-game perfection — kubbs + king or nothing",
        rules: [
            BriefingRule(key: "Round",   value: "One scenario · knock all kubbs + king"),
            BriefingRule(key: "Scoring", value: "+1 all down · 0 king missed · −1 any kubb left"),
            BriefingRule(key: "Session", value: "5 or 10 rounds · perfect game = +10"),
            BriefingRule(key: "Order",   value: "Field kubbs first · then baseline · then king"),
        ],
        rulesLabel: "THE CHALLENGE",
        coachCue: "Late game perfection",
        startLabel: "Accept Challenge"
    )

    static let threeForThree = BriefingConfig(
        theme: .pressure,
        modeLabel: "PRESSURE · PC",
        chip: "CHALLENGE",
        title: "3-4-3",
        tagline: "Ten kubbs, three groups, cleared in order",
        rules: [
            BriefingRule(key: "Setup",   value: "Inkast 3+4+3 kubbs across three baseline stakes"),
            BriefingRule(key: "Batons",  value: "6 batons shared across all three groups"),
            BriefingRule(key: "Order",   value: "Clear each group before moving to the next"),
            BriefingRule(key: "Score",   value: "1 pt per kubb + bonus batons if all 10 cleared"),
            BriefingRule(key: "Max",     value: "13 pts per frame · 10 frames · 130 max"),
        ],
        rulesLabel: "THE CHALLENGE",
        coachCue: "Focus on early game inkasting and field efficiency",
        startLabel: "Accept Challenge"
    )

    static let eightMeters = BriefingConfig(
        theme: .training,
        modeLabel: "ACCURACY · TRAINING",
        chip: "DRILL",
        title: "8 Meters",
        tagline: "Accuracy shooting drill from 8 meters",
        rules: [
            BriefingRule(key: "Distance", value: "8 meters from opposite baseline"),
            BriefingRule(key: "Setup",    value: "5 kubbs on opposite baseline"),
            BriefingRule(key: "Batons",   value: "6 per round"),
            BriefingRule(key: "Score",    value: "Hits ÷ total throws"),
            BriefingRule(key: "King",     value: "Clear all 5 with batons to spare? Bonus king throw!"),
        ],
        rulesLabel: "THE DRILL",
        coachCue: "Consistent 8 meter progress is vital to winning",
        startLabel: "Start Drill"
    )

    static let fourMeter = BriefingConfig(
        theme: .training,
        modeLabel: "BLASTING · TRAINING",
        chip: "DRILL",
        title: "4M Blasting",
        tagline: "Golf-scored close-range blasting drill",
        rules: [
            BriefingRule(key: "Rounds",  value: "9 fixed rounds"),
            BriefingRule(key: "Kubbs",   value: "Progressive — 2 to 10 field kubbs"),
            BriefingRule(key: "Batons",  value: "6 per round"),
            BriefingRule(key: "Par",     value: "MIN(kubbs, 6) — match par to score even"),
            BriefingRule(key: "Score",   value: "Total throws used · lower is better"),
        ],
        rulesLabel: "THE DRILL",
        coachCue: "The key is to clear field kubbs while still keeping batons in hand",
        startLabel: "Start Drill"
    )

    static let inkasting = BriefingConfig(
        theme: .training,
        modeLabel: "PLACEMENT · TRAINING",
        chip: "DRILL",
        title: "Inkasting",
        tagline: "Field-kubb placement and clustering drill",
        rules: [
            BriefingRule(key: "Kubbs",  value: "5 or 10 field kubbs inkasted to opposite half"),
            BriefingRule(key: "Photo",  value: "Photograph your kubbs after each round"),
            BriefingRule(key: "Score",  value: "Cluster area in m² — smaller is better"),
            BriefingRule(key: "Focus",  value: "Grouping and consistency, not distance"),
        ],
        rulesLabel: "THE DRILL",
        coachCue: "A tight cluster of inkast kubbs can create pivotal moments in games",
        startLabel: "Start Drill"
    )

    static let phantomGame = BriefingConfig(
        theme: .game,
        modeLabel: "SIMULATION · GAME",
        chip: "GAME",
        title: "Phantom Game",
        tagline: "Solo full-game simulation — play both sides",
        rules: [
            BriefingRule(key: "Format",  value: "Full 15m game · you control both sides"),
            BriefingRule(key: "Field",   value: "Alternating inkasting rounds"),
            BriefingRule(key: "Metrics", value: "Field efficiency & baseline accuracy tracked"),
            BriefingRule(key: "Win",     value: "First side to knock the king"),
        ],
        rulesLabel: "THE GAME",
        coachCue: "Practice makes perfect",
        startLabel: "Start Game"
    )

    static let competitiveMatch = BriefingConfig(
        theme: .game,
        modeLabel: "LIVE · GAME",
        chip: "MATCH",
        title: "Competitive Match",
        tagline: "Log a real match turn by turn",
        rules: [
            BriefingRule(key: "Tracking", value: "Each turn logged live"),
            BriefingRule(key: "Side",     value: "Pick which side you're on — A attacks first"),
            BriefingRule(key: "Scoring",  value: "Standard kubb rules throughout"),
            BriefingRule(key: "Result",   value: "Win/loss + efficiency metrics recorded"),
        ],
        rulesLabel: "THE MATCH",
        coachCue: "Good Luck!",
        startLabel: "Log Match"
    )
}

// MARK: - Main View

struct SessionBriefingView<SetupContent: View>: View {
    let config: BriefingConfig
    var lastValue: String? = nil
    var lastWhen: String? = nil
    var pbValue: String? = nil
    var targetValue: String? = nil
    var setupBadge: String? = nil
    @ViewBuilder var setupContent: () -> SetupContent
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                rulesSection
                    .padding(.horizontal, 16)
                    .padding(.top, 18)

                cueSection
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                setupContent()

                startButton
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
            }
        }
        .background(Color(hex: "EEECE4").ignoresSafeArea())
    }

    // MARK: Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(config.modeLabel)
                        .font(.custom("JetBrainsMono-Bold", size: 9))
                        .kerning(1.6)
                        .foregroundStyle(.white.opacity(0.6))

                    Text(config.title)
                        .font(.custom("Fraunces-MediumItalic", size: 32))
                        .tracking(-1)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(config.tagline)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text(config.chip)
                    .font(.custom("JetBrainsMono-Bold", size: 10))
                    .kerning(0.8)
                    .foregroundStyle(config.theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "FECC02"))
                    .clipShape(Capsule())
            }

            // Stats card
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S TARGET")
                        .font(.custom("JetBrainsMono-Bold", size: 9))
                        .kerning(1.4)
                        .foregroundStyle(.white.opacity(0.65))

                    Text(targetValue ?? "—")
                        .font(.custom("Fraunces-MediumItalic", size: 40))
                        .tracking(-1.4)
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("LAST")
                            .font(.custom("JetBrainsMono-Bold", size: 11))
                            .kerning(0.5)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(lastValue ?? "—")
                            .font(.custom("Fraunces-Medium", size: 18))
                            .tracking(-0.4)
                            .foregroundStyle(.white)
                        if let when = lastWhen {
                            Text(when)
                                .font(.custom("JetBrainsMono-Regular", size: 10))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("PB")
                            .font(.custom("JetBrainsMono-Bold", size: 11))
                            .kerning(0.5)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(pbValue ?? "—")
                            .font(.custom("Fraunces-Medium", size: 18))
                            .tracking(-0.4)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.leading, 14)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.black.opacity(0.22))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color(hex: "FECC02"))
                    .frame(width: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 16)
        }
        .padding(18)
        .background(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .strokeBorder(Color(hex: "FECC02").opacity(0.2), lineWidth: 1)
                    .frame(width: 160, height: 160)
                    .offset(x: 40, y: 40)
                Circle()
                    .strokeBorder(Color(hex: "FECC02").opacity(0.1), lineWidth: 1)
                    .frame(width: 200, height: 200)
                    .offset(x: 60, y: 60)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .background(
            LinearGradient(
                colors: config.theme.heroColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: config.theme.ink.opacity(0.35), radius: 20, y: 10)
    }

    // MARK: Rules

    private var rulesSection: some View {
        VStack(spacing: 8) {
            Text(config.rulesLabel)
                .font(.custom("JetBrainsMono-Bold", size: 10))
                .kerning(1.5)
                .foregroundStyle(config.theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(config.rules.enumerated()), id: \.element.id) { index, rule in
                    if index > 0 {
                        Divider().padding(.horizontal, 16)
                    }
                    HStack(spacing: 12) {
                        Text(rule.key.uppercased())
                            .font(.custom("JetBrainsMono-Bold", size: 11))
                            .kerning(0.4)
                            .foregroundStyle(config.theme.ink.opacity(0.55))
                            .frame(minWidth: 60, alignment: .leading)
                            .fixedSize()

                        Spacer()

                        Text(rule.value)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(config.theme.ink)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 16)
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Coach Cue

    private var cueSection: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(config.theme.cueBadgeBg)
                    .frame(width: 28, height: 28)
                Text("✦")
                    .font(.system(size: 13))
                    .foregroundStyle(config.theme.cueBadgeInk)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("COACH CUE")
                    .font(.custom("JetBrainsMono-Bold", size: 9))
                    .kerning(1.4)
                    .foregroundStyle(config.theme.cueCaption)

                Text(config.coachCue)
                    .font(.custom("Fraunces-MediumItalic", size: 17))
                    .tracking(-0.3)
                    .foregroundStyle(config.theme.ink)
            }

            Spacer()
        }
        .padding(14)
        .background(config.theme.cueBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Start Button

    private var startButton: some View {
        Button(action: onStart) {
            HStack(spacing: 8) {
                Text(config.startLabel)
                    .font(.system(size: 16, weight: .bold))

                if let badge = setupBadge {
                    Text(badge)
                        .font(.custom("JetBrainsMono-Bold", size: 10))
                        .kerning(0.5)
                        .foregroundStyle(config.theme.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "FECC02").opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(config.theme.ink)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: config.theme.ink.opacity(0.3), radius: 12, y: 6)
        }
    }
}

// MARK: - Briefing Picker

/// Pill-style segmented picker styled to match the briefing design.
struct BriefingPicker<Option: Hashable>: View {
    let label: String
    let options: [Option]
    let displayTitle: (Option) -> String
    let isNumeric: Bool
    @Binding var selected: Option
    let theme: BriefingTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("JetBrainsMono-Bold", size: 10))
                .kerning(1.5)
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 4)

            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selected
                    Button { selected = option } label: {
                        Text(displayTitle(option))
                            .font(isNumeric
                                ? .custom("Fraunces-Medium", size: 20)
                                : .custom("Fraunces-MediumItalic", size: 14))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isNumeric ? 14 : 13)
                            .background(isSelected ? theme.ink : Color.white)
                            .foregroundStyle(isSelected ? Color.white : theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        isSelected ? Color.clear : Color(UIColor.separator),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: isSelected ? theme.ink.opacity(0.28) : .clear,
                                radius: 6, y: 3
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
