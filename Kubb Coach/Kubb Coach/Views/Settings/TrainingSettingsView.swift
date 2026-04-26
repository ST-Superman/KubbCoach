//
//  TrainingSettingsView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import SwiftData

struct TrainingSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [InkastingSettings]

    // Local state for slider (updates in real-time)
    @State private var targetRadiusValue: Double = 0.5

    // Get or create settings
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
        Form {
            Section {
                Text("Configure how the app analyzes your inkasting throws")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Target Radius") {
                VStack(alignment: .leading, spacing: 16) {
                    // Current value display
                    HStack {
                        Text("Target Radius")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f m", targetRadiusValue))
                            .font(.title3.bold())
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }

                    // Description
                    Text(descriptionForValue(targetRadiusValue))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Slider with labels
                    VStack(spacing: 8) {
                        Slider(value: $targetRadiusValue, in: 0.25...1.0, step: 0.05) {
                            Text("Target Radius")
                        } minimumValueLabel: {
                            VStack {
                                Text("0.25m")
                                    .font(.caption2)
                                Text("Tight")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } maximumValueLabel: {
                            VStack {
                                Text("1.0m")
                                    .font(.caption2)
                                Text("Loose")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(Color.Kubb.swedishBlue)

                        // Preset buttons
                        HStack(spacing: 12) {
                            PresetButton(value: 0.25, label: "Advanced", currentValue: $targetRadiusValue)
                            PresetButton(value: 0.5, label: "Balanced", currentValue: $targetRadiusValue)
                            PresetButton(value: 1.0, label: "Beginner", currentValue: $targetRadiusValue)
                        }
                    }

                    // Visual example
                    OutlierVisualization(targetRadius: targetRadiusValue)
                        .frame(height: 120)
                        .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }

            Section {
                Text("Smaller target radius requires tighter groupings. Larger target radius is more forgiving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("The target radius is the maximum distance (in meters) a kubb can be from the cluster center before being marked as an outlier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Display Units") {
                Toggle("Use Imperial Units", isOn: Binding(
                    get: { currentSettings.useImperialUnits },
                    set: { newValue in
                        currentSettings.useImperialUnits = newValue
                        currentSettings.lastModified = Date()
                        try? modelContext.save()
                    }
                ))

                Text(currentSettings.useImperialUnits ? "Distances shown in feet/inches, areas in square feet/inches" : "Distances shown in meters, areas in square meters")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Note: Pitch distances (8m, 4m) remain in meters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Training Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load from effectiveTargetRadius (handles migration)
            targetRadiusValue = currentSettings.effectiveTargetRadius
            // If targetRadiusMeters was nil (old database), set it now
            if currentSettings.targetRadiusMeters == nil {
                currentSettings.targetRadiusMeters = currentSettings.effectiveTargetRadius
                try? modelContext.save()
            }
        }
        .onChange(of: targetRadiusValue) { oldValue, newValue in
            saveSettings(newValue)
        }
    }

    // MARK: - Helper Methods

    private func descriptionForValue(_ value: Double) -> String {
        switch value {
        case ..<0.35:
            return "Very Challenging - Requires exceptional precision"
        case 0.35..<0.5:
            return "Challenging - For advanced players"
        case 0.5..<0.65:
            return "Balanced - Achievable with good technique (recommended)"
        case 0.65..<0.8:
            return "Moderate - Good for developing consistency"
        default:
            return "Forgiving - Great for beginners"
        }
    }

    private func saveSettings(_ newValue: Double) {
        currentSettings.targetRadiusMeters = newValue
        currentSettings.lastModified = Date()
        try? modelContext.save()
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let value: Double
    let label: String
    @Binding var currentValue: Double

    var isSelected: Bool {
        abs(currentValue - value) < 0.01
    }

    var body: some View {
        Button {
            currentValue = value
        } label: {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? .white : Color.Kubb.swedishBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.Kubb.swedishBlue : Color.Kubb.swedishBlue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - Outlier Visualization

struct OutlierVisualization: View {
    let targetRadius: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))

                // Core cluster (center)
                Circle()
                    .fill(Color.Kubb.swedishBlue.opacity(0.2))
                    .frame(width: 60, height: 60)

                Circle()
                    .stroke(Color.Kubb.swedishBlue, lineWidth: 2)
                    .frame(width: 60, height: 60)

                // Target radius ring (scaled by target radius value)
                // Scale 0.25-1.0m to 80-160 pixel range for visualization
                let ringSize = 60 + ((targetRadius - 0.25) / 0.75) * 100
                Circle()
                    .stroke(Color.Kubb.forestGreen.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .frame(width: ringSize, height: ringSize)

                // Example kubbs
                // Core kubbs (inside threshold)
                ForEach(0..<4) { index in
                    let angle = Double(index) * .pi / 2
                    let radius = 20.0
                    Circle()
                        .fill(Color.Kubb.swedishBlue)
                        .frame(width: 8, height: 8)
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius
                        )
                }

                // Outlier kubb (outside target radius)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .offset(x: ringSize / 2 + 5, y: 0)

                // Labels
                VStack {
                    Spacer()
                    HStack {
                        Label("Core", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.Kubb.swedishBlue)
                        Spacer()
                        Label("Target Radius", systemImage: "circle.dashed")
                            .font(.caption2)
                            .foregroundStyle(Color.Kubb.forestGreen)
                        Spacer()
                        Label("Outlier", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrainingSettingsView()
            .modelContainer(for: InkastingSettings.self, inMemory: true)
    }
}
