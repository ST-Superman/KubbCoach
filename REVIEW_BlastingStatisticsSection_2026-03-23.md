# Code Review: BlastingStatisticsSection.swift

**File**: `Kubb Coach/Kubb Coach/Views/Statistics/BlastingStatisticsSection.swift`
**Date**: 2026-03-23
**Reviewer**: Claude Code
**Lines of Code**: 501

---

## 1. File Overview

### Purpose
`BlastingStatisticsSection` is a SwiftUI view component that displays comprehensive statistical analysis for 4-meter blasting training sessions in the Kubb Coach app. It provides golfers with visual insights into their performance across multiple dimensions.

### Key Responsibilities
- Aggregates and displays key blasting metrics (session count, averages, personal bests)
- Visualizes score trends over time using Swift Charts
- Shows per-round performance breakdown by kubb count
- Tracks golf-style achievements (birdies, eagles, albatrosses, condors)
- Calculates and displays personal records and streaks

### Dependencies
- **SwiftUI**: UI framework
- **Charts**: Apple's charting framework for data visualization
- **SessionDisplayItem**: Unified enum for local/cloud session data
- **GolfScore**: Golf scoring model (par, birdie, eagle, etc.)
- **UI Components**: MetricCard, RecordCard, GolfScoreBadge
- **Design System**: DesignConstants, KubbColors, view modifiers

### Integration Points
- Consumed by parent statistics view with session data
- Works with both local SwiftData sessions and CloudKit cloud sessions
- Uses shared design system components

---

## 2. Architecture Analysis

### Design Patterns

✅ **SOLID Principles Adherence**
- **Single Responsibility**: View focuses solely on statistics display (computation logic self-contained)
- **Open/Closed**: Extends SessionDisplayItem without modifying it
- **Liskov Substitution**: Properly handles both .local and .cloud session cases
- **Interface Segregation**: Clean, minimal public API (only requires sessions array)
- **Dependency Inversion**: Depends on SessionDisplayItem abstraction, not concrete types

✅ **SwiftUI Best Practices**
- Declarative composition with extracted computed properties
- Uses `@ViewBuilder`-style subview extraction (`keyMetricsSection`, `scoreTrendChart`, etc.)
- Stateless presentation layer (no `@State` or business logic)
- Pure functions for calculations

✅ **Code Organization**
- Logical MARK sections separate concerns cleanly:
  - Key Metrics
  - Score Trend Chart
  - Per-Round Performance Chart
  - Golf Score Achievements
  - Personal Records
  - Computed Properties
  - Golf Score Calculations
  - Supporting Types
- Consistent naming conventions
- Related functionality grouped together

### Separation of Concerns

**Well-Separated**:
- View rendering logic separated from data computation
- Chart configuration isolated in dedicated sections
- Golf score calculations encapsulated

**Could Be Improved**:
- Business logic (statistics calculations) mixed with view code
- Could benefit from a dedicated ViewModel or StatisticsCalculator service
- Multiple computed properties performing similar switch-case patterns (code duplication)

---

## 3. Code Quality

### Strengths

✅ **Excellent Documentation**
- Comprehensive `RecordInfo` descriptions explain each metric
- Clear calculation explanations for users (important for training app)
- Inline comments for complex logic (e.g., golf scoring semantics)

✅ **Safe Optional Handling**
- Proper use of `guard` statements (lines 313, 343)
- Default values for empty data (returns 0, not crashes)
- Nil-coalescing for optional session properties (line 306-308)

✅ **Type Safety**
- Uses enums (`SessionDisplayItem`, `GolfScore`) instead of raw values
- Strong typing for all calculations (Double vs Int appropriately chosen)
- No force-unwrapping (`!`) found

✅ **Consistent Formatting**
- 4-space indentation throughout
- Vertical alignment for similar properties
- Blank lines separate logical blocks

### Code Smells & Technical Debt

⚠️ **High Computational Complexity** (Lines 327-484)
- Multiple O(n) and O(n*m) loops through sessions/rounds
- `averageScoreForRound` called 9 times per render (line 162) - 9×O(n×m) total
- `sessionScore` switch called repeatedly in loops
- No memoization or caching

⚠️ **Code Duplication** (Lines 331-341, 350-360, 366-383, 432-446, 465-472)
- Pattern of switching on `.local/.cloud` repeated 7+ times
- Each duplicates the logic for extracting rounds and processing them
- Violates DRY principle

⚠️ **Magic Numbers** (Lines 389-408)
- Hardcoded threshold `4` for minimum sessions (line 389)
- Hardcoded `recentCount = min(sessions.count / 2, 5)` (line 393)
- Threshold values `-2` and `2` for trend detection (lines 402, 404)
- Should be extracted as named constants

⚠️ **Potential Data Inconsistency** (Lines 303-310)
- `sessionScore` returns `Double`, but source data is `Int?`
- Unnecessary conversion - could stay as Int throughout
- Returns 0 for nil totalSessionScore - could hide missing data

⚠️ **Large View Structure** (501 lines)
- Single view handles 5 major sections
- Could be split into smaller, focused components
- Harder to test individual sections

### Error Handling

⚠️ **Silent Failures**
- Missing data returns 0 or empty arrays with no indication to user
- No logging for debugging statistical anomalies
- `bestRoundInfo` returns "N/A" but only if `bestScore == Int.max` (line 385) - could be more explicit

✅ **Defensive Programming**
- Empty state handling for charts (lines 109-113, 153-157)
- Guard clauses prevent division by zero
- Safe array access patterns

---

## 4. Performance Considerations

### Potential Bottlenecks

🔴 **Critical: Redundant Computation on Every Render**
- All computed properties recalculate on every view update
- `averageScoreForRound(1...9)` loops through all sessions 9 times (line 160-162)
- `topGolfScores` builds entire scoreMap on every render (lines 428-458)
- `longestUnderParStreak` performs O(n*m) flatMap + sort every render (lines 460-484)
- No `@State` caching or lazy evaluation

**Impact**: For 100 sessions with 9 rounds each:
- ~900 session switch operations per render
- ~1,800 round iterations in `averageScoreForRound` alone
- Could cause lag on older devices or large datasets

🟡 **Moderate: Chart Rendering**
- Charts library re-renders on every view update
- 200pt height frames (lines 136, 199) reasonable
- `ForEach(1...9)` creates 9 BarMarks - acceptable
- Line chart uses `.catmullRom` interpolation - computationally expensive but acceptable for small datasets

🟡 **Moderate: Sorting Operations**
- `sortedSessions` called multiple times (lines 116, 300, 394, 395, 465)
- Each creates new sorted array - O(n log n)
- Should compute once and cache

### Optimization Recommendations

**High Priority**:
1. **Extract calculations to ViewModel or computed struct**
   ```swift
   struct BlastingStatistics {
       let sessions: [SessionDisplayItem]

       // Compute all stats once on init
       lazy var averageSessionScore: Double = { ... }()
       lazy var perRoundAverages: [Int: Double] = { ... }()
       // etc.
   }
   ```

2. **Cache sorted sessions**
   ```swift
   private let sortedSessions: [SessionDisplayItem]

   init(sessions: [SessionDisplayItem]) {
       self.sessions = sessions
       self.sortedSessions = sessions.sorted { $0.createdAt < $1.createdAt }
   }
   ```

3. **Consolidate round extraction logic**
   ```swift
   private func extractRounds(from session: SessionDisplayItem) -> [Round] {
       switch session {
       case .local(let s): return s.rounds
       case .cloud(let s): return s.rounds
       }
   }
   ```

**Medium Priority**:
1. Extract magic numbers to constants
2. Consider pagination or data windowing for very large session counts (>500)
3. Use `.id()` modifier on charts to prevent unnecessary re-renders

---

## 5. Security & Data Safety

### Data Validation

✅ **Input Sanitization**
- Sessions array is trusted input (comes from SwiftData/CloudKit)
- No user input processing in this view
- Read-only operations only

✅ **Safe Data Access**
- No direct database queries
- No mutation of session data
- Proper optional handling prevents crashes

### Privacy Considerations

✅ **No Privacy Concerns**
- Displays only user's own training data
- No external data transmission
- No personally identifiable information exposed
- Statistics shown only in-app (no sharing functionality visible)

### CloudKit Data Handling

✅ **Appropriate**
- Treats local and cloud sessions identically
- No direct CloudKit API calls (separation of concerns)
- Statistics calculated from already-synced data

---

## 6. Testing Considerations

### Testability Assessment

⚠️ **Moderate Testability**
- View-heavy structure makes unit testing challenging
- Business logic embedded in computed properties is testable but requires view instantiation
- No dependency injection - sessions passed directly

### Missing Test Coverage Areas

**Critical to Test**:
1. **Edge Cases**
   - Empty sessions array
   - Single session
   - Sessions with missing rounds
   - Sessions with nil `totalSessionScore`
   - Mix of local and cloud sessions

2. **Golf Score Logic**
   - All score types (condor, albatross, eagle, birdie, par)
   - Boundary values (-4, -3, -2, -1, 0, +1, etc.)
   - Invalid golf scores (should return nil)

3. **Trend Detection**
   - Exactly 4 sessions (boundary case)
   - 3 sessions (should show "Not enough data")
   - Improving trend (delta < -2)
   - Declining trend (delta > 2)
   - Stable trend (-2 ≤ delta ≤ 2)

4. **Streak Calculation**
   - Consecutive under-par rounds
   - Interrupted streaks
   - No under-par rounds
   - All under-par rounds

5. **Round Performance**
   - All 9 rounds present
   - Missing rounds
   - Average calculation accuracy

### Recommended Test Cases

```swift
// Example test structure
class BlastingStatisticsSectionTests: XCTestCase {

    func test_averageSessionScore_withEmptySessions_returnsZero() { }

    func test_averageSessionScore_withMixedLocalAndCloud_calculatesCorrectly() { }

    func test_scoreTrendDirection_withLessThan4Sessions_returnsNotEnoughData() { }

    func test_scoreTrendDirection_withImprovingScores_returnsImproving() { }

    func test_topGolfScores_withNoUnderParRounds_returnsEmptyArray() { }

    func test_longestUnderParStreak_withConsecutiveRounds_calculatesCorrectly() { }

    func test_bestRoundInfo_withNoRounds_returnsNA() { }

    func test_averageScoreForRound_withMissingRound_handlesGracefully() { }
}
```

### Testing Challenges

1. **View Testing Complexity**
   - Requires SwiftUI preview or host view to test
   - Chart rendering difficult to validate programmatically
   - Consider extracting logic to separate `BlastingStatisticsCalculator` class

2. **Test Data Setup**
   - Need to create both local TrainingSession and CloudSession objects
   - SwiftData models may require ModelContext
   - Complex object graphs for realistic test scenarios

---

## 7. Issues Found

### Critical Issues

None found. The code is functionally sound.

### Potential Bugs

🟡 **Low Severity: Score Type Inconsistency** (Line 303-310)
- `sessionScore()` converts `Int?` to `Double`
- All consumers expect Double, but source data is Int
- Could lose precision (not an issue here, but semantically confusing)
- **Recommendation**: Keep as Int until final display formatting

🟡 **Low Severity: Trend Detection Edge Case** (Line 393)
```swift
let recentCount = min(sessions.count / 2, 5)
```
- For 5-7 sessions: recent = 2, older = 2
- For 8-9 sessions: recent = 4, older = 4
- For 10+ sessions: recent = 5, older = 5
- But comparison uses prefix/suffix which may not overlap correctly for odd counts
- **Example**: 7 sessions → recent = 3 (suffix 3), older = 3 (prefix 3) - middle session excluded
- **Recommendation**: Clarify intent or adjust algorithm

🟡 **Low Severity: Missing Round Number Validation** (Line 327-345)
- `averageScoreForRound` assumes round numbers 1-9
- No validation that roundNumber is in valid range
- Could silently fail if data contains invalid round numbers
- **Recommendation**: Add validation or filter

### Code Smells

🟡 **Switch-Case Repetition**
- 7+ identical switch patterns on SessionDisplayItem
- Violates DRY principle
- Makes refactoring error-prone
- **Solution**: Extract to helper function or add computed property to SessionDisplayItem

🟡 **Mixed Concerns**
- View contains business logic (statistics calculations)
- Harder to reuse calculations elsewhere
- **Solution**: Extract to dedicated StatisticsCalculator service or ViewModel

---

## 8. Recommendations

### High Priority

1. **Extract Statistics Calculation Layer** ⭐⭐⭐
   ```swift
   struct BlastingStatistics {
       private let sessions: [SessionDisplayItem]

       init(sessions: [SessionDisplayItem]) {
           self.sessions = sessions.sorted { $0.createdAt < $1.createdAt }
       }

       lazy var averageSessionScore: Double = { /* ... */ }()
       lazy var perRoundAverages: [Int: Double] = { /* ... */ }()
       lazy var topGolfScores: [GolfScoreAchievement] = { /* ... */ }()
       // etc.
   }
   ```
   **Benefits**:
   - Single computation on init
   - Easily unit testable
   - Reusable across multiple views
   - Clear separation of concerns

2. **Add Helper for Round Extraction** ⭐⭐⭐
   ```swift
   extension SessionDisplayItem {
       var rounds: [Round] {
           switch self {
           case .local(let session): return session.rounds
           case .cloud(let session): return session.rounds
           }
       }
   }
   ```
   **Benefits**:
   - Eliminates 7+ switch statements
   - More maintainable
   - Simpler code

3. **Extract Magic Numbers to Constants** ⭐⭐
   ```swift
   private enum StatisticsConstants {
       static let minimumSessionsForTrend = 4
       static let maxRecentSessionsForTrend = 5
       static let trendImprovementThreshold = -2.0
       static let trendDeclineThreshold = 2.0
   }
   ```

### Medium Priority

4. **Add Performance Monitoring** ⭐⭐
   - Add `#if DEBUG` timing logs for calculation methods
   - Monitor performance with large datasets (500+ sessions)
   - Consider lazy loading or pagination if needed

5. **Improve Error Visibility** ⭐⭐
   - Log when `totalSessionScore` is nil (indicates data issue)
   - Show user-friendly message when data is incomplete
   - Add debug mode to surface data quality issues

6. **Consolidate Color Logic** ⭐
   - `scoreColor()` function (lines 411-419) duplicates golf score color logic
   - GolfScore enum already has color property
   - Could use `GolfScore(score: Int(score))?.color ?? .gray`

### Low Priority (Nice-to-Have)

7. **Add Accessibility Support**
   - Charts need accessibility labels
   - VoiceOver descriptions for metrics
   - Support for Dynamic Type

8. **Add Animation**
   - Chart transitions when data updates
   - Metric card value changes
   - Trend indicator changes

9. **Consider Internationalization**
   - Number formatting for different locales
   - Golf terminology may need translation
   - Date formatting in trend descriptions

---

## 9. Compliance Checklist

### iOS Best Practices

✅ **SwiftUI Guidelines**
- [x] Uses declarative syntax
- [x] Proper view composition
- [x] No force-unwrapping
- [x] Safe optional handling
- [x] Proper use of computed properties
- [ ] ⚠️ Consider extracting large views (>300 lines)
- [x] Preview provider included

✅ **Swift Language Best Practices**
- [x] Strong typing
- [x] Enum usage appropriate
- [x] Naming conventions followed
- [x] No compiler warnings expected
- [x] Access control appropriate (private where needed)

### SwiftData Patterns

✅ **Appropriate Usage**
- [x] No direct ModelContext access (stateless view)
- [x] Works with already-fetched data
- [x] No threading issues (read-only)

N/A - No SwiftData queries in this file

### CloudKit Guidelines

✅ **Appropriate Usage**
- [x] Treats CloudSession as plain data
- [x] No direct CloudKit API calls
- [x] Separation of concerns maintained

N/A - No CloudKit operations in this file

### Charts Framework

✅ **Best Practices**
- [x] Proper use of LineMark, BarMark, PointMark, RuleMark
- [x] Axis configuration appropriate
- [x] Empty state handling
- [x] Color coding meaningful
- [ ] ⚠️ Missing accessibility labels for VoiceOver
- [x] Reasonable chart heights (200pt)

### Performance

⚠️ **Needs Attention**
- [ ] ❌ Computation on every render (should cache)
- [ ] ❌ Multiple O(n*m) loops
- [x] No memory leaks (value types used)
- [x] No retain cycles (no closures capturing self)

### Accessibility

⚠️ **Needs Improvement**
- [ ] ❌ Charts need `.accessibilityLabel()`
- [ ] ❌ Charts need `.accessibilityValue()`
- [ ] ❌ Trend indicators need accessibility descriptions
- [ ] ⚠️ Metric cards may need accessibility hints
- [x] Text uses system text styles (scalable)

### App Store Guidelines

✅ **Compliant**
- [x] No privacy violations
- [x] No prohibited content
- [x] Appropriate for all ages
- [x] No gambling elements (golf scoring is skill-based)
- [x] No misleading information

---

## Summary

### Overall Assessment: **B+ (Good, with room for optimization)**

**Strengths**:
- ✅ Clean, readable SwiftUI code with good structure
- ✅ Comprehensive statistics coverage
- ✅ Excellent user-facing documentation (RecordInfo)
- ✅ Safe coding practices (no force-unwraps, proper optionals)
- ✅ Good separation into logical sections

**Areas for Improvement**:
- ⚠️ Performance optimization needed (avoid recomputation on every render)
- ⚠️ Extract business logic to separate layer for testability
- ⚠️ Eliminate code duplication (7+ identical switch statements)
- ⚠️ Add accessibility support for charts
- ⚠️ Extract magic numbers to named constants

### Key Metrics

- **Lines of Code**: 501
- **Computed Properties**: 13
- **Switch Statements**: 7+ (duplicate pattern)
- **Chart Types Used**: 4 (LineMark, BarMark, PointMark, RuleMark)
- **Sections**: 5 major UI sections
- **Cyclomatic Complexity**: Moderate-High (multiple nested loops)

### Recommended Next Steps

1. **Immediate** (Before next release):
   - Extract rounds property to SessionDisplayItem extension
   - Add accessibility labels to charts

2. **Short-term** (Next sprint):
   - Create BlastingStatisticsCalculator service
   - Add unit tests for core calculations
   - Extract magic numbers to constants

3. **Long-term** (Technical debt backlog):
   - Performance profiling with large datasets
   - Consider pagination for 500+ sessions
   - Add localization support

---

**Review completed**: 2026-03-23
**Reviewed by**: Claude Code (Sonnet 4.5)
**Status**: ✅ Approved for production with recommended optimizations
