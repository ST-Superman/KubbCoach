# Code Review: InkastingSessionCompleteView.swift

**Date**: 2026-03-24
**Reviewer**: Claude Code
**File**: `Kubb Coach/Kubb Coach/Views/Inkasting/InkastingSessionCompleteView.swift`
**Lines of Code**: 529
**Created**: 2/24/26

---

## 1. File Overview

### Purpose
Post-session summary screen for Inkasting training mode. Displays session statistics, achievements, personal bests, goal progress, milestone tracking, and provides actions for sharing, adding notes, or starting a new session.

### Key Responsibilities
- Display comprehensive session statistics and metrics
- Show personal best achievements
- Compare current session to previous session
- Track goal progress and show completions
- Display milestone achievements
- Handle session notes
- Provide navigation options (share, train again, done, view stats)

### Dependencies
- **SwiftUI**: UI framework
- **SwiftData**: Database queries and persistence
- **OSLog**: Logging via AppLogger
- **Services**: SessionComparisonService, MilestoneService, TrainingSessionManager, HapticFeedbackService

### Integration Points
- **Input**: Receives `TrainingSession`, `selectedTab` binding, `navigationPath` binding
- **Database**: Heavy SwiftData queries (7+ different FetchDescriptors)
- **Navigation**: Modifies navigation path and tab selection
- **Overlays**: Shows goal completion and milestone overlays

---

## 2. Architecture Analysis

### Design Patterns Used
✅ **SwiftUI View Composition**: Well-organized into sections
✅ **Computed Properties**: For derived data
⚠️ **Service Layer**: Good use but could be better abstracted
⚠️ **State Management**: Multiple @State variables, some redundancy

### SOLID Principles

**Single Responsibility Principle**: ⚠️ **Partial Violation**
- View handles display, data fetching, business logic, and navigation
- Should extract data fetching/transformation to ViewModel or Service
- Too many responsibilities in one view

**Open/Closed Principle**: ⚠️ **Moderate**
- Hard to extend without modifying
- Computed properties tightly coupled to implementation

**Liskov Substitution Principle**: ✅ **N/A**
- No inheritance hierarchy

**Interface Segregation Principle**: ✅ **Good**
- Clean interface with bindings and session input

**Dependency Inversion Principle**: ⚠️ **Partial**
- Direct dependency on modelContext (hard to test)
- Direct service instantiation (not injected)

### Code Organization

```
InkastingSessionCompleteView
├── State Properties (6 @State variables)
├── Computed Properties (5 database queries)
├── body: ScrollView
│   ├── Success icon & title
│   ├── Personal best badges
│   ├── Session comparison
│   ├── Consistency achievement
│   ├── Stats section
│   ├── Improvement section
│   ├── Goal progress section
│   ├── Milestone progress
│   ├── Session notes
│   └── Action buttons
├── Private View Builders (4 methods)
├── Helper Methods (5 methods)
└── Overlay Management (goals & milestones)
```

**Structure**: ✅ Logical organization
**Complexity**: ⚠️ High - 529 lines, many responsibilities

---

## 3. Code Quality

### Critical Issues

#### 🔴 **Force Unwrapping - Crash Risk**
**Location**: Line 40
```swift
let comparison = lastSession != nil ? SessionComparisonService.getComparison(
    current: activeSession,
    previous: lastSession!,  // ❌ Force unwrap!
    context: modelContext
) : nil
```

**Problem**: If `lastSession` is somehow nil despite the check, app crashes.

**Fix**:
```swift
let comparison: ComparisonResult? = {
    guard let lastSession = lastSession else { return nil }
    return SessionComparisonService.getComparison(
        current: activeSession,
        previous: lastSession,
        context: modelContext
    )
}()
```

---

#### 🔴 **Computed Property Performance Issue**
**Location**: Lines 35-44
```swift
private var sessionComparison: (comparison: ComparisonResult?, isFirst: Bool) {
    let lastSession = SessionComparisonService.findLastSession(matching: activeSession, context: modelContext)
    let isFirst = lastSession == nil
    let comparison = lastSession != nil ? SessionComparisonService.getComparison(...) : nil
    return (comparison, isFirst)
}
```

**Problem**:
- Database queries run **every time** this property is accessed
- Called multiple times during view rendering
- No caching, very inefficient
- Could run dozens of times per screen

**Fix**: Use `@State` with `onAppear` initialization:
```swift
@State private var sessionComparison: (comparison: ComparisonResult?, isFirst: Bool) = (nil, false)

// In onAppear:
let lastSession = SessionComparisonService.findLastSession(matching: activeSession, context: modelContext)
sessionComparison = (
    comparison: lastSession != nil ? SessionComparisonService.getComparison(...) : nil,
    isFirst: lastSession == nil
)
```

---

#### 🔴 **Arbitrary Async Delay - Code Smell**
**Location**: Lines 172-174
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    checkForGoalCompletion()
}
```

**Problems**:
- Magic number (0.5s) with no explanation
- Suggests race condition or timing issue
- Unreliable - may need more or less time
- Comment says "for async goal evaluation" but doesn't fix root cause

**Root Cause**: Goal evaluation happening asynchronously somewhere else. The 0.5s delay is a band-aid.

**Better Approach**:
1. Make goal evaluation synchronous if possible
2. Use proper async/await pattern
3. Use NotificationCenter or Combine to react to goal completion
4. Or refactor goal service to provide completion callback

**Temporary Fix** (document the issue):
```swift
// FIXME: This delay works around race condition where goal evaluation
// completes after view appears. Should refactor to use completion handler
// or notification. Increased from 0.5s to 1.0s for reliability.
Task { @MainActor in
    try await Task.sleep(nanoseconds: 1_000_000_000)
    checkForGoalCompletion()
}
```

---

#### 🔴 **Multiple Database Queries for Same Data**
**Location**: Lines 92-93, 188-190
```swift
// Line 92-93
let analyses = activeSession.fetchInkastingAnalyses(context: modelContext)
let perfectRounds = analyses.filter { $0.outlierCount == 0 }.count

// Line 188-189 (same data fetched again!)
let analyses = activeSession.fetchInkastingAnalyses(context: modelContext)
let perfectRounds = analyses.filter { $0.outlierCount == 0 }.count
```

**Problem**:
- Fetching same data twice
- Filtering same data twice
- Inefficient database access

**Fix**: Cache in `@State`:
```swift
@State private var sessionAnalyses: [InkastingAnalysis] = []
@State private var perfectRoundsCount: Int = 0

// In onAppear:
sessionAnalyses = activeSession.fetchInkastingAnalyses(context: modelContext)
perfectRoundsCount = sessionAnalyses.filter { $0.outlierCount == 0 }.count
```

---

### High-Priority Issues

#### 🟠 **Silent Error Handling**
**Location**: Multiple places (lines 50, 60, 116, 164, 381, 413, 446, 462)

Examples:
```swift
let totalSessions = (try? modelContext.fetchCount(descriptor)) ?? 0  // Silent failure
let activeGoals = (try? modelContext.fetch(descriptor)) ?? []        // Silent failure
if let fetched = try? modelContext.fetch(descriptor).first {         // Silent failure
    // ...
} else {
    AppLogger.inkasting.warning("⚠️ Failed to re-fetch session")     // Logged but no UI feedback
}
```

**Problems**:
- User has no idea if something failed
- Could show incorrect/incomplete data
- Hard to debug production issues

**Recommendation**:
1. Add error state to view
2. Show error message to user
3. Provide retry action
4. At minimum, show "Data unavailable" instead of empty/zero values

```swift
@State private var loadError: Error?

// Show error UI:
if let error = loadError {
    ErrorView(error: error) {
        retryLoadingData()
    }
}
```

---

#### 🟠 **Heavy onAppear Processing**
**Location**: Lines 158-180

**Issues**:
- Multiple database queries
- Session re-fetching
- Async delay
- Milestone fetching
- All on main thread
- Blocks UI responsiveness

**Fix**: Use Task for async processing:
```swift
.task {
    await loadSessionData()
}

private func loadSessionData() async {
    // Fetch in background
    let descriptor = FetchDescriptor<TrainingSession>(...)
    if let fetched = try? modelContext.fetch(descriptor).first {
        await MainActor.run {
            freshSession = fetched
        }
    }

    // Goal completion check
    await MainActor.run {
        checkForGoalCompletion()
    }

    // Milestones
    let milestoneService = MilestoneService(modelContext: modelContext)
    let unseen = milestoneService.getUnseenMilestones()
    await MainActor.run {
        showingMilestone = unseen.first
    }
}
```

---

#### 🟠 **Duplicate Database Queries**
**Location**: Lines 113-116
```swift
if let milestone = nextMilestone {  // Query 1: fetches count
    let descriptor = FetchDescriptor<TrainingSession>(
        predicate: #Predicate { $0.completedAt != nil }
    )
    let totalSessions = (try? modelContext.fetchCount(descriptor)) ?? 0  // Query 2: same count!
```

**Problem**: `nextMilestone` computed property already fetches the count (line 50), but we fetch it again.

**Fix**: Return count along with milestone or cache it.

---

#### 🟠 **Potential State Management Issues**
**Location**: Lines 23-24
```swift
@State private var freshSession: TrainingSession?
// ...
private var activeSession: TrainingSession {
    freshSession ?? session
}
```

**Problem**:
- Two sources of truth: `session` (immutable input) and `freshSession` (mutable state)
- Complex to reason about which is being used
- Notes are saved to `activeSession` which might be either

**Better Approach**: Single source of truth
```swift
@State private var displaySession: TrainingSession

init(session: TrainingSession, ...) {
    self.session = session
    _displaySession = State(initialValue: session)
}

// In onAppear, update displaySession if refetch succeeds
```

---

### Medium-Priority Issues

#### 🟡 **No Loading State**
When view appears, multiple database queries run but no loading indicator shown. User might see empty/partial data briefly.

**Recommendation**: Add loading state
```swift
@State private var isLoading = true

// Show loading overlay while isLoading == true
```

---

#### 🟡 **Double Save Attempts**
**Location**: Lines 379-382 and 410-413

Both "Train Again" and "Done" buttons save notes:
```swift
// Train Again
if !sessionNotes.isEmpty {
    activeSession.notes = sessionNotes
    try? modelContext.save()  // Save 1
}

// Done
if !sessionNotes.isEmpty {
    activeSession.notes = sessionNotes
    try? modelContext.save()  // Save 2
}
```

**Issue**: Duplicate code, should be extracted to helper.

**Better**:
```swift
private func saveSessionNotes() {
    guard !sessionNotes.isEmpty else { return }
    activeSession.notes = sessionNotes
    do {
        try modelContext.save()
        AppLogger.inkasting.debug("Session notes saved")
    } catch {
        AppLogger.inkasting.error("Failed to save notes: \(error)")
        // Show error to user
    }
}
```

---

#### 🟡 **Goal Completion Time Window**
**Location**: Lines 479
```swift
if timeSinceCompletion < 10 {  // 10 seconds window
```

**Issue**: Increased from 5s to 10s as workaround for async issues. This is brittle and could miss goals or show stale ones.

**Better Solution**:
- Store "viewed" flag on goal completion records
- Or use completion session ID to determine if celebration should show
- Don't rely on timestamps

---

#### 🟡 **Missing Accessibility**
**Issues**:
- Success icon (line 68) has no accessibility label
- Stats cards might not have proper labels
- Progress bars need accessibility values
- Buttons have text but could use hints

**Fixes**:
```swift
Image(systemName: "checkmark.circle.fill")
    .accessibilityLabel("Session completed successfully")

ProgressView(value: goal.progressPercentage / 100.0)
    .accessibilityValue("\(Int(goal.progressPercentage)) percent complete")
```

---

## 4. Performance Considerations

### Current Performance Issues

1. **Computed Properties with Database Queries** (Critical)
   - `sessionComparison`: 2 database queries per access
   - `nextMilestone`: 1 count query per access
   - `matchingGoals`: 1 fetch query per access
   - These run **every time SwiftUI re-evaluates the view**

2. **Duplicate Data Fetching**
   - `fetchInkastingAnalyses()` called twice (lines 92, 188)
   - Session count fetched multiple times (lines 50, 116)

3. **Heavy onAppear**
   - Multiple synchronous database operations
   - Blocks main thread
   - Poor perceived performance

4. **No Caching**
   - Every view update refetches data
   - No memoization

### Performance Optimization Strategy

**Immediate** (High Impact):
1. Convert computed properties to `@State` with initialization in `onAppear`/`.task`
2. Cache `fetchInkastingAnalyses()` result
3. Consolidate duplicate queries

**Short-term** (Medium Impact):
1. Use `.task` instead of `onAppear` for async work
2. Add loading state during data fetch
3. Lazy-load sections (milestone, goals) only when visible

**Long-term** (Architectural):
1. Extract to ViewModel pattern
2. Implement proper caching layer
3. Use Combine to react to database changes

---

## 5. Security & Data Safety

### Current State
✅ **Generally Safe** - No major security issues

### Data Integrity Issues

1. **Silent Save Failures** (Lines 381, 413)
   ```swift
   try? modelContext.save()  // ❌ Ignores errors
   ```
   **Impact**: User thinks notes are saved but they're not

   **Fix**: Show error alert if save fails

2. **Concurrent Modification Risk**
   - `freshSession` and `session` both exist
   - Notes might be saved to wrong instance
   - No optimistic locking

3. **State Consistency**
   - Goal completion checked after arbitrary delay
   - Race condition between completion and display
   - Could show wrong goals or miss completions

---

## 6. Testing Considerations

### Current Testability: ⚠️ **Poor**

**Challenges**:
1. **No ViewModel**: All logic in view, hard to test
2. **Tight Coupling**: Direct modelContext dependency
3. **Computed Properties**: Side effects in computed properties
4. **Heavy Database Dependency**: Can't test without SwiftData stack

### Missing Test Coverage

1. **Goal Matching Logic** (lines 489-497) - Should be unit tested
2. **Progress Message Logic** (lines 514-527) - Pure function, should be tested
3. **Phase Color Mapping** (lines 499-512) - Should be tested
4. **Statistics Calculations** - Complex logic, needs tests
5. **Session Comparison Logic** - Critical feature, needs tests
6. **Note Saving** - Should verify persistence

### Recommended Test Strategy

**Extract Testable Logic**:
```swift
// Create separate file: InkastingSessionSummary.swift
struct InkastingSessionSummary {
    let session: TrainingSession
    let analyses: [InkastingAnalysis]

    var perfectRoundsCount: Int {
        analyses.filter { $0.outlierCount == 0 }.count
    }

    var consistencyPercentage: Double {
        guard !analyses.isEmpty else { return 0 }
        return Double(perfectRoundsCount) / Double(analyses.count) * 100
    }

    var avgSpread: Double {
        guard !analyses.isEmpty else { return 0 }
        return analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)
    }
}

// Now unit testable!
class InkastingSessionSummaryTests: XCTestCase {
    func testConsistencyCalculation() {
        // ...
    }
}
```

**Create ViewModel**:
```swift
@Observable
class InkastingSessionCompleteViewModel {
    let session: TrainingSession
    private let modelContext: ModelContext

    var sessionSummary: InkastingSessionSummary?
    var sessionComparison: ComparisonResult?
    var matchingGoals: [TrainingGoal] = []

    func loadData() async {
        // Testable with mock ModelContext
    }
}
```

---

## 7. Issues Found

### Critical 🔴

1. **Force Unwrap Crash Risk**
   - **Location**: Line 40
   - **Impact**: Potential crash
   - **Priority**: High
   - **Effort**: 5 minutes

2. **Computed Property Performance**
   - **Location**: Lines 35-44, 46-53, 55-62
   - **Impact**: Severe performance degradation, sluggish UI
   - **Priority**: Critical
   - **Effort**: 1 hour

3. **Duplicate Database Queries**
   - **Location**: Lines 92-93, 188-190, 50/116
   - **Impact**: Poor performance, unnecessary database load
   - **Priority**: High
   - **Effort**: 30 minutes

4. **Arbitrary Async Delay**
   - **Location**: Line 172
   - **Impact**: Race condition, unreliable goal display
   - **Priority**: High
   - **Effort**: 2-4 hours (requires refactoring goal evaluation)

### High Priority 🟠

5. **Silent Error Handling**
   - **Location**: Multiple (8+ instances)
   - **Impact**: Data loss, poor UX, hard to debug
   - **Priority**: High
   - **Effort**: 2 hours

6. **Heavy onAppear**
   - **Location**: Lines 158-180
   - **Impact**: UI lag on view appear
   - **Priority**: Medium-High
   - **Effort**: 1 hour

7. **State Management Confusion**
   - **Location**: Lines 23-24, 31-33
   - **Impact**: Bugs, hard to maintain
   - **Priority**: Medium
   - **Effort**: 1 hour

### Medium Priority 🟡

8. **No Loading State**
   - **Impact**: Poor UX during data fetch
   - **Priority**: Medium
   - **Effort**: 30 minutes

9. **Duplicate Code**
   - **Location**: Lines 379-382, 410-413
   - **Impact**: Maintainability
   - **Priority**: Low-Medium
   - **Effort**: 15 minutes

10. **Missing Accessibility**
    - **Impact**: Accessibility compliance
    - **Priority**: Medium
    - **Effort**: 1 hour

11. **Brittle Goal Detection**
    - **Location**: Lines 449-487
    - **Impact**: Missed celebrations, stale data
    - **Priority**: Medium
    - **Effort**: 3-4 hours (refactor needed)

---

## 8. Recommendations

### Immediate Actions (Critical Fixes)

1. **Fix Force Unwrap** ✅ Critical
   ```swift
   // Line 40
   guard let previousSession = lastSession else { return (nil, true) }
   let comparison = SessionComparisonService.getComparison(
       current: activeSession,
       previous: previousSession,
       context: modelContext
   )
   ```

2. **Convert Computed Properties to State** ✅ Critical
   ```swift
   @State private var sessionComparison: (comparison: ComparisonResult?, isFirst: Bool)?
   @State private var nextMilestone: MilestoneDefinition?
   @State private var matchingGoals: [TrainingGoal] = []
   @State private var sessionAnalyses: [InkastingAnalysis] = []
   @State private var perfectRoundsCount: Int = 0

   // Initialize in .task modifier
   .task {
       await loadAllData()
   }
   ```

3. **Remove Duplicate Queries** ✅ Critical
   - Cache analyses result
   - Cache session count
   - Reuse cached values

---

### High-Priority Improvements

4. **Add Error Handling UI** ✅ Important
   ```swift
   @State private var errorMessage: String?

   // Show error banner:
   if let error = errorMessage {
       ErrorBanner(message: error) {
           errorMessage = nil
       }
   }
   ```

5. **Add Loading State** ✅ Important
   ```swift
   @State private var isLoading = true

   if isLoading {
       ProgressView("Loading session data...")
   } else {
       // Main content
   }
   ```

6. **Extract Note Saving** ✅ Important
   ```swift
   private func saveSessionNotes() throws {
       guard !sessionNotes.isEmpty else { return }
       activeSession.notes = sessionNotes
       try modelContext.save()
   }
   ```

7. **Fix Goal Completion Detection** ✅ Important
   - Add "viewedInSession" property to goal completions
   - Don't rely on timestamps
   - Or: Pass completed goals from previous view

---

### Medium-Priority Enhancements

8. **Extract ViewModel** 📦 Recommended
   - Separate data logic from UI
   - Improve testability
   - Better state management

9. **Add Caching Layer** 📦 Recommended
   - Cache frequently accessed data
   - Invalidate on changes
   - Reduce database load

10. **Improve Accessibility** ♿ Important
    - Add labels to all icons
    - Add hints to buttons
    - Add values to progress bars
    - Test with VoiceOver

11. **Add Analytics** 📊 Optional
    - Track which sections viewed
    - Track action button usage
    - A/B test messaging

---

### Long-Term Architectural Improvements

12. **MVVM Pattern** (Recommended)
    ```swift
    @Observable
    class InkastingSessionCompleteViewModel {
        let session: TrainingSession
        var summary: SessionSummary?
        var comparison: ComparisonResult?
        var goals: [GoalProgress] = []
        var isLoading = false
        var errorMessage: String?

        func load() async { }
        func saveNotes(_ notes: String) throws { }
        func shareSession() { }
    }
    ```

13. **Service Layer Refactor**
    - Create unified SessionSummaryService
    - Consolidate database queries
    - Add caching
    - Better error propagation

14. **Reactive State Management**
    - Use Combine or Observation
    - React to database changes
    - Automatic UI updates

---

## 9. Compliance Checklist

### iOS Best Practices
- [x] Uses SwiftUI
- [ ] **Missing**: Loading states
- [ ] **Missing**: Error handling UI
- [x] Proper navigation patterns
- [ ] **Issue**: Heavy main thread work
- [ ] **Issue**: Computed properties with side effects

### SwiftData Patterns
- [ ] **Issue**: Too many direct queries in view
- [ ] **Issue**: No error handling for fetch operations
- [x] Proper use of @Query for settings
- [ ] **Issue**: Computed properties querying database
- [ ] **Missing**: @MainActor annotations for ModelContext operations

### SwiftUI Best Practices
- [x] Good view composition
- [ ] **Issue**: View is too large (529 lines)
- [ ] **Missing**: ViewModel pattern
- [x] Proper use of bindings
- [ ] **Issue**: Side effects in computed properties

### Accessibility
- [ ] **Missing**: Labels on decorative images
- [ ] **Missing**: Accessibility values for progress bars
- [x] Semantic text styling
- [ ] **Missing**: VoiceOver testing

### Performance
- [ ] **Critical**: Computed properties trigger database queries
- [ ] **Critical**: Duplicate data fetching
- [ ] **Issue**: Heavy onAppear processing
- [ ] **Missing**: Lazy loading
- [ ] **Missing**: Data caching

---

## 10. Code Examples

### Recommended ViewModel Pattern

```swift
@Observable
class InkastingSessionCompleteViewModel {
    // MARK: - Properties

    let session: TrainingSession
    private let modelContext: ModelContext
    private let sessionManager: TrainingSessionManager

    // MARK: - State

    var isLoading = false
    var errorMessage: String?

    var sessionSummary: SessionSummary?
    var sessionComparison: (comparison: ComparisonResult?, isFirst: Bool)?
    var matchingGoals: [TrainingGoal] = []
    var nextMilestone: MilestoneDefinition?
    var completedGoal: (goal: TrainingGoal, xp: Int)?
    var unseenMilestones: [MilestoneDefinition] = []

    // MARK: - Initialization

    init(session: TrainingSession, modelContext: ModelContext) {
        self.session = session
        self.modelContext = modelContext
        self.sessionManager = TrainingSessionManager(modelContext: modelContext)
    }

    // MARK: - Data Loading

    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load all data in parallel
            async let summary = loadSessionSummary()
            async let comparison = loadSessionComparison()
            async let goals = loadMatchingGoals()
            async let milestone = loadNextMilestone()
            async let completedGoal = checkGoalCompletion()
            async let milestones = loadUnseenMilestones()

            self.sessionSummary = try await summary
            self.sessionComparison = try await comparison
            self.matchingGoals = try await goals
            self.nextMilestone = try await milestone
            self.completedGoal = try await completedGoal
            self.unseenMilestones = try await milestones

        } catch {
            errorMessage = "Failed to load session data: \(error.localizedDescription)"
            AppLogger.inkasting.error("Error loading session complete data: \(error)")
        }
    }

    // MARK: - Private Loading Methods

    private func loadSessionSummary() async throws -> SessionSummary {
        let analyses = session.fetchInkastingAnalyses(context: modelContext)
        return SessionSummary(session: session, analyses: analyses)
    }

    private func loadSessionComparison() async throws -> (ComparisonResult?, Bool) {
        guard let lastSession = SessionComparisonService.findLastSession(
            matching: session,
            context: modelContext
        ) else {
            return (nil, true)
        }

        let comparison = SessionComparisonService.getComparison(
            current: session,
            previous: lastSession,
            context: modelContext
        )
        return (comparison, false)
    }

    private func loadMatchingGoals() async throws -> [TrainingGoal] {
        let descriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { $0.status == "active" }
        )
        let activeGoals = try modelContext.fetch(descriptor)
        return activeGoals.filter { goalMatches(goal: $0) }
    }

    private func loadNextMilestone() async throws -> MilestoneDefinition? {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let totalSessions = try modelContext.fetchCount(descriptor)
        let sessionMilestones = MilestoneDefinition.allMilestones.filter { $0.category == .sessionCount }
        return sessionMilestones.first { $0.threshold > totalSessions }
    }

    private func checkGoalCompletion() async throws -> (goal: TrainingGoal, xp: Int)? {
        // Improved: Check if session is in goal's completedSessionIds
        let descriptor = FetchDescriptor<TrainingGoal>(
            predicate: #Predicate { goal in
                goal.status == "completed" && goal.completedSessionIds.contains(session.id)
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        let completedGoals = try modelContext.fetch(descriptor)

        // Return first unviewed goal completion
        for goal in completedGoals {
            if !goal.viewedCompletionInSession {
                let xp = goal.baseXP + goal.bonusXP
                return (goal, xp)
            }
        }

        return nil
    }

    private func loadUnseenMilestones() async throws -> [MilestoneDefinition] {
        let milestoneService = MilestoneService(modelContext: modelContext)
        return milestoneService.getUnseenMilestones()
    }

    // MARK: - Actions

    func saveNotes(_ notes: String) throws {
        guard !notes.isEmpty else { return }
        session.notes = notes
        try modelContext.save()
        AppLogger.inkasting.debug("Session notes saved successfully")
    }

    func startNewSession(
        navigationPath: inout NavigationPath
    ) {
        let newSession = sessionManager.startSession(
            phase: session.phase ?? .inkastingDrilling,
            sessionType: session.sessionType ?? .inkasting5Kubb,
            rounds: session.configuredRounds
        )
        navigationPath.removeLast(navigationPath.count)
    }

    func markGoalViewed() {
        guard let goal = completedGoal?.goal else { return }
        goal.viewedCompletionInSession = true
        try? modelContext.save()
        completedGoal = nil
    }

    func markMilestoneViewed(_ milestone: MilestoneDefinition) {
        let milestoneService = MilestoneService(modelContext: modelContext)
        milestoneService.markAsSeen(milestoneId: milestone.id)

        // Update unseen list
        unseenMilestones = milestoneService.getUnseenMilestones()
    }

    // MARK: - Helpers

    private func goalMatches(goal: TrainingGoal) -> Bool {
        if let targetPhase = goal.phaseEnum {
            guard session.phase == targetPhase else { return false }
        }
        if let targetSessionType = goal.sessionTypeEnum {
            guard session.sessionType == targetSessionType else { return false }
        }
        return true
    }
}

// MARK: - Session Summary Model

struct SessionSummary {
    let session: TrainingSession
    let analyses: [InkastingAnalysis]

    var perfectRoundsCount: Int {
        analyses.filter { $0.outlierCount == 0 }.count
    }

    var consistencyPercentage: Double {
        guard !analyses.isEmpty else { return 0 }
        return Double(perfectRoundsCount) / Double(analyses.count) * 100
    }

    var avgSpread: Double {
        guard !analyses.isEmpty else { return 0 }
        return analyses.reduce(0.0) { $0 + $1.totalSpreadRadius } / Double(analyses.count)
    }

    var isPerfectSession: Bool {
        !analyses.isEmpty && perfectRoundsCount == analyses.count
    }
}
```

### Updated View (Simplified)

```swift
struct InkastingSessionCompleteView: View {
    @State private var viewModel: InkastingSessionCompleteViewModel
    @Binding var selectedTab: AppTab
    @Binding var navigationPath: NavigationPath

    @State private var sessionNotes: String = ""
    @State private var showShareSheet = false

    init(session: TrainingSession, selectedTab: Binding<AppTab>, navigationPath: Binding<NavigationPath>, modelContext: ModelContext) {
        self._selectedTab = selectedTab
        self._navigationPath = navigationPath
        self._viewModel = State(initialValue: InkastingSessionCompleteViewModel(
            session: session,
            modelContext: modelContext
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                contentView
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                successHeader

                if let summary = viewModel.sessionSummary {
                    statsSection(summary: summary)

                    if summary.perfectRoundsCount > 0 {
                        consistencyAchievement(summary: summary)
                    }
                }

                // ... other sections using viewModel data
            }
            .padding()
        }
    }

    // ... rest of view implementation
}
```

---

## Summary

### Overall Assessment: ⚠️ **Functional but Needs Optimization**

**Strengths**:
- Comprehensive session summary
- Good visual design and UX flow
- Well-organized UI sections
- Good integration with services
- Proper goal/milestone tracking

**Critical Gaps**:
- Performance issues (computed properties with database queries)
- Duplicate data fetching
- Silent error handling
- No loading states
- Race conditions in goal detection
- Poor testability (no ViewModel)

**Recommendation**: **Refactor before adding new features**. The performance issues and race conditions need to be addressed. The view works but will become sluggish with more data and is fragile due to timing-dependent code.

### Effort Estimate for Production-Ready
- **Critical fixes**: 3-4 hours
- **High-priority improvements**: 4-5 hours
- **ViewModel extraction**: 6-8 hours
- **Testing**: 4-6 hours
- **Total**: ~20-25 hours for complete refactor

### Risk Level: 🟡 MEDIUM-HIGH
- Medium risk for performance degradation as data grows
- Medium risk for race conditions
- Low risk for crashes (only one force unwrap)
- Medium risk for data integrity (silent save failures)

---

## Action Items

### Before Next Release
1. [ ] Fix force unwrap (Line 40)
2. [ ] Convert computed properties to @State
3. [ ] Remove duplicate database queries
4. [ ] Add loading state
5. [ ] Add error handling UI
6. [ ] Extract note saving to helper
7. [ ] Fix goal completion detection (remove arbitrary delay)

### Future Enhancements
8. [ ] Extract ViewModel pattern
9. [ ] Add comprehensive unit tests
10. [ ] Improve accessibility labels
11. [ ] Add analytics tracking
12. [ ] Optimize with caching layer
13. [ ] Consider pagination for goals/milestones if lists grow

---

**Review completed**: 2026-03-24
**Reviewed by**: Claude Code
**Next review recommended**: After implementing critical performance fixes
