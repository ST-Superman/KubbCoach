//
//  PersonalBestHelpSheet.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/22/26.
//

import SwiftUI

/// Detailed help sheet explaining a personal best category
struct PersonalBestHelpSheet: View {
    let category: BestCategory
    let best: PersonalBest?
    let formatter: PersonalBestFormatter
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .font(.title)
                            .foregroundStyle(best != nil ? KubbColors.swedishGold : .secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.displayName)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(category.shortDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(category.displayName): \(category.shortDescription)")

                    Divider()

                    // Current Record
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Record")
                            .font(.headline)

                        if let best = best {
                            HStack {
                                Text(formatter.format(value: best.value, for: category))
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Achieved")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(best.achievedAt, format: .dateTime.month().day().year())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(KubbColors.swedishGold.opacity(0.1))
                            .cornerRadius(12)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Record: \(formatter.format(value: best.value, for: category)), achieved on \(best.achievedAt.formatted(date: .long, time: .omitted))")
                        } else {
                            Text("No record yet — complete a session to set your first record!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }

                    Divider()

                    // Detailed Explanation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It's Calculated")
                            .font(.headline)

                        Text(.init(category.helpDescription))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
                .padding()
            }
            .navigationTitle("Record Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    @Previewable @State var isPresented = true
    let best = PersonalBest(
        category: .highestAccuracy,
        phase: .eightMeters,
        value: 85.5,
        sessionId: UUID()
    )
    let settings = InkastingSettings()
    let formatter = PersonalBestFormatter(settings: settings)

    return PersonalBestHelpSheet(
        category: .highestAccuracy,
        best: best,
        formatter: formatter,
        isPresented: $isPresented
    )
}
