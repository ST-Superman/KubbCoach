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
        [.highestAccuracy, .mostConsecutiveHits, .perfectRound, .perfectSession]
    }

    private var blastingCategories: [BestCategory] {
        [.lowestBlastingScore, .longestUnderParStreak, .bestUnderParSession]
    }

    private var inkastingCategories: [BestCategory] {
        [.tightestInkastingCluster, .longestNoOutlierStreak, .bestNoOutlierSession]
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
                    Image(systemName: "target")
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
                    Image(systemName: "flag.fill")
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
                    Image(systemName: "scope")
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

    var body: some View {
        VStack(spacing: 8) {
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
        .padding(.vertical, 16)
        .background(best != nil ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }

    private func formatValue(_ value: Double) -> String {
        switch category {
        case .highestAccuracy:
            return String(format: "%.1f%%", value)
        case .lowestBlastingScore:
            let score = Int(value)
            return score > 0 ? "+\(score)" : "\(score)"
        case .perfectRound, .perfectSession:
            return "✓"
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
        case .bestUnderParSession:
            return "\(Int(value)) under par"
        case .longestNoOutlierStreak:
            return "\(Int(value)) rounds"
        case .bestNoOutlierSession:
            return "\(Int(value)) kubbs"
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
        category: .perfectRound,
        phase: nil,
        value: 1.0,
        sessionId: UUID()
    )
    let pb3 = PersonalBest(
        category: .mostConsecutiveHits,
        phase: nil,
        value: 12.0,
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
