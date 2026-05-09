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

    // MARK: - Derived kicker

    private var kicker: String {
        if let phase = trainingPhase {
            switch phase {
            case .eightMeters:         return "TRAINING · 8M"
            case .fourMetersBlasting:  return "TRAINING · 4M"
            case .inkastingDrilling:   return "TRAINING · INK"
            case .gameTracker:         return "GAME TRACKER"
            case .pressureCooker:      return "PRESSURE"
            }
        } else if icon == "flag.2.crossed.fill" {
            return "LIVE GAMES"
        } else {
            return "ALL MODES"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            // Header
            VStack(alignment: .leading, spacing: KubbSpacing.xxs) {
                // Mono kicker
                Text(kicker)
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .foregroundStyle(color)

                // Section title with optional icon
                HStack(spacing: Layout.headerSpacing) {
                    if let trainingPhase = trainingPhase {
                        trainingPhase.iconImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(color)
                    } else if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color)
                    }

                    Text(title)
                        .font(KubbType.titleL)
                        .foregroundStyle(Color.Kubb.text)
                }
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
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        .overlay(alignment: .top) {
            // Colored top accent bar matching mode family
            color.opacity(0.18)
                .frame(height: 3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: KubbRadius.xl,
                        topTrailingRadius: KubbRadius.xl
                    )
                )
        }
        .kubbCardShadow()
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
            color: Color.Kubb.swedishBlue,
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
