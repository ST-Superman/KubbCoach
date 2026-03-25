# Code Review: GoalService.swift

**Date**: 2026-03-25
**File**: `Kubb Coach/Kubb Coach/Services/GoalService.swift`
**Lines**: 577

---

## Summary

**Overall Quality**: ⭐⭐⭐⭐☆ (4/5)

**Strengths**:
- ✅ Comprehensive goal evaluation system
- ✅ Supports multiple goal types (volume, performance, consistency)
- ✅ Well-organized with clear MARK sections
- ✅ Good XP calculation with bonuses
- ✅ Analytics integration
- ✅ Multiple concurrent goals support

**Issues**:
1. **MEDIUM**: Dangerous use of Int.max and Double.infinity for missing values (lines 159, 161, 186)
2. **MEDIUM**: Duplicate expiration checks creating redundant logic (lines 362-365, 390)
3. **LOW**: Silent error handling with try? (line 74)
4. **LOW**: Comparison operators inconsistent (>= vs >, <= vs <)

---

## Recommendations

### 1. Fix Dangerous Default Values (MEDIUM Priority)

**Current Issue (Lines 159, 161, 186)**: Using Int.max and Double.infinity as defaults for missing values can break comparison logic and cause unexpected results.

**Lines 159, 161**:
```swift
case .blastingScore:
    return Double(session.totalSessionScore ?? Int.max)  // DANGEROUS
case .clusterArea:
    return session.averageClusterArea(context: context) ?? Double.infinity  // DANGEROUS
```

**Line 186**:
```swift
if let analysis = round.fetchInkastingAnalysis(context: context) {
    return analysis.clusterAreaSquareMeters
}
return Double.infinity  // DANGEROUS
```

**Recommended fix**:
```swift
private func getSessionLevelMetric(session: TrainingSession, metric: String, context: ModelContext) -> Double? {
    switch PerformanceMetric(rawValue: metric) {
    case .accuracy8m:
        return session.accuracy
    case .kingAccuracy:
        return session.kingThrowAccuracy
    case .blastingScore:
        guard let score = session.totalSessionScore else { return nil }
        return Double(score)
    case .clusterArea:
        return session.averageClusterArea(context: context)
    case .underParRounds:
        return Double(session.underParRoundsCount)
    default:
        return nil
    }
}

// Update caller to handle nil:
private func evaluatePerformanceGoal(
    _ goal: TrainingGoal,
    session: TrainingSession,
    context: ModelContext
) -> Bool {
    guard let metric = goal.targetMetric,
          let targetValue = goal.targetValue,
          let comparison = goal.comparisonType else { return false }

    // ... scope logic ...

    // Get the value to compare based on scope
    guard let actualValue = getSessionLevelMetric(session: session, metric: metric, context: context) else {
        // Missing data - cannot evaluate
        return false
    }

    // Compare session-level value
    return compareValues(actualValue, targetValue, comparison: comparison)
}
```

Apply similar pattern to `getRoundLevelMetric()`.

### 2. Remove Duplicate Expiration Checks (MEDIUM Priority)

**Current Issue (Lines 362-365 and 390)**: Expiration is checked twice in volume goal evaluation, creating confusing logic.

**Current code**:
```swift
} else {
    // VOLUME GOAL: Original logic
    if goal.isExpired && goal.statusEnum == .active {  // Line 362
        goal.status = GoalStatus.failed.rawValue
        goal.failedAt = Date()
    }

    // ... counting logic ...

    // Check for completion or failure
    if goal.completedSessionCount >= goal.targetSessionCount {
        // ... completion logic ...
    } else if goal.isExpired && goal.statusEnum == .active {  // Line 390 - DUPLICATE
        // ... failure logic ...
    }
}
```

**Recommended fix**:
```swift
} else {
    // VOLUME GOAL: Original logic

    // Avoid duplicate counting
    if !goal.completedSessionIds.contains(session.id) {
        goal.completedSessionCount += 1
        goal.completedSessionIds.append(session.id)
        goal.lastProgressUpdate = Date()
        goal.modifiedAt = Date()
        goal.needsUpload = true
    }

    // Check for completion or failure
    if goal.completedSessionCount >= goal.targetSessionCount {
        // Goal completed!
        goal.status = GoalStatus.completed.rawValue
        goal.completedAt = Date()
        goal.modifiedAt = Date()
        goal.needsUpload = true

        // Calculate XP with potential bonus
        xpAwarded = calculateXPReward(for: goal, completionPercentage: 100.0)
        goal.bonusXP = xpAwarded - goal.baseXP
        goal.xpAwarded = true

        statusChanged = true
    } else if goal.isExpired && goal.statusEnum == .active {
        // Goal failed (deadline passed) - check once here
        goal.status = GoalStatus.failed.rawValue
        goal.failedAt = Date()
        goal.modifiedAt = Date()
        goal.needsUpload = true

        // Award partial credit if >= 60% complete
        let completionPercentage = goal.progressPercentage
        if completionPercentage >= 60.0 {
            xpAwarded = calculateXPReward(for: goal, completionPercentage: completionPercentage)
            goal.xpAwarded = true
        }

        statusChanged = true
    }
}
```

### 3. Improve Error Handling (LOW Priority)

**Line 74**: Replace try? with explicit error handling:
```swift
func getActiveGoals(limit: Int = 5, context: ModelContext) -> [TrainingGoal] {
    let descriptor = FetchDescriptor<TrainingGoal>(
        predicate: #Predicate { $0.status == "active" },
        sortBy: [
            SortDescriptor(\.priority),
            SortDescriptor(\.createdAt, order: .reverse)
        ]
    )

    do {
        let goals = try context.fetch(descriptor)
        return Array(goals.prefix(limit))
    } catch {
        AppLogger.database.error("Failed to fetch active goals: \(error.localizedDescription)")
        return []
    }
}
```

### 4. Clarify Comparison Operators (LOW Priority)

**Line 198-199**: The operators use >= and <= which means "greater than or equal" and "less than or equal". This is correct for most goals, but the naming is confusing.

**Current**:
```swift
private func compareValues(_ actual: Double, _ target: Double, comparison: String) -> Bool {
    switch ComparisonType(rawValue: comparison) {
    case .greaterThan:
        return actual >= target  // "Greater than or equal"
    case .lessThan:
        return actual <= target  // "Less than or equal"
    default:
        return false
    }
}
```

**Options**:
1. Keep current logic but add comment explaining inclusive comparison
2. Rename enum to `greaterThanOrEqual` and `lessThanOrEqual`
3. Add strict comparison types if needed

**Recommended (add comment)**:
```swift
private func compareValues(_ actual: Double, _ target: Double, comparison: String) -> Bool {
    switch ComparisonType(rawValue: comparison) {
    case .greaterThan:
        // Inclusive: actual >= target (meets or exceeds goal)
        return actual >= target
    case .lessThan:
        // Inclusive: actual <= target (meets or beats target)
        return actual <= target
    default:
        return false
    }
}
```

---

## Architecture Analysis

**Design Pattern**: Singleton service
**Thread Safety**: Not marked @MainActor, but all methods access ModelContext (should be called from main thread)

**Integration Points**:
- TrainingGoal model
- TrainingSession model
- GoalAnalytics model
- PlayerLevelService (XP awards)

**Evaluation Logic**: ✅ Well-structured with separate methods for each goal type

---

## Code Quality Assessment

### Positive Patterns
1. **Comprehensive evaluation**: Handles volume, performance, and consistency goals
2. **XP system**: Includes base XP, bonuses, and partial credit
3. **Progress tracking**: Prevents duplicate session counting
4. **Analytics integration**: Tracks outcomes for difficulty adjustment

### Areas for Improvement
1. **Nil handling**: Using sentinel values (Int.max, infinity) instead of optionals
2. **Duplicate logic**: Expiration checked multiple times
3. **Error propagation**: Some methods silently fail instead of throwing
4. **Thread safety**: Should document MainActor requirement

---

## Testing Considerations

**Testability**: ✅ Good - can inject ModelContext for testing
**Covered**: Goal evaluation logic (18 tests in GoalServiceTests)
**Missing Coverage**:
- Edge case: nil values in performance metrics
- Edge case: expired goals with partial completion
- Concurrent goal updates

---

## Next Steps

1. ✅ **MEDIUM**: Fix dangerous default values (Int.max, infinity)
2. ✅ **MEDIUM**: Remove duplicate expiration checks
3. ⏭️ **LOW**: Improve error handling with explicit logging
4. ⏭️ **LOW**: Clarify comparison operator behavior with comments

---

**Status**: Needs fixes for dangerous defaults
**Build Required**: Yes (after changes)
