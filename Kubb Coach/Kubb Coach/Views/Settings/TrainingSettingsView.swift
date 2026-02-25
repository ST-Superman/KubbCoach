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
    @State private var thresholdValue: Double = 0.3

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

            Section("Outlier Detection Sensitivity") {
                VStack(alignment: .leading, spacing: 16) {
                    // Current value display
                    HStack {
                        Text("Threshold")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f m", thresholdValue))
                            .font(.title3.bold())
                            .foregroundStyle(.blue)
                    }

                    // Description
                    Text(descriptionForValue(thresholdValue))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Slider with labels
                    VStack(spacing: 8) {
                        Slider(value: $thresholdValue, in: 0.1...1.0, step: 0.05) {
                            Text("Threshold")
                        } minimumValueLabel: {
                            VStack {
                                Text("0.1m")
                                    .font(.caption2)
                                Text("Strict")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } maximumValueLabel: {
                            VStack {
                                Text("1.0m")
                                    .font(.caption2)
                                Text("Lenient")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.blue)

                        // Preset buttons
                        HStack(spacing: 12) {
                            PresetButton(value: 0.15, label: "Strict", currentValue: $thresholdValue)
                            PresetButton(value: 0.3, label: "Balanced", currentValue: $thresholdValue)
                            PresetButton(value: 0.5, label: "Lenient", currentValue: $thresholdValue)
                        }
                    }

                    // Visual example
                    OutlierVisualization(threshold: thresholdValue)
                        .frame(height: 120)
                        .padding(.top, 8)
                }
                .padding(.vertical, 8)
            }

            Section {
                Text("Lower thresholds identify even small inconsistencies. Higher thresholds only mark obvious outliers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("The threshold represents the minimum distance (in meters) a kubb must be from the core cluster to be considered an outlier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Training Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            thresholdValue = currentSettings.outlierThresholdMeters
        }
        .onChange(of: thresholdValue) { oldValue, newValue in
            saveSettings(newValue)
        }
    }

    // MARK: - Helper Methods

    private func descriptionForValue(_ value: Double) -> String {
        switch value {
        case ..<0.2:
            return "Very Strict - Marks even slightly off throws as outliers. Best for advanced players."
        case 0.2..<0.35:
            return "Balanced - Standard detection for most players. Recommended."
        case 0.35..<0.6:
            return "Lenient - Only marks obvious outliers. Good for beginners."
        default:
            return "Very Lenient - Only extreme outliers are marked."
        }
    }

    private func saveSettings(_ newValue: Double) {
        currentSettings.outlierThresholdMeters = newValue
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
                .foregroundStyle(isSelected ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - Outlier Visualization

struct OutlierVisualization: View {
    let threshold: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))

                // Core cluster (center)
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)

                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 60, height: 60)

                // Threshold ring (scaled by threshold value)
                let ringSize = 60 + (threshold * 100)
                Circle()
                    .stroke(Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .frame(width: ringSize, height: ringSize)

                // Example kubbs
                // Core kubbs (inside threshold)
                ForEach(0..<4) { index in
                    let angle = Double(index) * .pi / 2
                    let radius = 20.0
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius
                        )
                }

                // Outlier kubb (outside threshold)
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
                            .foregroundStyle(.blue)
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
