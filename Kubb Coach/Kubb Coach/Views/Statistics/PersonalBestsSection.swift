//
//  PersonalBestsSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//

import SwiftUI
import SwiftData

struct PersonalBestsSection: View {
    @Query private var personalBests: [PersonalBest]
    @Query private var inkastingSettings: [InkastingSettings]

    private var currentSettings: InkastingSettings {
        inkastingSettings.first ?? InkastingSettings()
    }

    private func getBest(for category: BestCategory) -> PersonalBest? {
        personalBests
            .filter { $0.category == category }
            .sorted { $0.value > $1.value }
            .first
    }

    private var globalCategories: [BestCategory] {
        [.longestStreak, .mostSessionsInWeek]
    }

    private var eightMeterCategories: [BestCategory] {
        [.highestAccuracy, .mostConsecutiveHits]
    }

    private var blastingCategories: [BestCategory] {
        [.lowestBlastingScore, .longestUnderParStreak]
    }

    private var inkastingCategories: [BestCategory] {
        [.tightestInkastingCluster, .longestNoOutlierStreak]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Global Records
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(KubbColors.swedishGold)
                    Text("Global Records")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(globalCategories, id: \.self) { category in
                        PersonalBestCard(category: category, best: getBest(for: category), settings: currentSettings)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            // 8 Meter Records
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(TrainingPhase.eightMeters.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(KubbColors.phase8m)
                    Text("8 Meter Records")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(eightMeterCategories, id: \.self) { category in
                        PersonalBestCard(category: category, best: getBest(for: category), settings: currentSettings)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            // Blasting Records
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(TrainingPhase.fourMetersBlasting.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(KubbColors.phase4m)
                    Text("Blasting Records")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(blastingCategories, id: \.self) { category in
                        PersonalBestCard(category: category, best: getBest(for: category), settings: currentSettings)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            // Inkasting Records
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(TrainingPhase.inkastingDrilling.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(KubbColors.phaseInkasting)
                    Text("Inkasting Records")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(inkastingCategories, id: \.self) { category in
                        PersonalBestCard(category: category, best: getBest(for: category), settings: currentSettings)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct PersonalBestCard: View {
    let category: BestCategory
    let best: PersonalBest?
    let settings: InkastingSettings

    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(best != nil ? KubbColors.swedishGold : .gray)

            Text(category.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let best = best {
                Text(formatValue(best.value))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            } else {
                Text("—")
                    .font(.title3)
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(best != nil ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .sheet(isPresented: $showHelp) {
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

                        Divider()

                        // Current Record
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Record")
                                .font(.headline)

                            if let best = best {
                                HStack {
                                    Text(formatValue(best.value))
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
                            showHelp = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch category {
        case .highestAccuracy:
            return String(format: "%.1f%%", value)
        case .lowestBlastingScore:
            let score = Int(value)
            return score > 0 ? "+\(score)" : "\(score)"
        case .longestStreak:
            return "\(Int(value)) days"
        case .mostSessionsInWeek:
            return "\(Int(value)) sessions"
        case .mostConsecutiveHits:
            return "\(Int(value)) hits"
        case .tightestInkastingCluster:
            // Use InkastingSettings for proper unit formatting
            return settings.formatArea(value)
        case .longestUnderParStreak:
            return "\(Int(value)) rounds"
        case .longestNoOutlierStreak:
            return "\(Int(value)) rounds"
        }
    }
}

#Preview {
    @Previewable @State var container = try! ModelContainer(
        for: PersonalBest.self, InkastingSettings.self
    )

    // Create some sample personal bests
    let pb1 = PersonalBest(
        category: .highestAccuracy,
        phase: .eightMeters,
        value: 85.5,
        sessionId: UUID()
    )
    let pb2 = PersonalBest(
        category: .mostConsecutiveHits,
        phase: nil,
        value: 12.0,
        sessionId: UUID()
    )
    let pb3 = PersonalBest(
        category: .longestStreak,
        phase: nil,
        value: 5.0,
        sessionId: UUID()
    )

    // Create inkasting settings
    let settings = InkastingSettings()

    container.mainContext.insert(pb1)
    container.mainContext.insert(pb2)
    container.mainContext.insert(pb3)
    container.mainContext.insert(settings)

    return ScrollView {
        PersonalBestsSection()
    }
    .modelContainer(container)
}
