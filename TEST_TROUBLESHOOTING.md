# Test Troubleshooting Guide
## InkastingStatisticsViewModelTests

### Quick Fix: Use Simulator, Not Physical Device

**The most common issue**: Running tests on physical iPhone instead of simulator.

#### ✅ Correct Way (Simulator)
```bash
cd "/Users/sthompson/Developer/Kubb-Coach/Kubb Coach"
xcodebuild test -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

#### ❌ Wrong Way (Physical Device)
```bash
xcodebuild test -scheme "Kubb Coach" \
  -destination 'platform=iOS,name=Scott - personal'
```

---

## Why Tests Fail on Physical Device

1. **SwiftData In-Memory Storage**: Tests use `isStoredInMemoryOnly: true` which works best on simulators
2. **MainActor Threading**: Simulator provides more consistent async/await behavior
3. **Performance**: Physical devices are slower and may timeout
4. **Code Signing**: Test bundles may not be properly signed for device

---

## Common Error Messages & Solutions

### Error 1: "Testing failed"
**Likely Cause**: Running on physical device
**Solution**: Switch to simulator in Xcode device dropdown

### Error 2: "Thread 1: Fatal error: Unexpectedly found nil"
**Likely Cause**: SwiftData context not properly initialized
**Solution**: Tests already handle this - make sure running on simulator

### Error 3: "Test target Kubb_CoachTests is not part of scheme"
**Likely Cause**: Test target not enabled in scheme
**Solution**:
1. In Xcode: Product → Scheme → Edit Scheme
2. Select "Test" tab
3. Make sure "Kubb CoachTests" is checked

### Error 4: "Module 'Kubb_Coach' has no member 'InkastingStatisticsViewModel'"
**Likely Cause**: File not added to test target
**Solution**:
1. Select InkastingStatisticsViewModel.swift in Xcode
2. File Inspector → Target Membership
3. Make sure "Kubb Coach" is checked (NOT test target)

---

## How to Run Tests in Xcode

### Method 1: Test Navigator (Recommended)
1. Press `⌘+6` to open Test Navigator
2. **Select a SIMULATOR device** from device dropdown (top toolbar)
3. Find `InkastingStatisticsViewModelTests`
4. Click the ▶️ play button next to it

### Method 2: Keyboard Shortcut
1. **Select a SIMULATOR device** from device dropdown
2. Press `⌘+U` to run all tests

### Method 3: Individual Test
1. Open `InkastingStatisticsViewModelTests.swift`
2. Click the diamond icon in the gutter next to any test function
3. Make sure using simulator!

---

## Verify Tests Compile

Run this to check if tests build correctly:

```bash
cd "/Users/sthompson/Developer/Kubb-Coach/Kubb Coach"
xcodebuild build-for-testing -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Should end with: `** TEST BUILD SUCCEEDED **`

---

## Run Diagnostic Script

We've created a diagnostic script:

```bash
cd /Users/sthompson/Developer/Kubb-Coach
chmod +x test-diagnostics.sh
./test-diagnostics.sh
```

Share the output if you need help interpreting results.

---

## Expected Test Results

When tests run successfully, you should see:

```
Test Suite 'InkastingStatisticsViewModelTests' started
Test Case '-[Kubb_CoachTests.InkastingStatisticsViewModelTests testCalculateWithEmptySessions]' passed (0.001 seconds)
Test Case '-[Kubb_CoachTests.InkastingStatisticsViewModelTests testCalculateWithOnlyCloudSessions]' passed (0.002 seconds)
Test Case '-[Kubb_CoachTests.InkastingStatisticsViewModelTests testCalculateWithSingleSession]' passed (0.005 seconds)
...
Test Suite 'InkastingStatisticsViewModelTests' passed
    Executed 18 tests, with 0 failures
```

---

## Still Having Issues?

If tests still fail after switching to simulator, please share:

1. **Exact error message** you're seeing
2. **Device you're using** (simulator or physical)
3. **Output from diagnostic script**
4. **Xcode version**

This will help pinpoint the exact issue!

---

## Test List (18 Tests)

All these should pass:

**Empty State Tests (2)**
- ✅ testCalculateWithEmptySessions
- ✅ testCalculateWithOnlyCloudSessions

**Session Calculation Tests (2)**
- ✅ testCalculateWithSingleSession
- ✅ testCalculateWithMultipleSessions

**Spread Ratio Tests (2)**
- ✅ testSpreadRatioCalculation
- ✅ testSpreadRatioWithZeroClusterArea

**Consistency Tests (2)**
- ✅ testConsistencyScoreAllPerfect
- ✅ testConsistencyScoreNoPerfect

**Trend Tests (4)**
- ✅ testTrendCalculationImproving
- ✅ testTrendCalculationDeclining
- ✅ testTrendCalculationStable
- ✅ testTrendCalculationInsufficientData

**Data Points Test (1)**
- ✅ testSessionDataPointsGeneration

**Edge Cases (2)**
- ✅ testSessionWithNoAnalyses
- ✅ testMixedLocalAndCloudSessions

---

**Remember**: Always use **SIMULATOR** for unit tests! 📱✅
