//
//  EmailReportSettingsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/2/26.
//

import SwiftUI
import SwiftData

/// Settings view for configuring email progress reports
struct EmailReportSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [EmailReportSettings]

    @State private var emailAddress: String = ""
    @State private var selectedFrequency: ReportFrequency = .weekly
    @State private var isEnabled: Bool = false
    @State private var showingSaveConfirmation: Bool = false

    private var settings: EmailReportSettings? {
        settingsQuery.first
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Email Reports", isOn: $isEnabled)
                    .tint(KubbColors.swedishBlue)
            } footer: {
                Text("Receive weekly progress reports and training reminders via email")
            }

            if isEnabled {
                Section {
                    TextField("your@email.com", text: $emailAddress)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Email Address")
                } footer: {
                    Text("Enter the email address where you'd like to receive reports")
                }

                Section {
                    Picker("Send reports", selection: $selectedFrequency) {
                        ForEach(ReportFrequency.allCases) { frequency in
                            Text(frequency.displayName)
                                .tag(frequency)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Frequency")
                } footer: {
                    Text("Choose how often you want to receive training reports")
                }

                if let lastSent = settings?.lastSentAt {
                    Section {
                        HStack {
                            Text("Last Report Sent")
                            Spacer()
                            Text(formatDate(lastSent))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Next Report Due")
                            Spacer()
                            Text(formatDate(nextReportDate(from: lastSent)))
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Report History")
                    }
                }
            }
        }
        .navigationTitle("Email Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveSettings()
                }
                .disabled(!isFormValid)
            }
        }
        .onAppear {
            loadSettings()
        }
        .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your email report settings have been updated")
        }
    }

    // MARK: - Helper Methods

    private func loadSettings() {
        guard let settings = settings else {
            // Create default settings if none exist
            let newSettings = EmailReportSettings()
            modelContext.insert(newSettings)
            return
        }

        emailAddress = settings.email ?? ""
        selectedFrequency = settings.frequency
        isEnabled = settings.isEnabled
    }

    private func saveSettings() {
        let settingsToUpdate: EmailReportSettings

        if let existing = settings {
            settingsToUpdate = existing
        } else {
            let newSettings = EmailReportSettings()
            modelContext.insert(newSettings)
            settingsToUpdate = newSettings
        }

        settingsToUpdate.email = emailAddress.isEmpty ? nil : emailAddress
        settingsToUpdate.frequency = selectedFrequency
        settingsToUpdate.isEnabled = isEnabled

        do {
            try modelContext.save()
            HapticFeedbackService.shared.success()
            showingSaveConfirmation = true
        } catch {
            print("Failed to save email settings: \(error)")
        }
    }

    private var isFormValid: Bool {
        if !isEnabled {
            return true // Can save if disabled
        }
        // If enabled, email must be valid
        return !emailAddress.isEmpty && emailAddress.contains("@")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func nextReportDate(from lastSent: Date) -> Date {
        let days = selectedFrequency.dayInterval
        return Calendar.current.date(byAdding: .day, value: days, to: lastSent) ?? lastSent
    }
}

#Preview {
    NavigationStack {
        EmailReportSettingsView()
            .modelContainer(
                for: [EmailReportSettings.self],
                inMemory: true
            )
    }
}
