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
    let phase: TrainingPhase?

    private var filteredBests: [PersonalBest] {
        if let phase = phase {
            return personalBests.filter { $0.phase == phase || $0.phase == nil }
        }
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
                    PersonalBestCard(category: category, best: best)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PersonalBestCard: View {
    let category: BestCategory
    let best: PersonalBest?

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
                Text(formatValue(best.value) + category.unit)
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
            return String(format: "%.1f", value)
        case .lowestBlastingScore:
            let score = Int(value)
            return score > 0 ? "+\(score)" : "\(score)"
        case .perfectRound, .perfectSession:
            return "✓"
        case .longestStreak, .mostSessionsInWeek, .mostConsecutiveHits:
            return "\(Int(value))"
        case .tightestInkastingCluster:
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    @Previewable @State var container = try! ModelContainer(for: PersonalBest.self)

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

    container.mainContext.insert(pb1)
    container.mainContext.insert(pb2)
    container.mainContext.insert(pb3)

    return ScrollView {
        PersonalBestsSection(phase: nil)
    }
    .modelContainer(container)
}
