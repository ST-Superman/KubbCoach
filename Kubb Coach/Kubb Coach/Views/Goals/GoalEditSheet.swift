//
//  GoalEditSheet.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
//
//  Re-skinned to the Kubb design system (Phase 4 of the design alignment
//  pass). Pattern-matches CompetitionSettingsView: ScrollView + SettingsCard
//  sections on Color.Kubb.paper, BriefingPicker for the category strip,
//  SettingsRow + Stepper for all numeric inputs.
//

import SwiftUI
import SwiftData

enum GoalCategory: String, CaseIterable {
    case volume = "Volume"
    case performance = "Performance"
    case consistency = "Consistency"
}

struct GoalEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var customTitle: String = ""
    @State private var goalCategory: GoalCategory = .volume
    @State private var goalType: GoalType = .volumeByDays
    @State private var targetPhase: TrainingPhase? = nil
    @State private var sessionCount: Int = 5
    @State private var endDate: Date = Date().addingTimeInterval(14 * 24 * 60 * 60)
    @State private var daysToComplete: Int = 14
    @State private var showError: String? = nil

    // Performance goal fields
    @State private var performanceMetric: PerformanceMetric = .accuracy8m
    @State private var targetValue: Double = 70.0
    @State private var comparisonType: ComparisonType = .greaterThan
    @State private var evaluationScope: EvaluationScope = .session

    // Consistency goal fields
    @State private var requiredStreak: Int = 3
    @State private var consistencyMetric: ConsistencyMetric = .accuracy

    let existingGoal: TrainingGoal?
    let onSave: () -> Void

    enum ConsistencyMetric: String, CaseIterable {
        case accuracy = "Accuracy"
        case blastingScore = "Under-Par Blasting"
        case inkasting = "Zero Outliers"
    }

    init(existingGoal: TrainingGoal? = nil, onSave: @escaping () -> Void = {}) {
        self.existingGoal = existingGoal
        self.onSave = onSave

        if let goal = existingGoal {
            _customTitle = State(initialValue: goal.customTitle ?? "")
            _goalType = State(initialValue: goal.goalTypeEnum)
            _targetPhase = State(initialValue: goal.phaseEnum)
            _sessionCount = State(initialValue: goal.targetSessionCount)
            _daysToComplete = State(initialValue: goal.daysToComplete ?? 14)
            if let end = goal.endDate {
                _endDate = State(initialValue: end)
            }

            if goal.goalTypeEnum.isPerformance {
                _goalCategory = State(initialValue: .performance)
                if let metric = goal.targetMetric {
                    _performanceMetric = State(initialValue: PerformanceMetric(rawValue: metric) ?? .accuracy8m)
                }
                if let value = goal.targetValue {
                    _targetValue = State(initialValue: value)
                }
                if let comparison = goal.comparisonType {
                    _comparisonType = State(initialValue: ComparisonType(rawValue: comparison) ?? .greaterThan)
                }
                if let scope = goal.evaluationScope {
                    _evaluationScope = State(initialValue: EvaluationScope(rawValue: scope) ?? .session)
                }
            } else if goal.goalTypeEnum.isConsistency {
                _goalCategory = State(initialValue: .consistency)
                if let streak = goal.requiredStreak {
                    _requiredStreak = State(initialValue: streak)
                }
                if let value = goal.targetValue {
                    _targetValue = State(initialValue: value)
                }
            } else {
                _goalCategory = State(initialValue: .volume)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: KubbSpacing.xl) {
                    if existingGoal == nil {
                        templatesLink
                    }

                    titleSection
                    categorySection
                    phaseSection

                    switch goalCategory {
                    case .volume:      volumeSection
                    case .performance: performanceSection
                    case .consistency: consistencySection
                    }

                    rewardCard

                    if let error = showError {
                        Text(error)
                            .font(KubbFont.inter(13))
                            .foregroundStyle(Color.Kubb.miss)
                            .padding(.horizontal, KubbSpacing.l)
                    }
                }
                .padding(.horizontal, KubbSpacing.l)
                .padding(.top, KubbSpacing.s)
                .padding(.bottom, KubbSpacing.giant)
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .navigationTitle(existingGoal == nil ? "Create Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(KubbFont.inter(16, weight: .semibold))
                            .foregroundStyle(Color.Kubb.textSec)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveGoal()
                    } label: {
                        Text(existingGoal == nil ? "Create" : "Save")
                            .font(KubbFont.inter(16, weight: .semibold))
                            .foregroundStyle(Color.Kubb.swedishBlue)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var templatesLink: some View {
        SettingsCard {
            NavigationLink {
                GoalTemplatesView()
            } label: {
                SettingsRow(
                    icon: "square.grid.2x2",
                    tint: Color.Kubb.swedishBlue,
                    label: "Browse Templates"
                ) {
                    SettingsChevron()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            SettingsEyebrow("GOAL TITLE")
            SettingsCard {
                GoalTextFieldRow(
                    icon: "textformat",
                    tint: Color.Kubb.swedishBlue,
                    label: "Title",
                    placeholder: "Optional",
                    text: $customTitle
                )
            }
            Text("Leave blank for an auto-generated title.")
                .font(KubbFont.inter(12))
                .foregroundStyle(Color.Kubb.textSec)
                .padding(.horizontal, 4)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            BriefingPicker(
                label: "GOAL CATEGORY",
                options: GoalCategory.allCases,
                displayTitle: { $0.rawValue },
                isNumeric: false,
                selected: $goalCategory,
                theme: .training
            )
            .onChange(of: goalCategory) { _, newValue in
                updateGoalTypeForCategory(newValue)
            }
            .padding(.horizontal, -KubbSpacing.l) // BriefingPicker has its own horizontal padding
        }
    }

    @ViewBuilder
    private var phaseSection: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            SettingsEyebrow("TRAINING PHASE")
            SettingsCard {
                if goalCategory == .volume {
                    SettingsRow(
                        icon: "scope",
                        tint: Color.Kubb.swedishBlue,
                        label: "Phase"
                    ) {
                        Picker("", selection: $targetPhase) {
                            Text("Any Phase").tag(nil as TrainingPhase?)
                            ForEach(TrainingPhase.allCases) { phase in
                                Text(phase.displayName).tag(phase as TrainingPhase?)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(Color.Kubb.swedishBlue)
                    }
                } else {
                    SettingsRow(
                        icon: "scope",
                        tint: Color.Kubb.swedishBlue,
                        label: "Phase",
                        detail: targetPhase?.displayName ?? "Select metric first"
                    ) {
                        EmptyView()
                    }
                }
            }
        }
    }

    // MARK: - Category-specific sections

    @ViewBuilder
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            SettingsEyebrow("TARGET")
            SettingsCard {
                SettingsRow(
                    icon: "number",
                    tint: Color.Kubb.swedishBlue,
                    label: "Sessions",
                    detail: "\(sessionCount)"
                ) {
                    Stepper("", value: $sessionCount, in: 1...50)
                        .labelsHidden()
                        .tint(Color.Kubb.swedishBlue)
                }
                SettingsRow(
                    icon: "calendar",
                    tint: Color.Kubb.phase4m,
                    label: "Timeframe"
                ) {
                    Picker("", selection: $goalType) {
                        Text("Next X days").tag(GoalType.volumeByDays)
                        Text("By date").tag(GoalType.volumeByDate)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(Color.Kubb.swedishBlue)
                }
                if goalType == .volumeByDate {
                    SettingsRow(
                        icon: "calendar.badge.clock",
                        tint: Color.Kubb.forestGreen,
                        label: "Deadline"
                    ) {
                        DatePicker("", selection: $endDate, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                } else {
                    SettingsRow(
                        icon: "hourglass",
                        tint: Color.Kubb.forestGreen,
                        label: "Days",
                        detail: "\(daysToComplete)"
                    ) {
                        Stepper("", value: $daysToComplete, in: 1...90)
                            .labelsHidden()
                            .tint(Color.Kubb.swedishBlue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            SettingsEyebrow("PERFORMANCE TARGET")
            SettingsCard {
                SettingsRow(
                    icon: "gauge.medium",
                    tint: Color.Kubb.swedishBlue,
                    label: "Metric"
                ) {
                    Picker("", selection: $performanceMetric) {
                        Text("8m Accuracy").tag(PerformanceMetric.accuracy8m)
                        Text("King Accuracy").tag(PerformanceMetric.kingAccuracy)
                        Text("Blasting Score").tag(PerformanceMetric.blastingScore)
                        Text("Cluster Area").tag(PerformanceMetric.clusterArea)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(Color.Kubb.swedishBlue)
                    .onChange(of: performanceMetric) { _, newValue in
                        updateGoalTypeForPerformanceMetric(newValue)
                    }
                }

                SettingsRow(
                    icon: "checklist",
                    tint: Color.Kubb.phaseGT,
                    label: "Evaluation",
                    subtitle: evaluationScope.description
                ) {
                    Picker("", selection: $evaluationScope) {
                        ForEach([EvaluationScope.session, .anyRound, .allRounds], id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(Color.Kubb.swedishBlue)
                }

                performanceTargetRow

                SettingsRow(
                    icon: "number",
                    tint: Color.Kubb.swedishBlue,
                    label: "Qualifying sessions",
                    detail: "\(sessionCount)"
                ) {
                    Stepper("", value: $sessionCount, in: 1...10)
                        .labelsHidden()
                        .tint(Color.Kubb.swedishBlue)
                }

                SettingsRow(
                    icon: "hourglass",
                    tint: Color.Kubb.forestGreen,
                    label: "Days to complete",
                    detail: "\(daysToComplete)"
                ) {
                    Stepper("", value: $daysToComplete, in: 1...90)
                        .labelsHidden()
                        .tint(Color.Kubb.swedishBlue)
                }
            }
        }
    }

    @ViewBuilder
    private var performanceTargetRow: some View {
        switch performanceMetric {
        case .accuracy8m, .kingAccuracy:
            SettingsRow(
                icon: "target",
                tint: Color.Kubb.swedishGold,
                label: "Target accuracy",
                detail: "\(Int(targetValue))%"
            ) {
                Stepper("", value: $targetValue, in: 50...100, step: 5)
                    .labelsHidden()
                    .tint(Color.Kubb.swedishBlue)
            }
        case .blastingScore:
            SettingsRow(
                icon: "target",
                tint: Color.Kubb.swedishGold,
                label: "Score target",
                detail: "Under \(Int(targetValue))"
            ) {
                Stepper("", value: $targetValue, in: -20...0, step: 1)
                    .labelsHidden()
                    .tint(Color.Kubb.swedishBlue)
            }
        case .clusterArea:
            SettingsRow(
                icon: "target",
                tint: Color.Kubb.swedishGold,
                label: "Cluster target",
                detail: String(format: "Under %.2fm²", targetValue)
            ) {
                Stepper("", value: $targetValue, in: 0.1...1.0, step: 0.05)
                    .labelsHidden()
                    .tint(Color.Kubb.swedishBlue)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            SettingsEyebrow("CONSISTENCY TARGET")
            SettingsCard {
                SettingsRow(
                    icon: "gauge.medium",
                    tint: Color.Kubb.swedishBlue,
                    label: "Metric"
                ) {
                    Picker("", selection: $consistencyMetric) {
                        Text("Accuracy Streak").tag(ConsistencyMetric.accuracy)
                        Text("Under-Par Streak").tag(ConsistencyMetric.blastingScore)
                        Text("Zero Outliers").tag(ConsistencyMetric.inkasting)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(Color.Kubb.swedishBlue)
                    .onChange(of: consistencyMetric) { _, newValue in
                        updateGoalTypeForConsistencyMetric(newValue)
                    }
                }

                switch consistencyMetric {
                case .accuracy:
                    SettingsRow(
                        icon: "target",
                        tint: Color.Kubb.swedishGold,
                        label: "Maintain accuracy",
                        detail: "\(Int(targetValue))%"
                    ) {
                        Stepper("", value: $targetValue, in: 50...100, step: 5)
                            .labelsHidden()
                            .tint(Color.Kubb.swedishBlue)
                    }
                case .blastingScore:
                    SettingsRow(
                        icon: "target",
                        tint: Color.Kubb.swedishGold,
                        label: "Score under par",
                        subtitle: "Negative blasting score"
                    ) {
                        EmptyView()
                    }
                case .inkasting:
                    SettingsRow(
                        icon: "target",
                        tint: Color.Kubb.swedishGold,
                        label: "Zero outliers",
                        subtitle: "Per session"
                    ) {
                        EmptyView()
                    }
                }

                SettingsRow(
                    icon: "flame.fill",
                    tint: Color.Kubb.streakFlame,
                    label: "Consecutive sessions",
                    detail: "\(requiredStreak)"
                ) {
                    Stepper("", value: $requiredStreak, in: 2...10)
                        .labelsHidden()
                        .tint(Color.Kubb.swedishBlue)
                }
            }

            HStack(alignment: .top, spacing: KubbSpacing.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Kubb.phase4m)
                    .padding(.top, 2)
                Text("Consistency goals are all-or-nothing. Breaking the streak fails the goal.")
                    .font(KubbFont.inter(12))
                    .foregroundStyle(Color.Kubb.textSec)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Reward (gold accent card)

    private var rewardCard: some View {
        VStack(alignment: .leading, spacing: KubbSpacing.s) {
            SettingsEyebrow("REWARD")
            HStack(spacing: KubbSpacing.m) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.Kubb.swedishGold)
                Text("Estimated")
                    .font(KubbFont.inter(15, weight: .medium))
                    .foregroundStyle(Color.Kubb.text)
                Spacer()
                Text("\(estimatedXP) XP")
                    .font(KubbFont.fraunces(20, weight: .medium, italic: true))
                    .foregroundStyle(Color.Kubb.swedishGold)
                    .monospacedDigit()
            }
            .padding(.horizontal, KubbSpacing.l)
            .padding(.vertical, KubbSpacing.m2)
            .accentCard(color: Color.Kubb.swedishGold, cornerRadius: KubbRadius.l)
        }
    }

    // MARK: - Logic (unchanged from original)

    private func updateGoalTypeForCategory(_ category: GoalCategory) {
        switch category {
        case .volume:
            goalType = .volumeByDays
        case .performance:
            goalType = .performanceAccuracy
            performanceMetric = .accuracy8m
            targetValue = 70.0
            comparisonType = .greaterThan
            targetPhase = .eightMeters
        case .consistency:
            goalType = .consistencyAccuracy
            consistencyMetric = .accuracy
            targetValue = 70.0
            requiredStreak = 3
            targetPhase = .eightMeters
        }
    }

    private func updateGoalTypeForPerformanceMetric(_ metric: PerformanceMetric) {
        switch metric {
        case .accuracy8m, .kingAccuracy:
            goalType = .performanceAccuracy
            comparisonType = .greaterThan
            targetPhase = .eightMeters
        case .blastingScore:
            goalType = .performanceBlastingScore
            comparisonType = .lessThan
            targetPhase = .fourMetersBlasting
        case .clusterArea:
            goalType = .performanceClusterArea
            comparisonType = .lessThan
            targetPhase = .inkastingDrilling
        case .underParRounds:
            goalType = .performanceZeroPenalty
            comparisonType = .greaterThan
            targetPhase = .fourMetersBlasting
        }
    }

    private func updateGoalTypeForConsistencyMetric(_ metric: ConsistencyMetric) {
        switch metric {
        case .accuracy:
            goalType = .consistencyAccuracy
            targetPhase = .eightMeters
        case .blastingScore:
            goalType = .consistencyBlastingScore
            targetPhase = .fourMetersBlasting
        case .inkasting:
            goalType = .consistencyInkasting
            targetPhase = .inkastingDrilling
        }
    }

    private var estimatedXP: Int {
        let (xp, _) = GoalService.shared.calculateBaseXP(
            sessionCount: sessionCount,
            targetPhase: targetPhase,
            daysToComplete: goalType == .volumeByDays ? daysToComplete : nil
        )
        return xp
    }

    private func saveGoal() {
        if goalCategory == .volume {
            guard sessionCount > 0 else {
                showError = "Session count must be at least 1"
                return
            }
            if goalType == .volumeByDate {
                guard endDate > Date() else {
                    showError = "Deadline must be in the future"
                    return
                }
            } else {
                guard daysToComplete > 0 else {
                    showError = "Days must be at least 1"
                    return
                }
            }
        } else if goalCategory == .performance {
            guard sessionCount > 0 else {
                showError = "Number of qualifying sessions must be at least 1"
                return
            }
        } else if goalCategory == .consistency {
            guard requiredStreak >= 2 else {
                showError = "Streak must be at least 2 consecutive sessions"
                return
            }
        }

        let finalEndDate: Date? = if goalCategory == .volume && goalType == .volumeByDate {
            endDate
        } else if goalCategory == .volume || goalCategory == .performance {
            Date().addingTimeInterval(TimeInterval(daysToComplete * 24 * 60 * 60))
        } else {
            nil
        }

        do {
            if let existing = existingGoal {
                existing.customTitle = customTitle.isEmpty ? nil : customTitle
                if goalType == .volumeByDate {
                    existing.endDate = endDate
                } else if goalCategory == .volume || goalCategory == .performance {
                    existing.daysToComplete = daysToComplete
                    existing.endDate = finalEndDate
                }
                existing.modifiedAt = Date()
                existing.needsUpload = true

                try modelContext.save()
            } else {
                let goal = try GoalService.shared.createGoal(
                    goalType: goalType,
                    targetPhase: targetPhase,
                    targetSessionType: nil,
                    targetSessionCount: goalCategory == .consistency ? 0 : sessionCount,
                    endDate: finalEndDate,
                    daysToComplete: (goalCategory == .volume && goalType == .volumeByDays) || goalCategory == .performance ? daysToComplete : nil,
                    context: modelContext
                )

                goal.customTitle = customTitle.isEmpty ? nil : customTitle

                if goalCategory == .performance {
                    goal.targetMetric = performanceMetric.rawValue
                    goal.targetValue = targetValue
                    goal.comparisonType = comparisonType.rawValue
                    goal.evaluationScope = evaluationScope.rawValue
                    goal.modifiedAt = Date()
                    goal.needsUpload = true
                }

                if goalCategory == .consistency {
                    goal.requiredStreak = requiredStreak
                    if consistencyMetric == .accuracy {
                        goal.targetValue = targetValue
                    }
                    goal.modifiedAt = Date()
                    goal.needsUpload = true
                }

                try modelContext.save()
            }

            onSave()
            dismiss()
        } catch {
            showError = "Failed to save goal: \(error.localizedDescription)"
        }
    }
}

// MARK: - GoalTextFieldRow
// Local clone of the private TextFieldRow primitive in CompetitionSettingsView.
// Kept here rather than promoted to a shared primitive — the two views own
// slightly different copy and capitalization rules.

private struct GoalTextFieldRow: View {
    let icon: String
    let tint: Color
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(KubbFont.inter(15, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(Color.Kubb.text)

            Spacer(minLength: 8)

            TextField(placeholder, text: $text)
                .font(KubbFont.inter(14))
                .foregroundStyle(Color.Kubb.text)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .frame(maxWidth: 200)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

#Preview("Create Goal") {
    GoalEditSheet(onSave: {})
        .modelContainer(for: [TrainingGoal.self], inMemory: true)
}

#Preview("Edit Goal") {
    let container = try! ModelContainer(
        for: TrainingGoal.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let goal = TrainingGoal(
        goalType: .volumeByDays,
        targetPhase: .eightMeters,
        targetSessionType: nil,
        targetSessionCount: 5,
        endDate: nil,
        daysToComplete: 14,
        baseXP: 100
    )
    container.mainContext.insert(goal)
    return GoalEditSheet(existingGoal: goal, onSave: {})
        .modelContainer(container)
}
