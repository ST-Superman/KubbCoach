// AboutView.swift
// Dark "Lodge after dark" hero + 5-row info card + centered editorial footer.
// Version / build read from Bundle.main; "since" is the project's launch year.
//
// "Replay onboarding" routes to TutorialReplayPickerView per the user's
// chosen replay model (tutorial-only — push KubbFieldSetupView for the
// chosen mode without touching the rest of the onboarding coordinator).

import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private let sinceYear = "2026"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                heroCard
                    .padding(.horizontal, 16)

                rowsCard
                    .padding(.horizontal, 16)

                footer
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            // Radial accent at top-right
            RadialGradient(
                colors: [Color.Kubb.swedishBlue.opacity(0.50), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 220
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 18) {
                Text("KUBB · A LAWN GAME · A FILE FORMAT")
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.white.opacity(0.50))

                VStack(alignment: .leading, spacing: -8) {
                    Text("Kubb")
                        .font(KubbFont.fraunces(56, weight: .regular, italic: true))
                        .tracking(-2)
                        .foregroundStyle(Color.Kubb.swedishGold)
                    Text("Coach")
                        .font(KubbFont.fraunces(56, weight: .regular, italic: true))
                        .tracking(-2)
                        .foregroundStyle(Color.Kubb.swedishGold)
                }

                Text("A practice journal for the world's finest stick-throwing game.")
                    .font(KubbFont.fraunces(15, weight: .regular, italic: true))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                HStack(alignment: .top, spacing: 24) {
                    stamp(label: "VERSION", value: version)
                    stamp(label: "BUILD",   value: build)
                    stamp(label: "SINCE",   value: sinceYear)
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.hero)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private func stamp(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.white.opacity(0.50))
            Text(value)
                .font(KubbFont.fraunces(24, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Rows card

    private var rowsCard: some View {
        SettingsCard {
            NavigationLink { WhatsNewView() } label: {
                SettingsNavRow(
                    icon: "sparkles",
                    tint: Color.Kubb.forestGreen,
                    label: "What's new",
                    detail: "Read release notes"
                )
            }
            NavigationLink { TutorialReplayPickerView() } label: {
                SettingsNavRow(
                    icon: "play.circle.fill",
                    tint: Color.Kubb.phase4m,
                    label: "Replay onboarding"
                )
            }
            NavigationLink { AcknowledgmentsView() } label: {
                SettingsNavRow(
                    icon: "heart.text.square.fill",
                    tint: Color.Kubb.phaseGT,
                    label: "Acknowledgments"
                )
            }
            NavigationLink { PrivacyPolicyView() } label: {
                SettingsNavRow(
                    icon: "lock.shield.fill",
                    tint: Color.Kubb.swedishBlue,
                    label: "Privacy policy"
                )
            }
            ContactRow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Made with stubborn affection in Chicago.\nAny day playing Kubb is a good day.")
                .font(KubbFont.fraunces(13, weight: .regular, italic: true))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.Kubb.textSec)

            Text("© \(sinceYear) KUBB COACH")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textTer)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Contact row (opens mailto:)

private struct ContactRow: View {
    private let contactEmail = "sathomps@gmail.com"

    var body: some View {
        Button {
            if let url = URL(string: "mailto:\(contactEmail)") {
                UIApplication.shared.open(url)
            }
        } label: {
            SettingsRow(
                icon: "envelope.fill",
                tint: Color.Kubb.textSec,
                label: "Contact",
                detail: contactEmail
            ) {
                SettingsChevron()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tutorial replay picker

private struct TutorialReplayPickerView: View {
    @State private var pickedMode: FieldSetupMode?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                InlineNavHeader("Walk through a tutorial.")

                VStack(spacing: 10) {
                    tutorialButton(mode: .eightMeter,
                                   title: "8-meter throwing",
                                   caption: "Standard baseline session")
                    tutorialButton(mode: .blasting,
                                   title: "4-meter blasting",
                                   caption: "Close-range power throws")
                    tutorialButton(mode: .inkasting,
                                   title: "Inkasting",
                                   caption: "Field-throw drilling")
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Replay tutorial")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: Binding(
            get: { pickedMode.map { ModeBox(mode: $0) } },
            set: { pickedMode = $0?.mode }
        )) { box in
            KubbFieldSetupView(mode: box.mode) {
                pickedMode = nil
            }
        }
    }

    private func tutorialButton(mode: FieldSetupMode, title: String, caption: String) -> some View {
        Button { pickedMode = mode } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(mode.color)
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KubbFont.fraunces(20, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                    Text(caption.uppercased())
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textSec)
                }
                Spacer(minLength: 8)
                SettingsChevron()
            }
            .padding(14)
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .kubbCardShadow()
        }
        .buttonStyle(.plain)
    }

    private struct ModeBox: Identifiable {
        let mode: FieldSetupMode
        var id: String {
            switch mode {
            case .eightMeter: return "eightMeter"
            case .blasting:   return "blasting"
            case .inkasting:  return "inkasting"
            }
        }
    }
}

// MARK: - Placeholder destinations
// These pages will be filled in with real content in a later pass; the rows
// themselves are part of the v1 shipping IA so they're wired up here as
// inline-titled stubs.

private struct WhatsNewView: View {
    private let entries: [WhatsNewEntry] = [
        .init(eyebrow: "NEW GAME MODES",
              title: "Pressure Cooker arrives.",
              body: "Two challenges join the rotation. 3-4-3 is a ten-frame clearing drill built for inkasting under pressure. In the Red is a late-game gauntlet where perfection is the only way out."),
        .init(eyebrow: "GAME TRACKER",
              title: "Log full matches, end to end.",
              body: "Track solo Phantom runs or head-to-head Competitive games. Records, share cards, and personal bests grow alongside your training."),
        .init(eyebrow: "ON YOUR WRIST",
              title: "A practice journal on Apple Watch.",
              body: "Game Tracker runs on Apple Watch, with CloudKit sync bringing every session back to the iPhone."),
        .init(eyebrow: "BRIEFINGS",
              title: "A few words before every session.",
              body: "Each of the seven training and game modes opens with a short briefing — what you're about to do, and why it matters."),
        .init(eyebrow: "FOCUS AREAS",
              title: "Tell each phase what you're working on.",
              body: "Your recap, stats, and pro tips all pay attention."),
        .init(eyebrow: "RECAP, REDRAWN",
              title: "An editorial close to every session.",
              body: "Sharper completion screens, accurate round and headline numbers, and pro tips drawn from the world's best kubb players."),
        .init(eyebrow: "CONDITIONS",
              title: "The weather goes with the throws.",
              body: "Each session quietly captures location, wind, and weather at the start. A small snapshot of where and how you played, kept alongside the round-by-round numbers."),
        .init(eyebrow: "A JOURNAL THAT REMEMBERS",
              title: "Notes follow the session.",
              body: "Anything you wrote during a recap now lives on the session detail — editable, reread-able. A new Kubb Journal inside Journey gathers every note you've ever left, filterable by phase."),
        .init(eyebrow: "WEEKLY DIGEST",
              title: "Sunday morning, your week in a letter.",
              body: "An opt-in email summary of the past seven days — sessions logged, streaks held, and what you've been working on."),
        .init(eyebrow: "LODGE · JOURNEY · STATS",
              title: "The whole app, reorganized.",
              body: "A simpler Lodge, a clearer Journey, and a Records tab that finally earns the name. Streaks, counts, and timelines now include every game mode."),
        .init(eyebrow: "WIDGETS",
              title: "Redesigned, dark-mode-aware.",
              body: "New home screen sizes and a layout that actually fits the stats it's showing."),
        .init(eyebrow: "UNDER THE HOOD",
              title: "Sturdier, quieter, faster.",
              body: "A new design system, a new schema, tighter CloudKit sync, and a long list of small fixes that add up to a much sturdier app."),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                hero
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(entries) { entry in
                        entryCard(entry)
                    }
                }
                .padding(.horizontal, 16)

                footer
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("What's new")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [Color.Kubb.swedishBlue.opacity(0.50), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 220
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                Text("RELEASE NOTES · VERSION 2.0")
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.white.opacity(0.50))

                Text("A bigger Lodge.\nNew ways to practice.")
                    .font(KubbFont.fraunces(34, weight: .regular, italic: true))
                    .tracking(-0.5)
                    .foregroundStyle(Color.Kubb.swedishGold)
                    .fixedSize(horizontal: false, vertical: true)

                Text("The same stubborn affection.")
                    .font(KubbFont.fraunces(15, weight: .regular, italic: true))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.top, 2)
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.hero)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private func entryCard(_ entry: WhatsNewEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.eyebrow)
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)

            Text(entry.title)
                .font(KubbFont.fraunces(22, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(entry.body)
                .font(KubbFont.inter(15))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    private var footer: some View {
        Text("Any day playing Kubb is a good day.")
            .font(KubbFont.fraunces(13, weight: .regular, italic: true))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.Kubb.textSec)
            .frame(maxWidth: .infinity)
    }
}

private struct WhatsNewEntry: Identifiable {
    let eyebrow: String
    let title: String
    let body: String
    var id: String { eyebrow }
}

private struct AcknowledgmentsView: View {
    private let people: [AckPerson] = [
        .init(name: "Tyler Murchie",
              note: "For introducing me to this great game, and for throwing alongside me as part of Kubb Your Enthusiasm."),
        .init(name: "George Sloan",
              note: "For hosting some great tournaments in Batavia, IL, and for encouraging me to keep developing this app."),
    ]

    private let sources: [AckSource] = [
        .init(label: "blacklabelbilliards.com",
              url: "https://blacklabelbilliards.com/blogs/blog/how-to-play-kubb"),
        .init(label: "elakaioutdoor.com",
              url: "https://elakaioutdoor.com/blogs/lifestyle/mastering-kubb-the-ultimate-guide-to-winning-strategies"),
        .init(label: "freshhobby.com",
              url: "https://freshhobby.com/how-to-play-kubb/"),
        .init(label: "funattic.com",
              url: "https://funattic.com/kubb-game-and-rules-guide/"),
        .init(label: "kangjiegardengame.com",
              url: "https://kangjiegardengame.com/kubb-strategies-and-tips-wanna-crush-your-opponents/"),
        .init(label: "kubb.info",
              url: "https://www.kubb.info/5-tips-to-always-win-with-kubb/"),
        .init(label: "kubbon.com",
              url: "https://kubbon.com"),
        .init(label: "tyrstrekubb.com",
              url: "https://www.tyrstrekubb.com/tips-rules"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                hero
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(people) { person in
                        personCard(person)
                    }
                }
                .padding(.horizontal, 16)

                sourcesCard
                    .padding(.horizontal, 16)

                footer
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [Color.Kubb.swedishBlue.opacity(0.50), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 220
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                Text("CREDITS · GRATITUDE")
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.white.opacity(0.50))

                Text("No one throws alone.")
                    .font(KubbFont.fraunces(34, weight: .regular, italic: true))
                    .tracking(-0.5)
                    .foregroundStyle(Color.Kubb.swedishGold)
                    .fixedSize(horizontal: false, vertical: true)

                Text("A few of the people and places that helped this app exist.")
                    .font(KubbFont.fraunces(15, weight: .regular, italic: true))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.hero)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private func personCard(_ person: AckPerson) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WITH THANKS")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)

            Text(person.name)
                .font(KubbFont.fraunces(22, weight: .medium))
                .foregroundStyle(Color.Kubb.text)

            Text(person.note)
                .font(KubbFont.inter(15))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRO TIPS · SOURCES")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)

            Text("Tips drawn from the web.")
                .font(KubbFont.fraunces(22, weight: .medium))
                .foregroundStyle(Color.Kubb.text)

            Text("Strategy, technique, and lore borrowed from the kubb community online:")
                .font(KubbFont.inter(15))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sources.enumerated()), id: \.element.id) { idx, source in
                    sourceRow(source)
                    if idx < sources.count - 1 {
                        Divider().background(Color.Kubb.textTer.opacity(0.2))
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    private func sourceRow(_ source: AckSource) -> some View {
        Button {
            if let url = URL(string: source.url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Text(source.label)
                    .font(KubbFont.inter(15, weight: .medium))
                    .foregroundStyle(Color.Kubb.text)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Kubb.textTer)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Text("Any day playing Kubb is a good day.")
            .font(KubbFont.fraunces(13, weight: .regular, italic: true))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.Kubb.textSec)
            .frame(maxWidth: .infinity)
    }
}

private struct AckPerson: Identifiable {
    let name: String
    let note: String
    var id: String { name }
}

private struct AckSource: Identifiable {
    let label: String
    let url: String
    var id: String { label }
}

private struct PrivacyPolicyView: View {
    private let contactEmail = "sathomps@gmail.com"
    private let effectiveDate = "May 20, 2026"

    private let sections: [PrivacySection] = [
        .init(eyebrow: "WHAT WE COLLECT",
              title: "Your practice, and almost nothing else.",
              body: "Kubb Coach records the training sessions and games you create — throws, hits, scores, durations, goals, milestones, and personal bests. There are no accounts to sign up for, no sign-in, and no profile. The app does not ask for your name, location, contacts, microphone, or health data."),

        .init(eyebrow: "WHERE IT LIVES",
              title: "On your device. Optionally in your iCloud.",
              body: "Session data is stored locally on your iPhone, iPad, and Apple Watch. If you are signed into iCloud, the app uses Apple's CloudKit to sync your data between your own Apple devices through your private iCloud container. Your data is not stored on any server operated by Kubb Coach, and it is not visible to the developer."),

        .init(eyebrow: "PHOTOS",
              title: "Inkasting analysis runs on the device.",
              body: "When you use the inkasting photo analysis feature, the app uses the camera or your photo library to capture an image of your kubbs. The image is analyzed entirely on-device using Apple's Vision framework. Photos are not uploaded to any server, and no images leave your device unless you explicitly share them."),

        .init(eyebrow: "EMAIL & SHARING",
              title: "Nothing leaves until you send it.",
              body: "Email reports and share cards are composed on the device and only sent when you tap the send or share button. The app does not send anything in the background on your behalf."),

        .init(eyebrow: "THIRD PARTIES",
              title: "No analytics. No trackers. No ads.",
              body: "Kubb Coach does not include third-party analytics, advertising, crash reporting, or tracking SDKs. Nothing about your usage is sent to any third-party service."),

        .init(eyebrow: "CHILDREN",
              title: "Not directed at children under 13.",
              body: "Kubb Coach is not intended for children under the age of 13, and the app does not knowingly collect personal information from anyone in that age group."),

        .init(eyebrow: "CHANGES",
              title: "If anything changes, this page changes too.",
              body: "If a future version of the app changes how data is handled, this policy will be updated and the effective date below will be revised."),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                hero
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(sections) { section in
                        sectionCard(section)
                    }
                    contactCard
                }
                .padding(.horizontal, 16)

                footer
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [Color.Kubb.swedishBlue.opacity(0.50), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 220
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                Text("PRIVACY · KUBB COACH")
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.white.opacity(0.50))

                Text("Your practice stays yours.")
                    .font(KubbFont.fraunces(34, weight: .regular, italic: true))
                    .tracking(-0.5)
                    .foregroundStyle(Color.Kubb.swedishGold)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Kubb Coach is a personal practice journal. It is built to work on your device, with your iCloud, and nothing else.")
                    .font(KubbFont.fraunces(15, weight: .regular, italic: true))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.hero)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private func sectionCard(_ section: PrivacySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.eyebrow)
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)

            Text(section.title)
                .font(KubbFont.fraunces(22, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(section.body)
                .font(KubbFont.inter(15))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUESTIONS")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textSec)

            Text("Get in touch.")
                .font(KubbFont.fraunces(22, weight: .medium))
                .foregroundStyle(Color.Kubb.text)

            Text("If you have a question about this policy or how your data is handled, send a note:")
                .font(KubbFont.inter(15))
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Button {
                if let url = URL(string: "mailto:\(contactEmail)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.Kubb.swedishBlue)
                    Text(contactEmail)
                        .font(KubbFont.inter(15, weight: .medium))
                        .foregroundStyle(Color.Kubb.text)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Kubb.textTer)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("EFFECTIVE \(effectiveDate.uppercased())")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textTer)
            Text("Any day playing Kubb is a good day.")
                .font(KubbFont.fraunces(13, weight: .regular, italic: true))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.Kubb.textSec)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PrivacySection: Identifiable {
    let eyebrow: String
    let title: String
    let body: String
    var id: String { eyebrow }
}

private struct PlaceholderPage: View {
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(eyebrow)
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(Color.Kubb.textSec)
                Text(title)
                    .font(KubbFont.fraunces(28, weight: .medium))
                    .foregroundStyle(Color.Kubb.text)
                Text(message)
                    .font(KubbFont.inter(15))
                    .foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.paper.ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
