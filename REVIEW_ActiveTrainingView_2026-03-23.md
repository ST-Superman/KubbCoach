# Code Review: ActiveTrainingView.swift

**Review Date**: 2026-03-23
**File**: `Kubb Coach Watch Watch App/Views/ActiveTrainingView.swift`
**Lines**: 335
**Score**: 7/10

## Summary
Core training session UI for Apple Watch. Handles throw recording, king throw logic, and round completion. Generally well-structured but has a critical force-unwrap and numerous magic numbers that reduce maintainability.

## Architecture
- **Pattern**: SwiftUI view with state management
- **Dependencies**: TrainingSessionManager, WatchKit haptics
- **Responsibility**: Active training session UI, throw recording, navigation

## Issues Found

### 🔴 High Priority

**HP-1: Force Unwrap Crash Risk (Line 184)**
```swift
RoundCompletionView(
    session: session,
    round: round,
    sessionManager: sessionManager!  // ⚠️ Force unwrap
)
```
**Risk**: Crash if sessionManager is nil despite checks
**Fix**: Use guard statement or optional binding
```swift
if let session = sessionManager?.currentSession,
   let round = sessionManager?.currentRound,
   let manager = sessionManager {
    RoundCompletionView(
        session: session,
        round: round,
        sessionManager: manager
    )
}
```

**HP-2: Unused Computed Property**
```swift
private var elapsedTime: String {  // Lines 268-273
    // Defined but never used in view
}
```
**Impact**: Dead code, confusing for maintenance
**Fix**: Remove or display in UI

### 🟡 Medium Priority

**MP-1: Magic Numbers Throughout (40+ instances)**
All geometry scaling factors should be constants:
```swift
// Current scattered throughout:
.font(.system(size: min(geometry.size.height * 0.06, 11)))
.padding(.top, geometry.size.height * 0.02)
.frame(height: geometry.size.height * 0.45)

// Should be:
private enum LayoutConstants {
    static let roundInfoFontScale: CGFloat = 0.06
    static let throwNumberFontScale: CGFloat = 0.11
    static let topPaddingScale: CGFloat = 0.02
    static let buttonHeightScale: CGFloat = 0.45
    static let iconSizeScale: CGFloat = 0.14
    // ... etc
}
```
**Impact**: Hard to maintain consistent sizing, difficult to adjust layout
**Count**: ~25 different scaling factors used repeatedly

**MP-2: No Error Logging**
SessionManager operations have no logging:
```swift
private func startSession() {
    let manager = TrainingSessionManager(modelContext: modelContext)
    manager.startSession(...)
    sessionManager = manager
    // No logging if startSession fails internally
}
```

**MP-3: Hardcoded Training Phase**
```swift
manager.startSession(phase: .eightMeters, sessionType: .standard, rounds: configuredRounds)
```
**Issue**: Watch app always uses 8M mode
**Consider**: Allow configuration or document this limitation

## Strengths

✅ **Correct Array Handling**: Line 294 properly sorts throwRecords by throwNumber before indexing - avoids the undo bug pattern

✅ **Clean State Management**: Uses @State and @Binding appropriately

✅ **Good UX**: King throw alert logic is well-implemented

✅ **Haptic Feedback**: Appropriate use of WatchKit haptics for success/failure

✅ **Proper Guards**: Most optional unwrapping uses safe patterns (except HP-1)

✅ **Clear Layout**: Well-organized with MARK comments

✅ **Accessible**: Good use of minimumScaleFactor for text sizing

## Code Quality

**Positive**:
- Clean separation of concerns
- Computed properties for derived state
- Reusable ThrowProgressIndicator component
- Preview provider for development

**Needs Improvement**:
- Extract magic numbers to constants enum
- Add error logging for debugging
- Remove unused code (elapsedTime)
- Fix force unwrap crash risk

## Testing Considerations

**Current Testability**: Low - tightly coupled to WatchKit and SwiftUI environment

**Recommended Tests**:
- [ ] King throw logic (5 hits triggers alert)
- [ ] Round completion flow
- [ ] Session resume vs new session
- [ ] Undo disabled on first throw
- [ ] Throw count display accuracy
- [ ] Exit confirmation behavior

**Testing Challenges**:
- WatchKit haptics hard to test
- Navigation path binding complex to mock
- GeometryReader makes snapshot testing difficult

## Performance

- ✅ Efficient: No expensive operations in body
- ✅ Appropriate use of computed properties
- ⚠️ ForEach in ThrowProgressIndicator could cache sorted array (minor)

## Security & Privacy

- ✅ No sensitive data handling
- ✅ No external API calls
- ✅ Proper ModelContext usage

## Recommendations

### Must Fix (Before Production)
1. **Remove force unwrap** at line 184 - replace with proper optional binding
2. **Extract all magic numbers** to LayoutConstants enum - improves maintainability

### Should Fix (High Value)
3. **Add error logging** for session operations - aids debugging
4. **Remove elapsedTime** or display in UI - eliminate dead code

### Consider (Nice to Have)
5. Document why Watch only supports 8M mode or make configurable
6. Add accessibility labels for VoiceOver support
7. Consider caching sorted throws in ThrowProgressIndicator

## Compliance

- ✅ SwiftUI best practices mostly followed
- ✅ WatchKit integration correct
- ⚠️ Force unwrap violates safety guidelines
- ✅ Proper use of @Environment
- ⚠️ Could improve VoiceOver support

## Final Assessment

**Score: 7/10**

Well-implemented Watch training view with solid UX and mostly safe code. Main issues are the force-unwrap crash risk (critical) and extensive magic numbers (maintenance burden). The correct array sorting shows learning from previous bugs. Once HP-1 and MP-1 are fixed, this would be production-ready at 9/10.

**Estimated Fix Time**: 1-2 hours
- HP-1: 15 minutes
- MP-1: 45 minutes
- HP-2: 5 minutes
- MP-2: 15 minutes
