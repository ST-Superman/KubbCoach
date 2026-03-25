# Code Review: MilestoneService.swift

**Date**: 2026-03-25
**File**: `Kubb Coach/Kubb Coach/Services/MilestoneService.swift`
**Lines**: 270

---

## Summary

**Overall Quality**: ⭐⭐⭐⭐☆ (4/5)

**Strengths**:
- ✅ Excellent @MainActor thread safety
- ✅ Well-organized milestone categories
- ✅ Platform-specific compilation
- ✅ Migration support for existing data
- ✅ Clear milestone checking logic

**Issues**:
1. **MEDIUM**: Hit streak milestone logic backwards (lines 129-137)
2. **LOW**: Silent error handling with try? throughout
3. **LOW**: Duplicate hit streak calculation logic

---

## Recommendations

### 1. Fix Hit Streak Milestone Logic (MEDIUM Priority)

**Current Issue (Lines 129-137)**: The nested if-else prevents awarding the 5-hit streak milestone to users who achieved a 10-hit streak. A user who gets 10 hits in a row should earn BOTH the 5-hit AND 10-hit milestones.

**Current code**:
```swift
let maxStreak = calculateMaxHitStreak(session: session)
if maxStreak >= 10 && !hasEarned(milestoneId: "hit_streak_10") {
    if let milestone = MilestoneDefinition.get(by: "hit_streak_10") {
        earned.append(milestone)
    }
} else if maxStreak >= 5 && !hasEarned(milestoneId: "hit_streak_5") {  // BUG: Won't execute if maxStreak >= 10
    if let milestone = MilestoneDefinition.get(by: "hit_streak_5") {
        earned.append(milestone)
    }
}
```

**Recommended fix**:
```swift
let maxStreak = calculateMaxHitStreak(session: session)

// Award 5-hit streak milestone if applicable
if maxStreak >= 5 && !hasEarned(milestoneId: "hit_streak_5") {
    if let milestone = MilestoneDefinition.get(by: "hit_streak_5") {
        earned.append(milestone)
    }
}

// Award 10-hit streak milestone if applicable (separate check)
if maxStreak >= 10 && !hasEarned(milestoneId: "hit_streak_10") {
    if let milestone = MilestoneDefinition.get(by: "hit_streak_10") {
        earned.append(milestone)
    }
}
```

### 2. Improve Error Handling (LOW Priority)

**Affected Lines**: 39, 185, 212, 223, 241

**Issue**: Silent try? can lose milestone data if save fails.

**Example fix for line 39**:
```swift
// Persist earned milestones
for milestone in newMilestones {
    let earned = EarnedMilestone(milestoneId: milestone.id, sessionId: session.id)
    modelContext.insert(earned)
}

do {
    try modelContext.save()
} catch {
    AppLogger.database.error("Failed to save earned milestones: \(error.localizedDescription)")
    // Retry once
    try? modelContext.save()
}
```

Apply similar pattern to other try? usages.

### 3. Extract Hit Streak Calculation (LOW Priority)

**Current**: `calculateMaxHitStreak()` is duplicated in StatisticsAggregator.swift (lines 116-128)

**Recommendation**: Extract to a shared utility or extension on TrainingSession:

```swift
// In TrainingSession.swift or SessionUtilities.swift
extension TrainingSession {
    /// Calculate the maximum hit streak across all rounds
    func calculateMaxHitStreak() -> Int {
        var currentStreak = 0
        var maxStreak = 0

        for round in rounds {
            for throwRecord in round.throwRecords {
                if throwRecord.result == .hit {
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                } else {
                    currentStreak = 0
                }
            }
        }

        return maxStreak
    }
}
```

Then use:
```swift
let maxStreak = session.calculateMaxHitStreak()
```

---

## Architecture Analysis

**Design Pattern**: Service class with ModelContext dependency
**Thread Safety**: ✅ Excellent - @MainActor protects all operations

**Integration Points**:
- MilestoneDefinition (static definitions)
- EarnedMilestone model
- TrainingSession model
- StreakCalculator utility

**Milestone Categories**:
- Session count
- Streak
- Performance (phase-specific)

---

## Code Quality Assessment

### Positive Patterns
1. **Clear organization**: Separate methods for each milestone category
2. **Deduplication**: hasEarned() check prevents duplicate awards
3. **Migration support**: Can backfill milestones from existing data
4. **Platform handling**: iOS-specific milestones properly gated

### Areas for Improvement
1. **Error resilience**: Silent failures could lose milestone awards
2. **Code reuse**: Hit streak calculation duplicated
3. **Validation**: No check that milestone IDs exist in definitions
4. **Logic bug**: Hit streak milestone logic prevents earning both

---

## Testing Considerations

**Testability**: ✅ Good - can inject ModelContext for testing
**Covered**: Milestone checking logic (14 tests in MilestoneServiceTests)
**Missing Coverage**:
- Edge case: user earns both 5 and 10-hit streak milestones
- Edge case: save failure during milestone award
- Migration with large session counts

---

## Next Steps

1. ✅ **MEDIUM**: Fix hit streak milestone logic (remove else if)
2. ⏭️ **LOW**: Improve error handling throughout
3. ⏭️ **LOW**: Extract hit streak calculation to shared utility

---

**Status**: Needs logic fix for hit streaks
**Build Required**: Yes (after changes)
