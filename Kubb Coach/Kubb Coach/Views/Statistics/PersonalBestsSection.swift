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
                            color: Color.Kubb.swedishGold,
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
                            color: Color.Kubb.swedishBlue,
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
                            color: Color.Kubb.phase4m,
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
                            color: Color.Kubb.forestGreen,
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
                            color: Color.Kubb.forestGreen,
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

    var body: some View {
        Button { showHelp = true } label: {
            VStack(alignment: .leading, spacing: KubbSpacing.s) {
                // Top row: icon pill + mono kicker + optional PB chip
                HStack(alignment: .center, spacing: KubbSpacing.s) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 26, height: 26)
                        Image(systemName: category.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }

                    Text(category.displayName.uppercased())
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textTer)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    if best != nil {
                        Text("★ PB")
                            .font(KubbType.monoXS)
                            .tracking(0.8)
                            .foregroundStyle(Color(hex: "8A6700"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.Kubb.swedishGold)
                            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xs))
                    }
                }

                // Value — the hero
                if let best = best {
                    Text(formatter.format(value: best.value, for: category))
                        .font(KubbFont.fraunces(28, weight: .medium, italic: true))
                        .foregroundStyle(Color.Kubb.text)
                        .tracking(-0.8)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)

                    Text(best.achievedAt, format: .dateTime.month().day().year())
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textTer)
                } else {
                    Text("—")
                        .font(KubbFont.fraunces(28, weight: .medium, italic: true))
                        .foregroundStyle(Color.Kubb.textTer)
                        .tracking(-0.8)

                    Text("NO RECORD")
                        .font(KubbType.monoXS)
                        .tracking(KubbTracking.monoXS)
                        .foregroundStyle(Color.Kubb.textTer)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(KubbSpacing.m)
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l))
            .kubbCardShadow()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let best = best {
                Button {
                    onShare?(best)
                } label: {
                    Label("Share Record", systemImage: "square.and.arrow.up")
                }
            }
            Button {
                showHelp = true
            } label: {
                Label("About This Record", systemImage: "info.circle")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(best != nil ? "Double tap for details or hold for more options" : "Double tap for details")
        .sheet(isPresented: $showHelp) {
            PersonalBestHelpSheet(
                category: category,
                best: best,
                formatter: formatter,
                isPresented: $showHelp
            )
        }
    }

    private var iconColor: Color {
        best != nil ? Color.Kubb.swedishGold : Color.Kubb.textTer
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
