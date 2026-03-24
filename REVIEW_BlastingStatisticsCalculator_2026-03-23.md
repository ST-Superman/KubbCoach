# Code Review: BlastingStatisticsCalculator.swift

**Date:** 2026-03-23
**Reviewer:** Claude Code Agent
**File:** `/Users/sthompson/Developer/Kubb-Coach/Kubb Coach/Kubb Coach/Services/BlastingStatisticsCalculator.swift`

---

## 1. File Overview

### Purpose
Encapsulates statistical calculations for blasting (4-meter) training sessions, computing all statistics once during initialization for optimal performance.

### Key Responsibilities
- Calculate aggregate statistics for blasting sessions (average scores, best sessions, trends)
- Provide cached computed values for UI display
- Support golf scoring analysis (par, birdie, eagle, etc.)
- Track under-par streaks and per-round performance

### Dependencies
- Foundation (core types)
- SwiftUI (Color type)
- SessionDisplayItem (data model)
- GolfScore (scoring logic)

---

## 2. Architecture Analysis

### Design Patterns
- **Value Type (Struct)**: Immutable calculator with pre-computed statistics
- **Eager Computation**: All calculations performed at initialization
- **Cache Pattern**: Results stored in properties for O(1) access

### Strengths
- Immutable design prevents state bugs
- Single computation pass is efficient
- Clear separation of calculation logic
- Performance instrumentation in debug builds

### Separation of Concerns
- Calculation logic isolated from presentation
- Pure functions for all statistical operations
- Supporting types properly separated

---

## 3. Code Quality

### Swift Best Practices
✅ **Excellent:**
- Proper use of struct for value semantics
- Static private functions for calculations
- Guard statements for early returns
- Nil-coalescing for optional handling
- Functional programming patterns (reduce, map, filter)

### Error Handling
⚠️ **Needs Improvement:**
- No error handling for invalid input data
- Assumes all sessions have valid data
- Silent failures with default values (0, "N/A")

### Optionals Management
✅ **Good:**
- Consistent use of nil-coalescing (`??`)
- Guard statements for empty collections
- No force-unwrapping

### Performance
✅ **Excellent:**
- Single-pass computation
- O(n) complexity for most operations
- Performance timing in debug builds
- Efficient use of built-in algorithms

---

## 4. Performance Considerations

### Strengths
- Pre-computation avoids repeated calculations
- Efficient functional operations
- Warning for calculations exceeding 100ms

### Potential Issues
1. **Memory overhead**: Stores full sorted array duplicate
2. **Large dataset handling**: No pagination or limiting for massive session counts
3. **Redundant sorting**: sortedSessions created but not always needed

### Recommendations
- Consider lazy evaluation for rarely-used statistics
- Add thresholds for very large datasets (>1000 sessions)

---

## 5. Security & Data Safety

### Data Validation
⚠️ **Missing:**
- No validation that sessions contain valid data
- No bounds checking on round numbers (1-9 assumption)
- No verification of sessionScore consistency

### Privacy
✅ **Good:**
- No personal data exposure
- Debug logging appropriate for development

---

## 6. Testing Considerations

### Current Testability
✅ **Excellent:**
- Pure functions are easily testable
- Deterministic outputs
- No external dependencies
- Value type simplifies test setup

### Test Coverage Areas
Existing tests should cover:
- Empty session array
- Single session
- Multiple sessions
- Edge cases (nil scores, missing rounds)
- Performance benchmarks

### Missing Test Cases
- Invalid round numbers outside 1-9 range
- Sessions with incomplete round data
- Very large datasets (1000+ sessions)
- Concurrent access patterns

---

## 7. Issues Found

### Critical Issues
None identified.

### Potential Bugs

**Issue 1: Inconsistent Round Number Assumptions**
```swift
for roundNumber in 1...9 {  // Line 205
```
- **Risk**: Hardcoded range assumes 9 rounds max
- **Impact**: Won't handle sessions with different round counts
- **Fix**: Determine max rounds dynamically from data

**Issue 2: Best Session Logic Bug**
```swift
guard let session = sessions.min(by: { ($0.sessionScore ?? 0) < ($1.sessionScore ?? 0) }) else {
```
- **Risk**: If all sessions have nil scores, returns first session as "best"
- **Impact**: Incorrect best session identification
- **Fix**: Filter out nil scores before finding minimum

**Issue 3: Trend Calculation Edge Case**
```swift
let recentCount = min(sortedSessions.count / 2, StatisticsConstants.maxRecentSessionsForTrend)
```
- **Risk**: With 4 sessions (minimum), recentCount = 2, but splits at different positions
- **Impact**: Asymmetric comparison (recent vs older)
- **Fix**: Ensure equal-sized groups or document the asymmetry

### Code Smells

**Smell 1: Magic Numbers**
- Lines 56, 78-84: Hardcoded thresholds (100ms, golf scoring)
- **Refactor**: Move to StatisticsConstants enum

**Smell 2: Duplicate Sorting Logic**
```swift
self.sortedSessions = sessions.sorted { $0.createdAt < $1.createdAt }  // Line 39
let sortedRounds = sortedSessions.flatMap { session in
    session.roundSummaries.sorted { $0.roundNumber < $1.roundNumber }  // Line 185-186
```
- **Issue**: Sorting happens multiple times
- **Fix**: Consider caching sorted rounds

**Smell 3: Debug Logging Inconsistency**
- Some methods have debug warnings, others don't
- **Fix**: Standardize logging strategy

---

## 8. Recommendations

### High Priority

**HP-1: Fix Best Session Bug**
```swift
private static func findBestSession(_ sessions: [SessionDisplayItem]) -> (SessionDisplayItem?, Int) {
    let validSessions = sessions.filter { $0.sessionScore != nil }
    guard let session = validSessions.min(by: { $0.sessionScore! < $1.sessionScore! }) else {
        return (nil, 0)
    }
    return (session, session.sessionScore!)
}
```

**HP-2: Dynamic Round Number Detection**
```swift
private static func calculatePerRoundAverages(_ sessions: [SessionDisplayItem]) -> [Int: Double] {
    let maxRound = sessions.flatMap { $0.roundSummaries }.map { $0.roundNumber }.max() ?? 9
    var averages: [Int: Double] = [:]

    for roundNumber in 1...maxRound {
        // existing logic
    }
    return averages
}
```

**HP-3: Add Input Validation**
```swift
init(sessions: [SessionDisplayItem]) {
    guard !sessions.isEmpty else {
        // Initialize with empty/default values
        self.sessions = []
        self.sortedSessions = []
        // ... set all properties to safe defaults
        return
    }
    // existing logic
}
```

### Medium Priority

**MP-1: Move Magic Numbers to Constants**
```swift
enum StatisticsConstants {
    static let minimumSessionsForTrend = 4
    static let maxRecentSessionsForTrend = 5
    static let trendImprovementThreshold = -2.0
    static let trendDeclineThreshold = 2.0
    static let topGolfScoresLimit = 2
    static let performanceWarningThresholdMs = 100.0  // NEW
    static let parScore = 0  // NEW
    static let maxExpectedRounds = 9  // NEW
}
```

**MP-2: Optimize Memory Usage**
```swift
// Only sort when needed for trend/streak calculations
private static func sortSessionsIfNeeded(_ sessions: [SessionDisplayItem], forTrend: Bool, forStreak: Bool) -> [SessionDisplayItem] {
    if forTrend || forStreak {
        return sessions.sorted { $0.createdAt < $1.createdAt }
    }
    return []
}
```

**MP-3: Add Error Result Type**
```swift
enum StatisticsError: Error {
    case noValidData
    case insufficientData
    case invalidRoundNumbers
}

// Return Result types for critical calculations
func calculateStatistics() -> Result<BlastingStatistics, StatisticsError> {
    // validation and calculation
}
```

**MP-4: Improve Debug Logging**
```swift
private static func logDebugInfo(_ message: String, level: LogLevel = .info) {
    #if DEBUG
    let prefix = level == .warning ? "⚠️" : "📊"
    print("\(prefix) BlastingStatisticsCalculator: \(message)")
    #endif
}
```

### Nice-to-Have

**NH-1: Add Documentation Comments**
- Add doc comments for all public methods
- Document performance characteristics
- Include usage examples

**NH-2: Support Async Computation**
- For very large datasets, consider async/await
- Add progress reporting capability

**NH-3: Add Caching Strategy**
- Cache results keyed by session set
- Invalidate on data changes

---

## 9. Compliance Checklist

### iOS Best Practices
- ✅ Value types for data structures
- ✅ Swift concurrency not needed (synchronous calculations)
- ✅ No force-unwrapping
- ⚠️ Missing comprehensive input validation

### Performance Guidelines
- ✅ Pre-computation strategy
- ✅ Performance monitoring
- ⚠️ No handling for extremely large datasets

### Code Style
- ✅ Consistent naming conventions
- ✅ Proper MARK comments
- ✅ Clear structure
- ⚠️ Some magic numbers

### Testing Requirements
- ⚠️ No unit tests present in file (should exist separately)
- ✅ Highly testable design

---

## 10. Summary

### Overall Assessment
**Quality Score: 8/10**

This is a well-designed, performant calculator with clean separation of concerns. The eager computation strategy is appropriate for the use case, and the code is highly testable. Main issues are around edge case handling and input validation.

### Key Strengths
1. Excellent performance characteristics
2. Immutable value type design
3. Pure functional calculation methods
4. Clear structure and organization

### Key Weaknesses
1. Missing input validation
2. Hardcoded assumptions about round counts
3. Best session logic doesn't handle all-nil case properly
4. Some magic numbers should be constants

### Recommendation
**APPROVE with REQUIRED FIXES**

Implement HP-1 through HP-3 before production use. The MP items should be prioritized for the next refactoring cycle.

---

**Review completed:** 2026-03-23
**Next review recommended:** After addressing high-priority items
