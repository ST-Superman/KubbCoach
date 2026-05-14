//
//  CompetitionSettingsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//
//  Settings redesign — dark Kubb.hero countdown card + editable details card
//  + schedule card with destructive clear button. Save / clear / widget-data
//  update logic preserved verbatim.
//

import SwiftUI
import SwiftData
import OSLog

struct CompetitionSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [CompetitionSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]
    @Query(
        filter: #Predicate<GameSession> { $0.completedAt != nil },
        sort: \GameSession.createdAt, order: .reverse
    ) private var gameSessions: [GameSession]
    @Query(
        filter: #Predicate<PressureCookerSession> { $0.completedAt != nil },
        sort: \PressureCookerSession.createdAt, order: .reverse
    ) private var pcSessions: [PressureCookerSession]

    @State private var competitionDate: Date = Date()
    @State private var competitionName: String = ""
    @State private var competitionLocation: String = ""
    @State private var hasCompetitionSet: Bool = false
    @State private var showingSaveConfirmation: Bool = false
    @State private var showingClearConfirmation: Bool = false

    private var settings: CompetitionSettings? {
        settingsQuery.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if hasCompetitionSet {
                    heroCountdown
                        .padding(.horizontal, 16)

                    detailsCard
                        .padding(.horizontal, 16)
                }

                scheduleCard
                    .padding(.horizontal, 16)
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Competition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveSettings()
                } label: {
                    Text("Save")
                        .font(KubbFont.inter(16, weight: .semibold))
                        .foregroundStyle(Color.Kubb.swedishBlue)
                }
            }
        }
        .onAppear {
            loadSettings()
        }
        .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your next competition has been saved.")
        }
        .alert("Clear Competition?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCompetition()
            }
        } message: {
            Text("This will remove the competition countdown from your home screen.")
        }
    }

    // MARK: - Hero countdown

    private var heroCountdown: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [Color.Kubb.swedishGold.opacity(0.25), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 220
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                Text("NEXT COMPETITION · IN")
                    .font(KubbFont.mono(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.55))

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(daysUntilCompetition)")
                        .font(KubbFont.fraunces(88, weight: .medium, italic: true))
                        .tracking(-3)
                        .foregroundStyle(Color.Kubb.swedishGold)
                    Text(daysUntilCompetition == 1 ? "day" : "days")
                        .font(KubbFont.fraunces(26, weight: .regular))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayedName)
                        .font(KubbFont.fraunces(20, weight: .medium))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                    Text(locationAndDateMono)
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.white.opacity(0.60))
                }

                statusPill
                    .padding(.top, 4)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.hero)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private var statusText: String {
        switch daysUntilCompetition {
        case 0:           return "TODAY IS THE DAY"
        case 1:           return "TOMORROW — FINAL PREPARATIONS"
        case 2...7:       return "LESS THAN A WEEK TRAINING WINDOW"
        default:          return "KEEP TRAINING CONSISTENTLY"
        }
    }

    private var statusDotColor: Color {
        switch daysUntilCompetition {
        case 0...3: return Color.Kubb.swedishGold
        case 4...7: return Color.Kubb.swedishGold
        default:    return Color.Kubb.forestGreen
        }
    }

    private var displayedName: String {
        competitionName.isEmpty ? "Upcoming competition" : competitionName
    }

    private var locationAndDateMono: String {
        let dateString = competitionDate.formatted(.dateTime.month(.abbreviated).day()).uppercased()
        if competitionLocation.isEmpty {
            return dateString
        }
        return "\(competitionLocation.uppercased()) · \(dateString)"
    }

    // MARK: - Details card (editable)

    private var detailsCard: some View {
        SettingsCard {
            DateRow(
                icon: "calendar",
                tint: Color.Kubb.swedishBlue,
                label: "Date",
                date: $competitionDate
            )
            TextFieldRow(
                icon: "tag.fill",
                tint: Color.Kubb.phaseGT,
                label: "Name",
                placeholder: "Optional",
                text: $competitionName
            )
            TextFieldRow(
                icon: "mappin.circle.fill",
                tint: Color.Kubb.forestGreen,
                label: "Location",
                placeholder: "Optional",
                text: $competitionLocation
            )
        }
    }

    // MARK: - Schedule card

    private var scheduleCard: some View {
        VStack(spacing: 0) {
            SettingsToggle(
                icon: "calendar.badge.clock",
                tint: Color.Kubb.swedishGold,
                label: "Track this competition",
                detail: nil,
                isOn: $hasCompetitionSet
            )

            if hasCompetitionSet {
                Rectangle()
                    .fill(Color.Kubb.sep)
                    .frame(height: 0.5)
                    .padding(.leading, 60)

                Button {
                    showingClearConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Clear competition")
                            .font(KubbFont.inter(15, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(Color.Kubb.phasePC)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }

    // MARK: - Helper Methods (UNCHANGED — copy preserved verbatim)

    private func loadSettings() {
        guard let settings = settings else {
            let newSettings = CompetitionSettings()
            modelContext.insert(newSettings)
            return
        }

        if let date = settings.nextCompetitionDate {
            hasCompetitionSet = true
            competitionDate = date
        } else {
            hasCompetitionSet = false
            competitionDate = Date()
        }

        competitionName = settings.competitionName ?? ""
        competitionLocation = settings.competitionLocation ?? ""
    }

    private func saveSettings() {
        let settingsToUpdate: CompetitionSettings

        if let existing = settings {
            settingsToUpdate = existing
        } else {
            let newSettings = CompetitionSettings()
            modelContext.insert(newSettings)
            settingsToUpdate = newSettings
        }

        if hasCompetitionSet {
            settingsToUpdate.nextCompetitionDate = competitionDate
            settingsToUpdate.competitionName = competitionName.isEmpty ? nil : competitionName
            settingsToUpdate.competitionLocation = competitionLocation.isEmpty ? nil : competitionLocation
        } else {
            settingsToUpdate.nextCompetitionDate = nil
            settingsToUpdate.competitionName = nil
            settingsToUpdate.competitionLocation = nil
        }

        do {
            try modelContext.save()
            HapticFeedbackService.shared.success()
            showingSaveConfirmation = true
            updateWidgetData()
        } catch {
            AppLogger.general.error("Failed to save competition settings: \(error.localizedDescription)")
        }
    }

    private func clearCompetition() {
        hasCompetitionSet = false
        competitionName = ""
        competitionLocation = ""
        saveSettings()
    }

    private var daysUntilCompetition: Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: competitionDate)
        return max(0, components.day ?? 0)
    }

    private func updateWidgetData() {
        let sessionItems = sessions.map { SessionDisplayItem.local($0) }
        let streak = StreakCalculator.currentStreak(
            from: sessionItems,
            gameSessions: gameSessions,
            pcSessions: pcSessions
        )
        let daysUntil = hasCompetitionSet ? settings?.daysUntilCompetition : nil
        let name = hasCompetitionSet ? (competitionName.isEmpty ? nil : competitionName) : nil
        let today = Calendar.current.startOfDay(for: Date())
        let trainedToday = sessions.contains {
            $0.completedAt != nil && Calendar.current.startOfDay(for: $0.createdAt) == today
        }

        WidgetDataService.shared.saveWidgetData(
            streak: streak,
            daysUntilCompetition: daysUntil,
            competitionName: name,
            trainedToday: trainedToday
        )
    }
}

// MARK: - DateRow

private struct DateRow: View {
    let icon: String
    let tint: Color
    let label: String
    @Binding var date: Date

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(KubbFont.inter(15, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(Color.Kubb.text)

            Spacer(minLength: 8)

            DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

// MARK: - TextFieldRow

private struct TextFieldRow: View {
    let icon: String
    let tint: Color
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(KubbFont.inter(15, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(Color.Kubb.text)

            Spacer(minLength: 8)

            TextField(placeholder, text: $text)
                .font(KubbFont.inter(14))
                .foregroundStyle(Color.Kubb.text)
                .multilineTextAlignment(.trailing)
                .autocapitalization(.words)
                .frame(maxWidth: 180)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

#Preview {
    NavigationStack {
        CompetitionSettingsView()
            .modelContainer(for: [CompetitionSettings.self], inMemory: true)
    }
}
