//
//  TrainingSettingsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//
//  Settings redesign — visualization card + Fraunces value row + slider +
//  Display Units card. Auto-saves on slider change.
//

import SwiftUI
import SwiftData

struct TrainingSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]

    @State private var targetRadiusValue: Double = 0.5

    private var currentSettings: InkastingSettings {
        if let existing = settings.first {
            return existing
        } else {
            let newSettings = InkastingSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                TargetRadiusViz(targetRadius: targetRadiusValue)
                    .padding(.horizontal, 16)

                valueRow
                    .padding(.horizontal, 20)

                sliderBlock
                    .padding(.horizontal, 16)

                displayUnitsCard
                    .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Inkasting")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            targetRadiusValue = currentSettings.effectiveTargetRadius
            if currentSettings.targetRadiusMeters == nil {
                currentSettings.targetRadiusMeters = currentSettings.effectiveTargetRadius
                try? modelContext.save()
            }
        }
        .onChange(of: targetRadiusValue) { _, newValue in
            saveSettings(newValue)
        }
    }

    // MARK: - Value row

    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", targetRadiusValue))
                    .font(KubbFont.fraunces(44, weight: .medium))
                    .tracking(-1.5)
                    .foregroundStyle(Color.Kubb.text)
                Text("m")
                    .font(KubbFont.mono(14, weight: .bold))
                    .foregroundStyle(Color.Kubb.textSec)
                    .baselineOffset(8)
            }

            Spacer(minLength: 12)

            Text(descriptionForValue(targetRadiusValue))
                .font(KubbFont.fraunces(14, weight: .regular, italic: true))
                .foregroundStyle(Color.Kubb.forestGreen)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 180, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Slider

    private var sliderBlock: some View {
        VStack(spacing: 10) {
            Slider(value: $targetRadiusValue, in: 0.25...1.0, step: 0.05)
                .tint(Color.Kubb.swedishBlue)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("0.25M")
                        .font(KubbFont.mono(10, weight: .bold))
                        .foregroundStyle(Color.Kubb.text)
                    Text("TIGHT")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textSec)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("1.0M")
                        .font(KubbFont.mono(10, weight: .bold))
                        .foregroundStyle(Color.Kubb.text)
                    Text("LOOSE")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textSec)
                }
            }
        }
    }

    // MARK: - Display Units

    private var displayUnitsCard: some View {
        VStack(spacing: 0) {
            SettingsToggle(
                icon: "ruler.fill",
                tint: Color.Kubb.swedishBlue,
                label: "Use imperial units",
                detail: nil,
                isOn: Binding(
                    get: { currentSettings.useImperialUnits },
                    set: { newValue in
                        currentSettings.useImperialUnits = newValue
                        currentSettings.lastModified = Date()
                        try? modelContext.save()
                    }
                )
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(currentSettings.useImperialUnits
                     ? "Distances in feet · areas in sq ft."
                     : "Distances in meters · areas in sq m.")
                    .font(KubbFont.inter(13))
                    .foregroundStyle(Color.Kubb.textSec)

                Text("Pitch distances always remain in meters — they're regulation.")
                    .font(KubbFont.inter(12))
                    .foregroundStyle(Color.Kubb.textTer)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    // MARK: - Helpers

    private func descriptionForValue(_ value: Double) -> String {
        switch value {
        case ..<0.35:    return "Very challenging — exceptional precision."
        case 0.35..<0.5: return "Challenging — for advanced players."
        case 0.5..<0.65: return "Balanced — good technique territory."
        case 0.65..<0.8: return "Moderate — developing consistency."
        default:         return "Forgiving — great for beginners."
        }
    }

    private func saveSettings(_ newValue: Double) {
        currentSettings.targetRadiusMeters = newValue
        currentSettings.lastModified = Date()
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        TrainingSettingsView()
            .modelContainer(for: InkastingSettings.self, inMemory: true)
    }
}
