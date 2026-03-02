//
//  CompetitionSettingsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import SwiftData

/// Settings view for configuring upcoming competition details
struct CompetitionSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [CompetitionSettings]

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
        Form {
            Section {
                Toggle("Set Competition Date", isOn: $hasCompetitionSet)
                    .tint(KubbColors.swedishBlue)
            } footer: {
                Text("Track an upcoming competition to stay motivated and focused on your training goals")
            }

            if hasCompetitionSet {
                Section("Competition Details") {
                    DatePicker(
                        "Date",
                        selection: $competitionDate,
                        in: Date()...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)

                    TextField("Name (optional)", text: $competitionName)
                        .autocapitalization(.words)

                    TextField("Location (optional)", text: $competitionLocation)
                        .autocapitalization(.words)
                }

                Section("Countdown") {
                    HStack {
                        Text("Days Remaining")
                        Spacer()
                        Text("\(daysUntilCompetition)")
                            .font(.headline)
                            .foregroundStyle(daysRemainingColor)
                    }

                    if daysUntilCompetition == 0 {
                        Text("Today is the day! Good luck!")
                            .font(.subheadline)
                            .foregroundStyle(KubbColors.swedishGold)
                    } else if daysUntilCompetition == 1 {
                        Text("Tomorrow! Final preparations!")
                            .font(.subheadline)
                            .foregroundStyle(KubbColors.phase4m)
                    } else if daysUntilCompetition <= 7 {
                        Text("Less than a week to go!")
                            .font(.subheadline)
                            .foregroundStyle(KubbColors.phase4m)
                    } else {
                        Text("Keep training consistently!")
                            .font(.subheadline)
                            .foregroundStyle(KubbColors.forestGreen)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Clear Competition")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Remove the competition from your home screen")
                }
            }
        }
        .navigationTitle("Competition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveSettings()
                }
            }
        }
        .onAppear {
            loadSettings()
        }
        .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your competition has been saved")
        }
        .alert("Clear Competition?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCompetition()
            }
        } message: {
            Text("This will remove the competition countdown from your home screen")
        }
    }

    // MARK: - Helper Methods

    private func loadSettings() {
        guard let settings = settings else {
            // Create default settings if none exist
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
        } catch {
            print("Failed to save competition settings: \(error)")
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

    private var daysRemainingColor: Color {
        switch daysUntilCompetition {
        case 0...3:
            return KubbColors.phase4m
        case 4...7:
            return KubbColors.swedishGold
        default:
            return KubbColors.forestGreen
        }
    }
}

#Preview {
    NavigationStack {
        CompetitionSettingsView()
            .modelContainer(
                for: [CompetitionSettings.self],
                inMemory: true
            )
    }
}
