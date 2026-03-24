# Code Review: BlastingActiveTrainingView.swift

**Review Date**: 2026-03-23
**File**: `Kubb Coach Watch Watch App/Views/BlastingActiveTrainingView.swift`
**Lines**: 344
**Score**: 7/10

## Summary
4M blasting mode training UI for Apple Watch. Handles kubb counting, throw recording, and round progression. Similar structure to ActiveTrainingView with same categories of issues: force unwrap, magic numbers, and missing logging.

## Architecture
- **Pattern**: SwiftUI view with state management
- **Dependencies**: TrainingSessionManager, WatchKit haptics
- **Responsibility**: 4M blasting training UI, kubb count tracking, navigation

## Issues Found

### 🔴 High Priority

**HP-1: Force Unwrap Crash Risk (Line 153)**
```swift
BlastingRoundCompletionView(
    session: session,
    round: round,
    sessionManager: sessionManager!,  // ⚠️ Force unwrap
    navigationPath: $navigationPath
)
```
**Risk**: Crash if sessionManager is nil despite checks
**Fix**: Use optional binding like ActiveTrainingView fix
```swift
if let session = sessionManager?.currentSession,
   let round = sessionManager?.currentRound,
   let manager = sessionManager {
    BlastingRoundCompletionView(
        session: session,
        round: round,
        sessionManager: manager,
        navigationPath: $navigationPath
    )
}
```

**HP-2: Hardcoded Round Count (Lines 16, 30)**
```swift
let configuredRounds: Int = 9  // Line 16
Text("Round \(currentRoundNumber) of 9")  // Line 30
```
**Issue**: Magic number 9 repeated, not using `configuredRounds` constant
**Fix**: Use `configuredRounds` property in both places

### 🟡 Medium Priority

**MP-1: Magic Numbers Throughout (35+ instances)**
All geometry scaling factors should be extracted to constants:
```swift
// Current scattered throughout:
.font(.system(size: min(geometry.size.height * 0.06, 11)))
.padding(.top, geometry.size.height * 0.015)
.font(.system(size: min(geometry.size.height * 0.22, 44), weight: .bold))

// Should be:
fileprivate enum LayoutConstants {
    // Font scales
    static let roundInfoFontScale: CGFloat = 0.06
    static let throwInfoFontScale: CGFloat = 0.07
    static let largeNumberFontScale: CGFloat = 0.22

    // Spacing/padding
    static let topPaddingScale: CGFloat = 0.015
    static let buttonSpacingScale: CGFloat = 0.05

    // Max kubbs per throw
    static let maxKubbsPerThrow: Int = 10
    static let blastingRoundCount: Int = 9
    static let throwsPerRound: Int = 6

    // ... etc
}
```
**Impact**: Hard to maintain, difficult to adjust layout consistency
**Count**: ~30 different scaling factors used

**MP-2: No Error Logging**
No OSLog for debugging session operations:
```swift
private func startSession() {
    let manager = TrainingSessionManager(modelContext: modelContext)
    // ... no logging if operations fail
}

private func confirmThrow() {
    guard let manager = sessionManager else { return }
    manager.recordBlastingThrow(kubbsKnockedDown: currentKubbCount)
    // No logging of throw recording
}
```
**Fix**: Add OSLog logger like ActiveTrainingView

**MP-3: Magic Number for Max Kubbs (Line 250)**
```swift
return min(10, max(0, remaining))
```
**Issue**: 10 is the game rule (max kubbs per throw) but not documented
**Fix**: Extract to `LayoutConstants.maxKubbsPerThrow` with comment

## Strengths

✅ **Correct Array Handling**: Line 321 properly sorts throwRecords by throwNumber before indexing

✅ **Clean State Management**: Proper use of @State and @Binding

✅ **Good UX**: Number picker with +/- buttons appropriate for Watch

✅ **Haptic Feedback**: Appropriate use of WatchKit haptics (click for count, success for confirmation)

✅ **Preview Progress**: Nice UX showing pending kubbs in progress bar

✅ **Smart Max Calculation**: `maxKubbsForThrow` accounts for remaining kubbs and game rules

✅ **Auto-completion**: `onChange(of: isBlastingRoundComplete)` automatically advances on completion

## Code Quality

**Positive**:
- Clean separation of concerns
- Reusable components (KubbProgressBar, BlastingThrowProgressIndicator)
- Computed properties for derived state
- Good guards for nil checks (except HP-1)
- Preview provider for development

**Needs Improvement**:
- Extract all magic numbers to constants enum
- Add error logging for debugging
- Fix force unwrap crash risk
- Use configuredRounds property consistently

## Testing Considerations

**Current Testability**: Low - tightly coupled to WatchKit and SwiftUI

**Recommended Tests**:
- [ ] Kubb count increment/decrement logic
- [ ] Max kubbs calculation (respects 10 limit and remaining kubbs)
- [ ] Round auto-completion when target reached
- [ ] Undo disabled on first throw
- [ ] Session resume vs new session
- [ ] Progress bar calculations (current, pending, preview)

**Testing Challenges**:
- WatchKit haptics hard to test
- Navigation path binding complex to mock
- GeometryReader makes snapshot testing difficult

## Performance

- ✅ Efficient: No expensive operations in body
- ✅ Appropriate use of computed properties
- ⚠️ `currentRoundScore` (line 243) filters rounds on every access - could cache (minor)
- ⚠️ ForEach in progress indicators could cache sorted arrays (minor)

## Security & Privacy

- ✅ No sensitive data handling
- ✅ No external API calls
- ✅ Proper ModelContext usage

## Recommendations

### Must Fix (Before Production)
1. **Remove force unwrap** at line 153 - replace with proper optional binding
2. **Extract all magic numbers** to LayoutConstants enum - ~30 instances to fix
3. **Use configuredRounds consistently** - line 30 should reference the property

### Should Fix (High Value)
4. **Add error logging** with OSLog - aids debugging on Watch
5. **Extract maxKubbsPerThrow constant** (10) with documentation

### Consider (Nice to Have)
6. Cache sorted throws in progress indicators for minor performance gain
7. Add accessibility labels for VoiceOver support
8. Consider caching currentRoundScore calculation

## Compliance

- ✅ SwiftUI best practices mostly followed
- ✅ WatchKit integration correct
- ⚠️ Force unwrap violates safety guidelines (HP-1)
- ✅ Proper use of @Environment
- ⚠️ Could improve VoiceOver support

## Comparison to ActiveTrainingView

This view has nearly identical issues to ActiveTrainingView:
- Same force unwrap pattern
- Same magic numbers problem
- Same lack of logging
- Both correctly handle array sorting

The fixes applied to ActiveTrainingView should be replicated here.

## Final Assessment

**Score: 7/10**

Well-implemented Watch blasting training view with good UX for kubb counting. Main issues are identical to ActiveTrainingView: force-unwrap crash risk (critical) and extensive magic numbers (maintenance burden). The correct array sorting shows good learning from previous bugs. Once HP-1, HP-2, and MP-1 are fixed, this would be production-ready at 9/10.

**Estimated Fix Time**: 1-2 hours
- HP-1: 15 minutes
- HP-2: 5 minutes
- MP-1: 45 minutes
- MP-2: 15 minutes
