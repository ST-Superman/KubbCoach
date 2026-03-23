# Code Review: BlastingDashboardChart.swift

**Date**: 2026-03-22
**Reviewer**: Claude Code
**File**: `Kubb Coach/Kubb Coach/Views/Statistics/BlastingDashboardChart.swift`
**Lines of Code**: 82

---

## 1. File Overview

### Purpose
`BlastingDashboardChart` is a SwiftUI bar chart component that visualizes 4-meter blasting session scores using golf-style scoring (negative = under par = good, positive = over par = bad). It provides users with a quick visual reference of recent blasting performance.

### Key Responsibilities
- Display bar chart of last 15 blasting session scores
- Use color coding: green for under par (good), red for over par (bad)
- Show par line at zero as reference
- Handle empty states gracefully

### Dependencies
- **SwiftUI**: View rendering
- **Charts**: Apple's native charting framework (iOS 16+)
- **Custom Types**: `SessionDisplayItem`, `KubbColors`

### Integration Points
- Used in Statistics/Dashboard views for blasting mode
- Receives filtered blasting session data
- Relies on `SessionDisplayItem` containing `totalSessionScore`

---

## 2. Architecture Analysis

### Design Patterns
✅ **View Component Pattern**: Clean, focused chart component
✅ **Computed Properties**: Efficient session filtering
⚠️ **Helper Method**: `sessionScore()` could be optimized

### SOLID Principles

**Single Responsibility** ✅
The view has one clear job: render a blasting score bar chart.

**Open/Closed** ⚠️
Hardcoded session count (15) reduces extensibility. Could be more configurable.

**Liskov Substitution** ✅
Conforms to `View` protocol correctly.

**Interface Segregation** ✅
Minimal dependencies - only receives what it needs.

**Dependency Inversion** ✅
Uses dependency injection for `sessions` data.

### Code Organization
- **Simple structure**: Computed property → Helper method → Body → Preview
- **Logical flow**: Empty state check, then chart rendering
- **Readability**: Good, but could benefit from comments

### Separation of Concerns
✅ View doesn't handle data fetching
✅ Minimal business logic (score extraction)
⚠️ Color logic embedded in chart (could be extracted)

---

## 3. Code Quality

### SwiftUI Best Practices

✅ **No State Management**: Pure view based on input (appropriate)
✅ **View Composition**: Single responsibility
✅ **Computed Properties**: Used correctly
⚠️ **Missing Accessibility**: No accessibility labels or identifiers
⚠️ **Hardcoded Strings**: Not localization-ready
⚠️ **Magic Numbers**: Session count (15) hardcoded

### Error Handling
✅ **Empty State**: Properly handles empty sessions
⚠️ **Nil Score Handling**: Uses `?? 0` which might hide data issues
✅ **Safe Operations**: No force-unwrapping

### Optionals Management
**Rating**: Good ✅

No force-unwrapping. Optionals handled with nil-coalescing:
```swift
return Double(localSession.totalSessionScore ?? 0)
```

**Concern**: Defaulting to 0 might hide missing data. Consider whether sessions without scores should be filtered out instead.

### Performance Issues

**⚠️ Repeated Function Calls** (Line 42)
```swift
.foregroundStyle(sessionScore(session) < 0 ? KubbColors.forestGreen : Color.red)
```

**Issue**: `sessionScore(session)` is called twice per bar:
1. Once for Y-value (line 40)
2. Once for color (line 42)

This creates redundant switch statements and optional unwrapping.

**Fix**: Compute score once and reuse:
```swift
ForEach(Array(chartSessions.enumerated()), id: \.element.id) { index, session in
    let score = sessionScore(session)
    BarMark(
        x: .value("Session", index + 1),
        y: .value("Score", score)
    )
    .foregroundStyle(score < 0 ? KubbColors.forestGreen : Color.red)
}
```

**Note**: Swift's current `@ChartContentBuilder` doesn't support `let` bindings. Alternative: create a helper view or precompute scores.

### Code Style
✅ Consistent naming conventions
✅ Proper indentation
⚠️ Missing documentation comments

---

## 4. Performance Considerations

### Potential Bottlenecks

**Redundant Score Calculations** ⚠️
- Each session's score is calculated twice (Y-value + color)
- For 15 sessions, that's 30 calculations vs. 15 needed
- Minor impact, but avoidable

**Array Operations** ✅
- `.suffix(15)` is O(n) but efficient for expected data size
- `.enumerated()` is O(1) lazy operation

### UI Rendering Efficiency

✅ **Fixed Session Count**: Max 15 bars keeps rendering predictable
✅ **Fixed Frame Height**: `frame(height: 150)` prevents layout thrashing
✅ **Simple Bar Chart**: Minimal rendering complexity

### Optimization Opportunities

1. **Precompute Scores**: Map sessions to scores once, reuse for chart
2. **Lazy Loading**: Not needed for 15 sessions
3. **Chart Complexity**: Already minimal

### Memory Usage
**Rating**: Excellent ✅

- Only holds last 15 sessions in memory
- No large data structures
- No leaked resources

---

## 5. Security & Data Safety

### Input Validation
✅ **Safe Array Access**: Uses `.suffix()` which handles empty arrays
✅ **Type Safety**: Swift's type system prevents invalid data
⚠️ **Silent Nil Handling**: `?? 0` might hide data integrity issues

### Data Sanitization
**N/A**: Chart only displays data, doesn't modify or transmit it.

### CloudKit Data Handling
**N/A**: This view doesn't interact with CloudKit directly.

### Privacy Considerations
✅ **No PII**: Only displays aggregated scores
✅ **No External Data**: All data is local session statistics

---

## 6. Testing Considerations

### Testability
**Rating**: Moderate ⚠️

**Pros**:
- Pure view component
- Deterministic output based on inputs
- Simple helper function can be tested

**Cons**:
- No ViewModel - testing requires SwiftUI infrastructure
- Chart rendering not easily unit-testable
- Score color logic embedded in view

### Missing Test Coverage

**Recommended Test Cases**:
```swift
// Unit tests for sessionScore() helper (if extracted)
1. Local session with positive score → Returns correct value
2. Local session with negative score → Returns correct value
3. Local session with nil score → Returns 0
4. Cloud session with score → Returns correct value
5. Cloud session with nil score → Returns 0

// Integration/Snapshot tests
6. Empty sessions array → Shows "No blasting data yet"
7. 5 sessions → Shows all 5 bars
8. 20 sessions → Shows only last 15 bars
9. All under par → All bars green
10. All over par → All bars red
11. Mixed scores → Correct color per bar
12. Par line visibility → Dashed line at y=0
```

### Test Automation
- Current `#Preview` provides visual testing
- Consider snapshot tests for various score distributions
- Consider UI tests for interaction (if made interactive)

---

## 7. Issues Found

### Critical Bugs
**None found** ✅

### Potential Bugs

**1. Performance: Redundant Score Calculations** ⚠️ **Low Priority**
```swift
// Line 40, 42: sessionScore() called twice per session
y: .value("Score", sessionScore(session))
...
.foregroundStyle(sessionScore(session) < 0 ? ...)
```

**Impact**: 2x computation overhead (minor for 15 sessions, but avoidable).

**Fix**: See workaround in section 8 (Swift limitation with @ChartContentBuilder).

**2. Hidden X-Axis Labels** ⚠️ **Medium Priority**
```swift
// Lines 62-66: X-axis labels completely hidden
.chartXAxis {
    AxisMarks { _ in
        AxisValueLabel("")  // Empty string
    }
}
```

**Issue**: Same as AccuracyTrendChart - reduces chart readability.

**Impact**: Users can't see which bar represents which session.

**Fix Options**:
```swift
// Option A: Show session numbers
.chartXAxis {
    AxisMarks { value in
        if let intValue = value.as(Int.self) {
            AxisValueLabel {
                Text("\(intValue)")
                    .font(.caption2)
            }
        }
    }
}

// Option B: Show dates (better UX)
.chartXAxis {
    AxisMarks(values: .automatic(desiredCount: 5)) { value in
        if let date = value.as(Date.self) {
            AxisValueLabel {
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
    }
}
```

**Recommendation**: Option B (show dates) provides more context.

**3. Color Accessibility** ⚠️ **Medium Priority**
```swift
// Line 42: Red/green might not work for color-blind users
.foregroundStyle(sessionScore(session) < 0 ? KubbColors.forestGreen : Color.red)
```

**Issue**: ~8% of males have red-green color blindness.

**Impact**: Some users can't distinguish good vs. bad scores by color alone.

**Fix**: Add additional visual indicators:
```swift
// Option A: Use different bar heights above/below zero (already done via Y-value)
// Option B: Add icons or patterns
// Option C: Use more distinct colors (blue vs. orange)
.foregroundStyle(sessionScore(session) < 0 ? KubbColors.phase8m : KubbColors.phase4m)
```

**Note**: The chart already uses position (above/below par line) as a secondary indicator, which helps accessibility.

### Code Smells

**1. Hardcoded Magic Number**
```swift
// Line 15: Session count hardcoded
Array(sessions.suffix(15)) // Last 15 sessions
```

**Recommendation**:
```swift
private static let maxSessionsDisplayed = 15

private var chartSessions: [SessionDisplayItem] {
    Array(sessions.suffix(Self.maxSessionsDisplayed))
}
```

**2. Nil Coalescing Might Hide Issues**
```swift
// Lines 21, 23: Defaulting to 0 might mask data problems
return Double(localSession.totalSessionScore ?? 0)
```

**Recommendation**: Consider logging or filtering sessions without scores:
```swift
private var chartSessions: [SessionDisplayItem] {
    sessions
        .filter { sessionScore($0) != nil }  // Only sessions with valid scores
        .suffix(15)
}

private func sessionScore(_ session: SessionDisplayItem) -> Double? {
    switch session {
    case .local(let localSession):
        return localSession.totalSessionScore.map(Double.init)
    case .cloud(let cloudSession):
        return cloudSession.totalSessionScore.map(Double.init)
    }
}
```

Or keep current behavior but document the assumption.

**3. X-Axis Uses Index Instead of Meaningful Data**
```swift
// Line 39: Session index less informative than date
x: .value("Session", index + 1)
```

**Issue**: "Session 1", "Session 2" is arbitrary - which session is which?

**Better**:
```swift
x: .value("Date", session.createdAt)
```

This makes the chart more informative and self-documenting.

### Technical Debt

**1. No Accessibility Support**
- Missing VoiceOver labels
- No accessibility hints
- Chart not navigable with VoiceOver

**2. No Localization**
- "No blasting data yet" → Hardcoded English
- "Last 15 sessions - Lower is better" → Hardcoded English

**3. No Configurability**
- Session count fixed at 15
- Colors hardcoded
- Height fixed at 150

---

## 8. Recommendations

### High Priority

**1. Add Accessibility Support** 🔴
```swift
// Add computed properties for accessibility
private var averageScore: Double {
    guard !chartSessions.isEmpty else { return 0 }
    return chartSessions.map(sessionScore).reduce(0, +) / Double(chartSessions.count)
}

private var performanceSummary: String {
    let underPar = chartSessions.filter { sessionScore($0) < 0 }.count
    let atPar = chartSessions.filter { sessionScore($0) == 0 }.count
    let overPar = chartSessions.filter { sessionScore($0) > 0 }.count

    if underPar > overPar {
        return "mostly under par"
    } else if overPar > underPar {
        return "mostly over par"
    } else {
        return "mixed performance"
    }
}

// Add to Chart:
.accessibilityElement(children: .combine)
.accessibilityLabel("Blasting score trend chart")
.accessibilityValue("Last \(chartSessions.count) sessions with average score of \(averageScore, specifier: "%.1f"), performance is \(performanceSummary)")
.accessibilityHint("Lower scores are better in golf-style scoring")
```

**2. Improve X-Axis Labels** 🔴
```swift
// Show dates instead of hiding labels
.chartXAxis {
    AxisMarks(values: .automatic(desiredCount: 5)) { value in
        if let date = value.as(Date.self) {
            AxisValueLabel {
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
    }
}

// And use dates in X-value:
x: .value("Date", session.createdAt)
```

### Medium Priority

**3. Optimize Score Calculation** 🟡

Current limitation: `@ChartContentBuilder` doesn't support `let` bindings.

**Workaround A**: Precompute scores
```swift
private struct SessionScore: Identifiable {
    let id: String
    let createdAt: Date
    let score: Double
}

private var sessionScores: [SessionScore] {
    chartSessions.map { session in
        SessionScore(
            id: session.id,
            createdAt: session.createdAt,
            score: sessionScore(session)
        )
    }
}

// Then in Chart:
ForEach(sessionScores) { item in
    BarMark(
        x: .value("Date", item.createdAt),
        y: .value("Score", item.score)
    )
    .foregroundStyle(item.score < 0 ? KubbColors.forestGreen : Color.red)
}
```

**Workaround B**: Extract to helper view
```swift
private struct ScoreBar: ChartContent {
    let session: SessionDisplayItem
    let score: Double

    var body: some ChartContent {
        BarMark(
            x: .value("Date", session.createdAt),
            y: .value("Score", score)
        )
        .foregroundStyle(score < 0 ? KubbColors.forestGreen : Color.red)
    }
}

// Then:
ForEach(chartSessions, id: \.id) { session in
    ScoreBar(session: session, score: sessionScore(session))
}
```

**4. Improve Color Accessibility** 🟡
```swift
// Option A: Use blue/orange instead of green/red
.foregroundStyle(score < 0 ? KubbColors.phase8m : KubbColors.phase4m)

// Option B: Add opacity variation for additional distinction
.foregroundStyle(score < 0 ? KubbColors.forestGreen : Color.red)
.opacity(abs(score) > 5 ? 1.0 : 0.7)  // Darker for more extreme scores
```

**5. Add Localization** 🟡
```swift
Text("No blasting data yet")
    → Text(LocalizedStringKey("statistics.blasting.empty"))

Text("Last 15 sessions - Lower is better")
    → Text(LocalizedStringKey("statistics.blasting.caption"))
```

### Nice-to-Have Optimizations

**6. Make Session Count Configurable** 🟢
```swift
struct BlastingDashboardChart: View {
    let sessions: [SessionDisplayItem]
    var maxSessions: Int = 15  // Configurable

    private var chartSessions: [SessionDisplayItem] {
        Array(sessions.suffix(maxSessions))
    }
}
```

**7. Add Range Selector** 🟢
Similar to AccuracyTrendChart, allow toggling between "Last 15" and "Last 50" sessions.

**8. Add Average Score Line** 🟢
```swift
// Show average as reference line
let avgScore = chartSessions.map(sessionScore).reduce(0, +) / Double(chartSessions.count)

RuleMark(y: .value("Average", avgScore))
    .foregroundStyle(.blue.opacity(0.5))
    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
    .annotation(position: .trailing) {
        Text("Avg: \(avgScore, specifier: "%.1f")")
            .font(.caption2)
    }
```

**9. Add Score Trend Indicator** 🟢
```swift
private var trendDirection: String {
    guard chartSessions.count >= 6 else { return "insufficient data" }
    let recent = chartSessions.suffix(3).map(sessionScore).reduce(0, +) / 3
    let earlier = chartSessions.prefix(3).map(sessionScore).reduce(0, +) / 3

    if recent < earlier - 2 {
        return "improving"  // Lower is better
    } else if recent > earlier + 2 {
        return "declining"
    } else {
        return "stable"
    }
}
```

### Refactoring Suggestions

**10. Extract Score Logic to Extension** 🟢
```swift
extension SessionDisplayItem {
    var blastingScore: Double {
        switch self {
        case .local(let localSession):
            return Double(localSession.totalSessionScore ?? 0)
        case .cloud(let cloudSession):
            return Double(cloudSession.totalSessionScore ?? 0)
        }
    }
}

// Then simplify chart:
y: .value("Score", session.blastingScore)
.foregroundStyle(session.blastingScore < 0 ? ...)
```

---

## 9. Compliance Checklist

### iOS Best Practices
- ✅ Uses native SwiftUI and Charts frameworks
- ✅ Follows iOS design patterns
- ❌ Missing accessibility support (critical)
- ⚠️ No Dynamic Type support tested
- ✅ Relies on system colors (Dark Mode compatible)

### SwiftUI Patterns
- ✅ Pure view based on input
- ✅ Computed properties for derived data
- ✅ No anti-patterns detected
- ⚠️ Could benefit from view extraction for complexity

### SwiftData Patterns
- **N/A**: This view doesn't interact with SwiftData directly

### CloudKit Guidelines
- **N/A**: No CloudKit interaction

### Accessibility Considerations
- ❌ No accessibility labels for chart
- ❌ No VoiceOver support for data interpretation
- ⚠️ Red/green color scheme not ideal for color-blind users (but position provides secondary cue)
- ❌ No accessibility hints explaining golf-style scoring

**Required Additions**:
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Blasting score bar chart")
.accessibilityValue("Performance summary: \(performanceSummary)")
.accessibilityHint("Lower scores are better. Green bars are under par, red bars are over par")
```

### App Store Guidelines
- ✅ No API misuse
- ✅ No private APIs
- ⚠️ Accessibility may be flagged during review
- ✅ No crashes or force-unwraps

---

## Summary

### Overall Rating: **B (Good)**

**Strengths**:
- ✅ Clean, focused SwiftUI code
- ✅ Effective use of bar chart for score visualization
- ✅ Golf-style scoring concept well-implemented
- ✅ No force-unwrapping or unsafe operations
- ✅ Good empty state handling
- ✅ Par line provides helpful reference

**Areas for Improvement**:
- ❌ Missing accessibility support (critical for App Store)
- ⚠️ Hidden X-axis reduces chart interpretability
- ⚠️ Redundant score calculations (minor performance issue)
- ⚠️ Red/green color scheme not ideal for accessibility
- ⚠️ No localization support
- ⚠️ X-axis uses arbitrary index instead of meaningful dates

### Comparison to AccuracyTrendChart
| Feature | AccuracyTrendChart | BlastingDashboardChart |
|---------|-------------------|------------------------|
| Accessibility | ❌ → ✅ (fixed) | ❌ (needs fixing) |
| X-axis labels | ❌ → ✅ (fixed) | ❌ (needs fixing) |
| Range selector | ✅ Yes | ❌ No |
| Color logic | ⚠️ → ✅ (fixed) | ⚠️ Accessibility concern |
| Performance | ✅ Good | ⚠️ Minor redundancy |

**Recommendation**: Apply similar improvements to this chart as were applied to AccuracyTrendChart.

### Actionable Next Steps

1. **Immediate**: Add accessibility labels and VoiceOver support
2. **Before Release**: Improve X-axis to show dates instead of indices
3. **Before Release**: Add performance summary for accessibility
4. **Next Sprint**: Optimize score calculation (precompute)
5. **Next Sprint**: Add localization strings
6. **Enhancement**: Consider blue/orange color scheme for better accessibility
7. **Enhancement**: Add range selector like AccuracyTrendChart
8. **Enhancement**: Add average score reference line

### Test Coverage Recommendation
- Add unit tests for `sessionScore()` helper
- Add snapshot tests for different score distributions
- Verify accessibility with VoiceOver testing
- Test color contrast for accessibility compliance

---

**Review Complete** ✓

This view is production-ready but needs accessibility improvements before App Store submission. It would benefit from the same enhancements applied to AccuracyTrendChart.swift.
