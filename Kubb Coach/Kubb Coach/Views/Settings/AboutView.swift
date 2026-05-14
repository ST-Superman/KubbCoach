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
            NavigationLink { WhatsNewPlaceholderView() } label: {
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
            NavigationLink { AcknowledgmentsPlaceholderView() } label: {
                SettingsNavRow(
                    icon: "heart.text.square.fill",
                    tint: Color.Kubb.phaseGT,
                    label: "Acknowledgments"
                )
            }
            NavigationLink { PrivacyPlaceholderView() } label: {
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

private struct WhatsNewPlaceholderView: View {
    var body: some View {
        PlaceholderPage(
            eyebrow: "RELEASE NOTES",
            title: "What's new",
            message: "Release notes will live here in a future update."
        )
        .navigationTitle("What's new")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AcknowledgmentsPlaceholderView: View {
    var body: some View {
        PlaceholderPage(
            eyebrow: "CREDITS",
            title: "Acknowledgments",
            message: "Open-source credits and design dedications will live here."
        )
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPlaceholderView: View {
    var body: some View {
        PlaceholderPage(
            eyebrow: "POLICY",
            title: "Privacy policy",
            message: "Privacy policy will live here in a future update."
        )
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
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
