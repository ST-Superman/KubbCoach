# Code Review: TrainingSessionManager.swift

**Date**: 2026-03-25
**File**: `Kubb Coach/Kubb Coach/Services/TrainingSessionManager.swift`
**Lines**: 561

---

## Summary

**Overall Quality**: ⭐⭐⭐⭐☆ (4/5)

**Strengths**:
- ✅ Excellent separation of concerns (session/round/throw management)
- ✅ Good logging throughout
- ✅ Platform-specific code isolation (#if os(iOS))
- ✅ Comprehensive integration with service layer
- ✅ Proper handling of SwiftData array ordering (line 372)
- ✅ Clear API design with @discardableResult where appropriate

**Issues**:
1. **MEDIUM**: Silent error fallback with `try? modelContext.save()` after catching errors could hide failures
2. **LOW**: Multiple save operations could be consolidated for efficiency
3. **LOW**: Missing @MainActor annotations on methods accessing ModelContext

---

## Recommendations

### 1. Improve Error Handling (MEDIUM Priority)

**Current Issue**: After catching save errors, the code silently retries with `try? modelContext.save()` which swallows the error. This makes debugging difficult.

**Lines affected**: 206, 239, 281, 355, 387, 424, 558

**Recommendation**: Log retry attempts and final failure state.

**Example fix for line 206**:
```swift
// Save again with PB and milestone IDs
do {
    try modelContext.save()
} catch {
    AppLogger.training.error("❌ Failed to save session with PB and milestones: \(error.localizedDescription)")
    // Retry once
    do {
        try modelContext.save()
        AppLogger.training.info("✅ Session save succeeded on retry")
    } catch {
        AppLogger.training.error("❌ Session save failed after retry: \(error.localizedDescription)")
    }
}
```

Apply similar pattern to lines: 239, 281, 355, 387, 424, 558

### 2. Add Thread Safety Documentation (LOW Priority)

**Issue**: Only `getMostRecentSession()` is marked @MainActor, but all ModelContext operations should document thread requirements.

**Recommendation**: Add documentation comment to class explaining thread safety:

```swift
/// Manages the lifecycle of training sessions, rounds, and throws
///
/// Thread Safety:
/// - All methods that access ModelContext must be called on the main actor
/// - The `@Observable` macro automatically handles state updates on the main thread
/// - Call from UI contexts or wrap in `await MainActor.run { }`
@Observable
final class TrainingSessionManager {
```

### 3. Consolidate Save Operations (LOW Priority)

**Current**: `completeSession()` has 3 separate save calls (lines 202, 236, potentially more via service calls)

**Recommendation**: Consider batching updates and saving once at the end. However, this may be intentional for data durability, so only refactor if performance issues arise.

---

## Architecture Analysis

**Design Pattern**: Service Manager with Observable state
**Dependencies**:
- ✅ Properly injected (ModelContext via init)
- ✅ Service calls are well-encapsulated

**Integration Points**:
- PersonalBestService
- MilestoneService
- GoalService
- DailyChallengeService
- StatisticsAggregator
- StreakCalculator
- NotificationService (iOS only)

**Platform Handling**: ✅ Excellent - iOS-specific features properly gated with `#if os(iOS)`

---

## Code Quality Assessment

### Positive Patterns
1. **Clear method naming**: `startSession()`, `completeRound()`, `undoLastThrow()`
2. **Good state management**: Uses `currentSession` and `currentRound` observables
3. **Proper deletion**: `cancelSession()` properly cleans up related data
4. **Array ordering awareness**: Line 372 - sorts throws before accessing (preventing undo bug)

### Areas for Improvement
1. **Input validation**: Methods don't validate parameters (e.g., negative rounds)
2. **State validation**: Methods don't check preconditions (e.g., calling `completeRound()` on already-completed round)
3. **Error propagation**: Consider throwing errors instead of logging and continuing

---

## Testing Considerations

**Testability**: ✅ Good - can inject ModelContext for testing
**Covered**: Session lifecycle, round management, throw recording
**Missing Coverage**:
- Error recovery scenarios
- Concurrent session attempts
- State validation edge cases

---

## Next Steps

1. ✅ **MEDIUM**: Improve error handling with better retry logging
2. ⏭️ **LOW**: Add thread safety documentation
3. ⏭️ **LOW**: Consider consolidating saves if performance issues arise

---

**Status**: Ready for improvements
**Build Required**: Yes (after changes)
