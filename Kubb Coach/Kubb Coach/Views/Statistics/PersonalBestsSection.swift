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
    let phase: TrainingPhase?

    private var currentSettings: InkastingSettings {
        inkastingSettings.first ?? InkastingSettings()
    }

    private var filteredBests: [PersonalBest] {
        if let phase = phase {
            // When a phase is selected, only show records applicable to that phase
            return personalBests.filter { best in
                best.category.applicablePhases.contains(phase)
            }
        }
        // When no phase is selected (All Phases), show all records
        return personalBests
    }

    private var groupedBests: [(BestCategory, PersonalBest?)] {
        BestCategory.allCases.map { category in
            let best = filteredBests
                .filter { $0.category == category }
                .sorted { $0.value > $1.value } // Get the best value
                .first
            return (category, best)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Bests")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 12
            ) {
                ForEach(groupedBests, id: \.0) { category, best in
                    PersonalBestCard(category: category, best: best, settings: currentSettings)
                }
            }
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
        PersonalBestsSection(phase: nil)
    }
    .modelContainer(container)
}
