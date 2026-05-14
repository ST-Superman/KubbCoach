// SettingsView.swift
// "Visual Index" Settings menu — Fraunces large title, 2×2 TrainingTile grid
// (Focus Area / Training / Competition / Email Reports), App-list card
// (Sound / Data / Appearance / About), and a dashed Debug placeholder.
//
// Each tile owns its own @Query so values stay fresh on return from a
// subview — no batch fetch in this view.

import SwiftUI
import SwiftData

struct SettingsView: View {
    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return "v\(v)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                SettingsLargeTitle("Settings", eyebrow: appVersion)

                trainingGrid

                appList

                #if DEBUG
                debugPlaceholder
                #endif
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        // Keep `navigationTitle("Settings")` so pushed subviews
        // (Appearance, About, etc.) inherit "Settings" as their back-button
        // label. The principal slot is intentionally emptied so the system
        // inline title doesn't render alongside our custom Fraunces title.
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { EmptyView() }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Training tile grid

    private var trainingGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            NavigationLink { FocusAreaSettingsView() } label: {
                FocusAreaTile()
            }
            NavigationLink { TrainingSettingsView() } label: {
                TrainingRadiusTile()
            }
            NavigationLink { CompetitionSettingsView() } label: {
                CompetitionTile()
            }
            NavigationLink { EmailReportSettingsView() } label: {
                EmailReportsTile()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - App list

    private var appList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsEyebrow("App")
                .padding(.horizontal, 20)

            SettingsCard {
                NavigationLink { SoundSettingsView() } label: {
                    SettingsNavRow(
                        icon: "speaker.wave.2.fill",
                        tint: Color.Kubb.forestGreen,
                        label: "Sound effects"
                    )
                }
                NavigationLink { DataManagementView() } label: {
                    SettingsNavRow(
                        icon: "externaldrive.fill",
                        tint: Color.Kubb.textSec,
                        label: "Data management"
                    )
                }
                NavigationLink { AppearanceSettingsView() } label: {
                    SettingsNavRow(
                        icon: "circle.lefthalf.filled",
                        tint: Color.Kubb.swedishBlue,
                        label: "Appearance"
                    )
                }
                NavigationLink { AboutView() } label: {
                    SettingsNavRow(
                        icon: "info.circle.fill",
                        tint: Color.Kubb.phaseGT,
                        label: "About"
                    )
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Debug placeholder

    #if DEBUG
    private var debugPlaceholder: some View {
        NavigationLink { DebugSettingsView() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEBUG TOOLS")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textSec)
                    Text("Development builds only")
                        .font(KubbFont.inter(14))
                        .foregroundStyle(Color.Kubb.text)
                }
                Spacer()
                SettingsChevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.Kubb.sepStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
    #endif
}

// MARK: - Tile views (each owns its own @Query)

/// Focus Area tile — surfaces the currently-pinned phase, or "Not pinned".
private struct FocusAreaTile: View {
    @Query private var prefs: [FocusAreaPreference]

    private var pinned: FocusAreaPreference? {
        prefs.first(where: { $0.isPinned })
    }

    private var pinnedPhase: TrainingPhase? {
        guard let raw = pinned?.sessionTypeRaw else { return nil }
        return TrainingPhase(rawValue: raw)
    }

    var body: some View {
        if let phase = pinnedPhase {
            TrainingTile(
                title: "Focus Area",
                value: shortName(phase),
                meta: "PINNED",
                tint: tint(for: phase),
                symbol: "pin.fill"
            )
        } else {
            TrainingTile(
                title: "Focus Area",
                value: "Not pinned",
                meta: "FOCUS AREAS",
                tint: Color.Kubb.swedishBlue,
                symbol: "scope"
            )
        }
    }

    private func shortName(_ p: TrainingPhase) -> String {
        switch p {
        case .eightMeters:         return "8 Meters"
        case .fourMetersBlasting:  return "4M Blasting"
        case .inkastingDrilling:   return "Inkasting"
        case .pressureCooker:      return "Pressure Cooker"
        case .gameTracker:         return "Game Tracker"
        }
    }

    private func tint(for p: TrainingPhase) -> Color {
        switch p {
        case .eightMeters:         return Color.Kubb.swedishBlue
        case .fourMetersBlasting:  return Color.Kubb.phase4m
        case .inkastingDrilling:   return Color.Kubb.forestGreen
        case .pressureCooker:      return Color.Kubb.phasePC
        case .gameTracker:         return Color.Kubb.phaseGT
        }
    }
}

/// Training tile — surfaces the current inkasting target radius.
private struct TrainingRadiusTile: View {
    @Query private var settings: [InkastingSettings]

    var body: some View {
        TrainingTile(
            title: "Training",
            value: valueText,
            meta: "TARGET RADIUS",
            tint: Color.Kubb.forestGreen,
            symbol: "scope"
        )
    }

    private var valueText: String {
        // `effectiveTargetRadius` is the single source of truth and handles
        // backward-compat with the deprecated outlier-threshold field.
        guard let radius = settings.first?.effectiveTargetRadius else { return "0.50 m" }
        return String(format: "%.2f m", radius)
    }
}

/// Competition tile — surfaces days-to-comp, or "Not set".
private struct CompetitionTile: View {
    @Query private var settings: [CompetitionSettings]

    private var days: Int? {
        settings.first?.daysUntilCompetition
    }

    var body: some View {
        if let d = days {
            TrainingTile(
                title: "Competition",
                value: countdownText(d),
                meta: countdownMeta(d),
                tint: Color.Kubb.swedishGold,
                symbol: "trophy.fill"
            )
        } else {
            TrainingTile(
                title: "Competition",
                value: "Not set",
                meta: "TBD",
                tint: Color.Kubb.swedishGold,
                symbol: "trophy.fill"
            )
        }
    }

    private func countdownText(_ days: Int) -> String {
        switch days {
        case 0:           return "Today"
        case 1:           return "1 day"
        default:          return "\(days) days"
        }
    }

    private func countdownMeta(_ days: Int) -> String {
        if days < 0 { return "PAST" }
        if days == 0 { return "TODAY" }
        return "NEXT COMP"
    }
}

/// Email Reports tile — surfaces digest frequency, or "Off".
private struct EmailReportsTile: View {
    @Query private var settings: [EmailReportSettings]

    private var current: EmailReportSettings? { settings.first }

    var body: some View {
        TrainingTile(
            title: "Email Reports",
            value: valueText,
            meta: metaText,
            tint: Color.Kubb.phase4m,
            symbol: "envelope.fill"
        )
    }

    private var valueText: String {
        guard let s = current, s.isEnabled else { return "Off" }
        return s.frequency.displayName
    }

    private var metaText: String {
        guard let s = current, s.isEnabled else { return "OFF" }
        return "DIGEST"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [
        FocusAreaPreference.self,
        InkastingSettings.self,
        CompetitionSettings.self,
        EmailReportSettings.self
    ], inMemory: true)
}
