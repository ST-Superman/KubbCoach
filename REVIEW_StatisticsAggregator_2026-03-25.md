# Code Review: StatisticsAggregator.swift

**Date**: 2026-03-25
**File**: `Kubb Coach/Kubb Coach/Services/StatisticsAggregator.swift`
**Lines**: 263

---

## Summary

**Overall Quality**: ⭐⭐⭐⭐☆ (4/5)

**Strengths**:
- ✅ Excellent thread safety with @MainActor
- ✅ Clean separation of phase-specific metrics
- ✅ Efficient predicate-based queries
- ✅ Comprehensive rebuild functionality
- ✅ Platform-specific compilation (#if os(iOS))

**Issues**:
1. **MEDIUM**: Logic error in best accuracy tracking (line 104-113)
2. **LOW**: Silent error handling with try? (line 261)
3. **LOW**: Error recovery could be improved (lines 66, 89, 224, 236)

---

## Recommendations

### 1. Fix Best Accuracy Logic (MEDIUM Priority)

**Current Issue (Lines 104-113)**: The code compares `session.accuracy` to `aggregate.averageEightMeterAccuracy` instead of tracking the actual best accuracy value. This means the "best" session ID might not point to the actual best session.

**Current code**:
```swift
// Update best accuracy if needed
if aggregate.bestEightMeterAccuracySessionId != nil {
    // Keep existing best unless this session is better
    // (In practice, we'd compare accuracies, but we'll simplify by checking if this is a new best)
    if session.accuracy > aggregate.averageEightMeterAccuracy {
        aggregate.bestEightMeterAccuracySessionId = session.id
    }
} else {
    aggregate.bestEightMeterAccuracySessionId = session.id
}
```

**Recommended fix**:
```swift
// Update best accuracy if needed
if let bestAccuracy = aggregate.bestEightMeterAccuracy {
    if session.accuracy > bestAccuracy {
        aggregate.bestEightMeterAccuracy = session.accuracy
        aggregate.bestEightMeterAccuracySessionId = session.id
    }
} else {
    // First session
    aggregate.bestEightMeterAccuracy = session.accuracy
    aggregate.bestEightMeterAccuracySessionId = session.id
}
```

**Note**: This requires adding `bestEightMeterAccuracy: Double?` property to `SessionStatisticsAggregate` model.

**Alternative (if can't modify model)**: Fetch the best session and compare:
```swift
// Keep logic simpler by just tracking ID - comparison should be done at query time
if aggregate.bestEightMeterAccuracySessionId == nil {
    aggregate.bestEightMeterAccuracySessionId = session.id
}
// Note: For accurate "best" tracking, fetch and compare at query time
```

### 2. Improve Error Handling (LOW Priority)

**Line 261**: Replace `try?` with explicit error handling:
```swift
static func getAggregate(
    for phase: TrainingPhase,
    timeRange: StatTimeRange,
    context: ModelContext
) -> SessionStatisticsAggregate? {
    let targetPhaseRawValue = phase.rawValue
    let targetTimeRangeRawValue = timeRange.rawValue
    var descriptor = FetchDescriptor<SessionStatisticsAggregate>(
        predicate: #Predicate { $0.phaseRawValue == targetPhaseRawValue && $0.timeRangeRawValue == targetTimeRangeRawValue }
    )
    descriptor.fetchLimit = 1

    do {
        return try context.fetch(descriptor).first
    } catch {
        logger.error("Failed to fetch aggregate for \(phase.rawValue) - \(timeRange.rawValue): \(error.localizedDescription)")
        return nil
    }
}
```

### 3. Add Safety Check for Empty Rounds (LOW Priority)

**Line 119**: Add guard before iterating rounds:
```swift
private static func updateEightMeterMetrics(aggregate: SessionStatisticsAggregate, session: TrainingSession) {
    aggregate.totalEightMeterSessions += 1
    aggregate.totalEightMeterThrows += session.totalThrows
    aggregate.totalEightMeterHits += session.totalHits

    // Recalculate average accuracy
    let totalAccuracy = aggregate.averageEightMeterAccuracy * Double(aggregate.totalEightMeterSessions - 1) + session.accuracy
    aggregate.averageEightMeterAccuracy = totalAccuracy / Double(aggregate.totalEightMeterSessions)

    // Update best accuracy (see recommendation #1)
    // ... (fixed logic)

    // Calculate hit streak for this session
    guard !session.rounds.isEmpty else {
        return
    }

    var currentStreak = 0
    var maxStreak = 0

    // ... rest of streak calculation
}
```

---

## Architecture Analysis

**Design Pattern**: Static utility service with @MainActor
**Thread Safety**: ✅ Excellent - all methods protected by @MainActor

**Integration Points**:
- SessionStatisticsAggregate model
- TrainingSession model
- ModelContext for persistence

**Platform Handling**: ✅ Good - iOS-specific inkasting metrics properly gated

---

## Code Quality Assessment

### Positive Patterns
1. **Incremental updates**: Only recalculates affected aggregates
2. **Time range filtering**: Efficient date-based filtering
3. **Rebuild capability**: Can recover from corruption
4. **Logging**: Comprehensive error logging

### Areas for Improvement
1. **Best value tracking**: Need to store actual best values, not just IDs
2. **Error recovery**: Silent failures could hide data inconsistencies
3. **Batch operations**: Consider batching for multiple session updates

---

## Testing Considerations

**Testability**: ✅ Good - static methods easy to test
**Covered**: Basic aggregate updates
**Missing Coverage**:
- Edge case: empty rounds/sessions
- Edge case: concurrent aggregate updates
- Rebuild with corrupted data
- Best value tracking accuracy

---

## Next Steps

1. ✅ **MEDIUM**: Fix best accuracy tracking logic
2. ⏭️ **LOW**: Improve error handling with explicit logging
3. ⏭️ **LOW**: Add safety check for empty rounds

---

**Status**: Needs logic fix for best accuracy
**Build Required**: Yes (after changes)
**Model Change Required**: Yes (add bestEightMeterAccuracy property)
