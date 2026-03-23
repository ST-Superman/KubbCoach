//
//  CategorySection.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/22/26.
//

import SwiftUI

/// Reusable section component for displaying a group of personal best categories
struct CategorySection: View {
    // MARK: - Layout Constants

    private enum Layout {
        static let sectionSpacing: CGFloat = 12
        static let gridSpacing: CGFloat = 12
        static let iconSize: CGFloat = 36
        static let cornerRadius: CGFloat = 12
        static let headerSpacing: CGFloat = 8
    }

    // MARK: - Grid Configuration

    private static let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // MARK: - Properties

    let title: String
    let icon: String?
    let trainingPhase: TrainingPhase?
    let color: Color
    let categories: [BestCategory]
    let bestsByCategory: [BestCategory: PersonalBest]
    let formatter: PersonalBestFormatter
    let onShare: ((BestCategory, PersonalBest) -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            // Header
            HStack(spacing: Layout.headerSpacing) {
                // Icon: Uses training phase icon if available, otherwise system icon
                if let trainingPhase = trainingPhase {
                    Image(trainingPhase.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.iconSize, height: Layout.iconSize)
                        .foregroundStyle(color)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) section")

            // Grid of category cards
            LazyVGrid(columns: Self.gridColumns, spacing: Layout.gridSpacing) {
                ForEach(categories, id: \.self) { category in
                    PersonalBestCard(
                        category: category,
                        best: bestsByCategory[category],
                        formatter: formatter,
                        // Transform parent's (category, best) callback to card's (best) callback
                        // by capturing the current category in a closure
                        onShare: onShare.map { shareHandler in
                            { best in shareHandler(category, best) }
                        }
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Personal best records grid")
            .accessibilityHint("Contains \(categories.count) personal best categories")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(Layout.cornerRadius)
        .padding(.horizontal)
    }
}

#Preview {
    let pb1 = PersonalBest(
        category: .highestAccuracy,
        phase: .eightMeters,
        value: 85.5,
        sessionId: UUID()
    )
    let pb2 = PersonalBest(
        category: .mostConsecutiveHits,
        phase: .eightMeters,
        value: 12.0,
        sessionId: UUID()
    )

    let settings = InkastingSettings()
    let formatter = PersonalBestFormatter(settings: settings)

    return ScrollView {
        CategorySection(
            title: "8 Meter Records",
            icon: nil,
            trainingPhase: .eightMeters,
            color: KubbColors.phase8m,
            categories: [.highestAccuracy, .mostConsecutiveHits],
            bestsByCategory: [
                .highestAccuracy: pb1,
                .mostConsecutiveHits: pb2
            ],
            formatter: formatter,
            onShare: { category, best in
                print("Share \(category): \(best.value)")
            }
        )
    }
}
