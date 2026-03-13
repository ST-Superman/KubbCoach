//
//  GoalEditSheet.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/10/26.
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
    @State private var endDate: Date = Date().addingTimeInterval(14 * 24 * 60 * 60) // 14 days from now
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

        // Pre-fill with existing goal values if editing
        if let goal = existingGoal {
            _customTitle = State(initialValue: goal.customTitle ?? "")
            _goalType = State(initialValue: goal.goalTypeEnum)
            _targetPhase = State(initialValue: goal.phaseEnum)
            _sessionCount = State(initialValue: goal.targetSessionCount)
            _daysToComplete = State(initialValue: goal.daysToComplete ?? 14)
            if let end = goal.endDate {
                _endDate = State(initialValue: end)
            }

            // Set category based on goal type
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
            Form {
                // Link to templates (only when creating new goal)
                if existingGoal == nil {
                    Section {
                        NavigationLink {
                            GoalTemplatesView()
                        } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                    .foregroundStyle(KubbColors.swedishBlue)
                                Text("Browse Templates")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    TextField("Custom Title (Optional)", text: $customTitle)
                        .autocorrectionDisabled()
                } header: {
                    Text("Goal Title")
                } footer: {
                    Text("Leave blank for automatic title based on goal type and progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Goal Category") {
                    Picker("Category", selection: $goalCategory) {
                        ForEach(GoalCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: goalCategory) { _, newValue in
                        updateGoalTypeForCategory(newValue)
                    }
                }

                Section("Training Phase") {
                    if goalCategory == .volume {
                        // Volume goals can be any phase
                        Picker("Phase", selection: $targetPhase) {
                            Text("Any Phase").tag(nil as TrainingPhase?)
                            ForEach(TrainingPhase.allCases) { phase in
                                Text(phase.displayName).tag(phase as TrainingPhase?)
                            }
                        }
                    } else {
                        // Performance and consistency goals are phase-specific
                        HStack {
                            Text("Phase")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(targetPhase?.displayName ?? "Select metric first")
                                .foregroundStyle(targetPhase != nil ? .primary : .secondary)
                        }
                        .font(.body)
                    }
                }

                // Category-specific sections
                switch goalCategory {
                case .volume:
                    volumeGoalSection
                case .performance:
                    performanceGoalSection
                case .consistency:
                    consistencyGoalSection
                }

                Section("Reward") {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(KubbColors.swedishGold)

                        Text("Estimated: \(estimatedXP) XP")
                            .fontWeight(.semibold)
                    }
                }

                if let error = showError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existingGoal == nil ? "Create Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(existingGoal == nil ? "Create" : "Save") {
                        saveGoal()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Goal Type Sections

    @ViewBuilder
    private var volumeGoalSection: some View {
        Section("Target") {
            Stepper("Sessions: \(sessionCount)", value: $sessionCount, in: 1...50)

            Picker("Timeframe", selection: $goalType) {
                Text("In next X days").tag(GoalType.volumeByDays)
                Text("By specific date").tag(GoalType.volumeByDate)
            }

            if goalType == .volumeByDate {
                DatePicker("Deadline", selection: $endDate, in: Date()..., displayedComponents: .date)
            } else {
                Stepper("Days: \(daysToComplete)", value: $daysToComplete, in: 1...90)
            }
        }
    }

    @ViewBuilder
    private var performanceGoalSection: some View {
        Section("Performance Target") {
            Picker("Metric", selection: $performanceMetric) {
                Text("8m Accuracy").tag(PerformanceMetric.accuracy8m)
                Text("King Accuracy").tag(PerformanceMetric.kingAccuracy)
                Text("Blasting Score").tag(PerformanceMetric.blastingScore)
                Text("Cluster Area").tag(PerformanceMetric.clusterArea)
            }
            .onChange(of: performanceMetric) { _, newValue in
                updateGoalTypeForPerformanceMetric(newValue)
            }

            Picker("Evaluation", selection: $evaluationScope) {
                ForEach([EvaluationScope.session, .anyRound, .allRounds], id: \.self) { scope in
                    Text(scope.displayName).tag(scope)
                }
            }

            Text(evaluationScope.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            switch performanceMetric {
            case .accuracy8m, .kingAccuracy:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Accuracy: \(Int(targetValue))%")
                        .font(.subheadline)

                    Slider(value: $targetValue, in: 50...100, step: 5)
                }

            case .blastingScore:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Score Target: Under \(Int(targetValue))")
                        .font(.subheadline)

                    Stepper("", value: $targetValue, in: -20...0, step: 1)
                }

            case .clusterArea:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cluster Target: Under \(String(format: "%.2f", targetValue))m²")
                        .font(.subheadline)

                    Stepper("", value: $targetValue, in: 0.1...1.0, step: 0.05)
                }

            default:
                EmptyView()
            }

            Stepper("Qualifying Sessions: \(sessionCount)", value: $sessionCount, in: 1...10)

            Stepper("Days to Complete: \(daysToComplete)", value: $daysToComplete, in: 1...90)
        }
    }

    @ViewBuilder
    private var consistencyGoalSection: some View {
        Section("Consistency Target") {
            Picker("Metric", selection: $consistencyMetric) {
                Text("Accuracy Streak").tag(ConsistencyMetric.accuracy)
                Text("Under-Par Streak").tag(ConsistencyMetric.blastingScore)
                Text("Zero Outliers").tag(ConsistencyMetric.inkasting)
            }
            .onChange(of: consistencyMetric) { _, newValue in
                updateGoalTypeForConsistencyMetric(newValue)
            }

            switch consistencyMetric {
            case .accuracy:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maintain \(Int(targetValue))% Accuracy")
                        .font(.subheadline)

                    Slider(value: $targetValue, in: 50...100, step: 5)
                }

            case .blastingScore:
                Text("Score under par (negative score)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            case .inkasting:
                Text("Zero outliers in session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Stepper("Consecutive Sessions: \(requiredStreak)", value: $requiredStreak, in: 2...10)
        }

        Section {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("Consistency goals are all-or-nothing. Breaking the streak fails the goal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func updateGoalTypeForCategory(_ category: GoalCategory) {
        switch category {
        case .volume:
            goalType = .volumeByDays
            // Volume goals can have any phase (set to nil by default)
        case .performance:
            goalType = .performanceAccuracy
            performanceMetric = .accuracy8m
            targetValue = 70.0
            comparisonType = .greaterThan
            targetPhase = .eightMeters  // Accuracy requires 8m
        case .consistency:
            goalType = .consistencyAccuracy
            consistencyMetric = .accuracy
            targetValue = 70.0
            requiredStreak = 3
            targetPhase = .eightMeters  // Accuracy requires 8m
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
        // Validation
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

        // Calculate end date
        let finalEndDate: Date? = if goalCategory == .volume && goalType == .volumeByDate {
            endDate
        } else if goalCategory == .volume || goalCategory == .performance {
            Date().addingTimeInterval(TimeInterval(daysToComplete * 24 * 60 * 60))
        } else {
            nil  // Consistency goals have no deadline
        }

        do {
            if let existing = existingGoal {
                // Update existing goal (limited editing: can only change deadline and title)
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
                // Create new goal
                let goal = try GoalService.shared.createGoal(
                    goalType: goalType,
                    targetPhase: targetPhase,
                    targetSessionType: nil,
                    targetSessionCount: goalCategory == .consistency ? 0 : sessionCount,
                    endDate: finalEndDate,
                    daysToComplete: (goalCategory == .volume && goalType == .volumeByDays) || goalCategory == .performance ? daysToComplete : nil,
                    context: modelContext
                )

                // Set custom title
                goal.customTitle = customTitle.isEmpty ? nil : customTitle

                // Set performance-specific fields
                if goalCategory == .performance {
                    goal.targetMetric = performanceMetric.rawValue
                    goal.targetValue = targetValue
                    goal.comparisonType = comparisonType.rawValue
                    goal.evaluationScope = evaluationScope.rawValue
                    goal.modifiedAt = Date()
                    goal.needsUpload = true
                }

                // Set consistency-specific fields
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
