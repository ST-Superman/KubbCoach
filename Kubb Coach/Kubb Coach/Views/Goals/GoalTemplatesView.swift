//
//  GoalTemplatesView.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//

import SwiftUI
import SwiftData

struct GoalTemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: TemplateCategory?
    @State private var selectedPhase: TrainingPhase?
    @State private var creatingGoal = false
    @State private var errorMessage: String?

    private var filteredTemplates: [GoalTemplate] {
        GoalTemplateService.shared.getTemplates(
            forPhase: selectedPhase,
            category: selectedCategory,
            difficulty: nil
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Intro Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Start Templates")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Choose a pre-made goal to get started quickly. Templates are organized by difficulty and training phase.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(
                            title: "All",
                            icon: "target",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(TemplateCategory.allCases) { category in
                            CategoryChip(
                                title: category.displayName,
                                icon: category.icon,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Phase Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PhaseFilterChip(
                            title: "All Phases",
                            isSelected: selectedPhase == nil,
                            color: KubbColors.swedishBlue,
                            action: { selectedPhase = nil }
                        )

                        ForEach(TrainingPhase.allCases, id: \.self) { phase in
                            PhaseFilterChip(
                                title: phase.displayName,
                                isSelected: selectedPhase == phase,
                                color: phaseColor(for: phase),
                                action: { selectedPhase = phase }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Template Grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(filteredTemplates) { template in
                        TemplateCard(template: template) {
                            createGoalFromTemplate(template)
                        }
                    }
                }
                .padding(.horizontal)

                if filteredTemplates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No Templates Found")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Try adjusting your filters")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(.vertical)
        }
        .background(DesignGradients.homeWarm.ignoresSafeArea())
        .navigationTitle("Goal Templates")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
        .overlay {
            if creatingGoal {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView("Creating goal...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
        }
    }

    private func createGoalFromTemplate(_ template: GoalTemplate) {
        // Check if can create new goal
        guard GoalService.shared.canCreateNewGoal(context: modelContext) else {
            errorMessage = "You already have 5 active goals. Complete or abandon one before creating a new goal."
            return
        }

        creatingGoal = true

        Task {
            do {
                _ = try GoalTemplateService.shared.createGoalFromTemplate(template, context: modelContext)

                await MainActor.run {
                    creatingGoal = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    creatingGoal = false
                    errorMessage = "Failed to create goal: \(error.localizedDescription)"
                }
            }
        }
    }

    private func phaseColor(for phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters:
            return KubbColors.phase8m
        case .fourMetersBlasting:
            return KubbColors.phase4m
        case .inkastingDrilling:
            return KubbColors.phaseInkasting
        case .gameTracker:
            return KubbColors.swedishBlue
        case .pressureCooker:
            return KubbColors.phasePressureCooker
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: GoalTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon and category badge
                HStack {
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundStyle(categoryColor)

                    Spacer()

                    Text(template.category.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.15))
                        .cornerRadius(4)
                }

                // Template info
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                // Difficulty badge
                HStack(spacing: 4) {
                    Image(systemName: difficultyIcon)
                        .font(.caption2)
                        .foregroundStyle(difficultyColor)

                    Text(template.difficulty.rawValue.capitalized)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(difficultyColor)
                }
            }
            .padding(12)
            .frame(height: 160)
            .background(Color(.systemBackground))
            .cornerRadius(DesignConstants.mediumRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.mediumRadius)
                    .strokeBorder(categoryColor.opacity(0.2), lineWidth: 1.5)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        switch template.category {
        case .beginner:
            return KubbColors.forestGreen
        case .intermediate:
            return KubbColors.swedishBlue
        case .advanced:
            return KubbColors.streakFlame
        case .competitive:
            return KubbColors.swedishGold
        }
    }

    private var difficultyColor: Color {
        switch template.difficulty {
        case .easy:
            return Color.green
        case .moderate:
            return KubbColors.swedishBlue
        case .challenging:
            return Color.orange
        case .ambitious:
            return Color.red
        }
    }

    private var difficultyIcon: String {
        switch template.difficulty {
        case .easy:
            return "circle.fill"
        case .moderate:
            return "circle.lefthalf.filled"
        case .challenging:
            return "circle.righthalf.filled"
        case .ambitious:
            return "circle.fill"
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? KubbColors.swedishBlue : Color(.secondarySystemBackground))
            .cornerRadius(DesignConstants.buttonRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Phase Filter Chip

struct PhaseFilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(.secondarySystemBackground))
                .cornerRadius(DesignConstants.buttonRadius)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        GoalTemplatesView()
    }
    .modelContainer(for: [TrainingGoal.self], inMemory: true)
}
