//
//  PersonalBestsSection.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/27/26.
//  Refactored on 3/22/26 - Comprehensive improvements
//

import SwiftUI
import SwiftData

struct PersonalBestsSection: View {
    @Query(sort: \PersonalBest.achievedAt, order: .reverse)
    private var personalBests: [PersonalBest]

    @Query private var inkastingSettings: [InkastingSettings]

    @State private var isRefreshing = false

    // MARK: - Computed Properties

    private var currentSettings: InkastingSettings {
        inkastingSettings.first ?? InkastingSettings()
    }

    private var formatter: PersonalBestFormatter {
        PersonalBestFormatter(settings: currentSettings)
    }

    /// Cached dictionary of best records per category (prevents repeated filtering)
    private var bestsByCategory: [BestCategory: PersonalBest] {
        let grouped = Dictionary(grouping: personalBests, by: { $0.category })
        return grouped.compactMapValues { bests in
            bests.max { a, b in
                // For categories where lower is better, reverse comparison
                if a.category == .lowestBlastingScore || a.category == .tightestInkastingCluster {
                    return a.value > b.value
                }
                return a.value < b.value
            }
        }
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

    private var gameTrackerCategories: [BestCategory] {
        [.bestGameFieldEfficiency, .bestGameEightMeterRate, .longestWinStreak]
    }

    // MARK: - Body

    var body: some View {
        Group {
            if personalBests.isEmpty {
                // Empty state with onboarding
                PersonalBestsEmptyState()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Global Records
                        CategorySection(
                            title: "Global Records",
                            icon: "trophy.fill",
                            trainingPhase: nil,
                            color: KubbColors.swedishGold,
                            categories: globalCategories,
                            bestsByCategory: bestsByCategory,
                            formatter: formatter,
                            onShare: handleShare
                        )

                        // 8 Meter Records
                        CategorySection(
                            title: "8 Meter Records",
                            icon: nil,
                            trainingPhase: .eightMeters,
                            color: KubbColors.phase8m,
                            categories: eightMeterCategories,
                            bestsByCategory: bestsByCategory,
                            formatter: formatter,
                            onShare: handleShare
                        )

                        // Blasting Records
                        CategorySection(
                            title: "Blasting Records",
                            icon: nil,
                            trainingPhase: .fourMetersBlasting,
                            color: KubbColors.phase4m,
                            categories: blastingCategories,
                            bestsByCategory: bestsByCategory,
                            formatter: formatter,
                            onShare: handleShare
                        )

                        // Inkasting Records
                        CategorySection(
                            title: "Inkasting Records",
                            icon: nil,
                            trainingPhase: .inkastingDrilling,
                            color: KubbColors.phaseInkasting,
                            categories: inkastingCategories,
                            bestsByCategory: bestsByCategory,
                            formatter: formatter,
                            onShare: handleShare
                        )

                        // Game Records
                        CategorySection(
                            title: "Game Records",
                            icon: "flag.2.crossed.fill",
                            trainingPhase: nil,
                            color: KubbColors.forestGreen,
                            categories: gameTrackerCategories,
                            bestsByCategory: bestsByCategory,
                            formatter: formatter,
                            onShare: handleShare
                        )
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await refreshData()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Personal Best Records")
    }

    // MARK: - Methods

    /// Handle share action for a personal best record
    private func handleShare(category: BestCategory, best: PersonalBest) {
        let shareText = best.shareableText(formatter: formatter)
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        // Get the window scene to present the activity view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    /// Refresh data with pull-to-refresh
    private func refreshData() async {
        isRefreshing = true
        // Add a small delay to show refresh animation
        try? await Task.sleep(for: .milliseconds(500))
        isRefreshing = false
        // SwiftData @Query automatically refreshes, so no manual work needed
    }
}

// MARK: - PersonalBestCard

struct PersonalBestCard: View {
    let category: BestCategory
    let best: PersonalBest?
    let formatter: PersonalBestFormatter
    let onShare: ((PersonalBest) -> Void)?

    @State private var showHelp = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 8) {
            // Action buttons (help and share)
            HStack {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Learn about \(category.displayName)")

                Spacer()

                if best != nil {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share \(category.displayName) record")
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            // Category icon
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundStyle(best != nil ? KubbColors.swedishGold : .gray)

            // Category name
            Text(category.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Value display
            if let best = best {
                VStack(spacing: 4) {
                    Text(formatter.format(value: best.value, for: category))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    // Achievement date
                    Text(best.achievedAt, format: .dateTime.month().day())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(best != nil ? "Double tap for more information or to share" : "Double tap for more information")
        .sheet(isPresented: $showHelp) {
            PersonalBestHelpSheet(
                category: category,
                best: best,
                formatter: formatter,
                isPresented: $showHelp
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let best = best {
                ShareSheet(items: [best.shareableText(formatter: formatter)])
            }
        }
    }

    private var accessibilityLabel: String {
        if let best = best {
            let value = formatter.format(value: best.value, for: category)
            let date = best.achievedAt.formatted(date: .abbreviated, time: .omitted)
            return "\(category.displayName): \(value), achieved on \(date)"
        } else {
            return "\(category.displayName): No record yet"
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var container = try! ModelContainer(
        for: PersonalBest.self, InkastingSettings.self
    )

    // Create sample personal bests
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
    let pb4 = PersonalBest(
        category: .lowestBlastingScore,
        phase: .fourMetersBlasting,
        value: -3.0,
        sessionId: UUID()
    )
    let pb5 = PersonalBest(
        category: .tightestInkastingCluster,
        phase: .inkastingDrilling,
        value: 0.025,
        sessionId: UUID()
    )

    // Create inkasting settings
    let settings = InkastingSettings()

    container.mainContext.insert(pb1)
    container.mainContext.insert(pb2)
    container.mainContext.insert(pb3)
    container.mainContext.insert(pb4)
    container.mainContext.insert(pb5)
    container.mainContext.insert(settings)

    return PersonalBestsSection()
        .modelContainer(container)
}

// MARK: - Empty State Preview

#Preview("Empty State") {
    @Previewable @State var container = try! ModelContainer(
        for: PersonalBest.self, InkastingSettings.self
    )

    return PersonalBestsSection()
        .modelContainer(container)
}
