# Fix for BlastingStatisticsCalculatorTests

## Problem
The test failures are caused by trying to reverse-engineer the golf scoring formula. The mock data generator was attempting to create specific scores, but the formula `score = (throws - par) + (remainingKubbs × 2)` is too complex to reliably reverse.

## Solution
**Use explicit throw/kubb data instead of target scores:**

### Old Approach (Broken)
```swift
// Trying to create a session with score of -5
let sessions = createMockSessions(scores: [
    (-5, [-1, -1, -1, -1, -1, 0, 0, 0, 0])  // Target scores
], startDate: Date())
```

### New Approach (Fixed)
```swift
// Create explicit data: 1 throw, knock down all 2 kubbs
// Score will be: (1 - 2) + (0 × 2) = -1 (birdie)
let sessions = createMockSessions(rounds: [
    [(throws: 1, kubbs: 2)]  // Round 1: 1 throw, 2 kubbs knocked
], startDate: Date())

// Calculate expected score
let expectedScore = (1 - 2) + (0 * 2) = -1
```

## Par Values by Round
```
Round 1 (2 kubbs): par = 2
Round 2 (3 kubbs): par = 2
Round 3 (4 kubbs): par = 3
Round 4 (5 kubbs): par = 3
Round 5 (6 kubbs): par = 3
Round 6 (7 kubbs): par = 4
Round 7 (8 kubbs): par = 4
Round 8 (9 kubbs): par = 4
Round 9 (10 kubbs): par = 5
```

## Score Calculation Examples

### Example 1: Birdie (-1) on Round 1
- Target: 2 kubbs, Par: 2
- Use 1 throw, knock down all 2 kubbs
- Score = (1 - 2) + (0 × 2) = **-1**

### Example 2: Eagle (-2) on Round 3
- Target: 4 kubbs, Par: 3
- Use 1 throw, knock down all 4 kubbs
- Score = (1 - 3) + (0 × 2) = **-2**

### Example 3: Par (0) on Round 1
- Target: 2 kubbs, Par: 2
- Use 2 throws, knock down all 2 kubbs
- Score = (2 - 2) + (0 × 2) = **0**

### Example 4: Bogey (+1) on Round 1
- Target: 2 kubbs, Par: 2
- Use 3 throws, knock down all 2 kubbs
- Score = (3 - 2) + (0 × 2) = **+1**

### Example 5: Double Bogey with penalty
- Target: 2 kubbs, Par: 2
- Use 3 throws, knock down only 1 kubb (1 remaining)
- Score = (3 - 2) + (1 × 2) = **+3**

## How to Fix Each Test

For each failing test:

1. **Identify the desired outcome** (e.g., "test under par rounds")
2. **Create explicit data** using (throws, kubbs) format
3. **Calculate expected score** using the formula
4. **Update assertions** to match calculated score

### Example Fix

**Before:**
```swift
@Test("Average session score with single session")
func testAverageWithSingleSession() {
    let sessions = createMockSessions(scores: [
        (-5, [-1, -1, -1, -1, -1, 0, 0, 0, 0])
    ], startDate: Date())

    #expect(calculator.averageSessionScore == -5.0)  // FAILS
}
```

**After:**
```swift
@Test("Average session score with single session")
func testAverageWithSingleSession() {
    // Create 1 session with 9 rounds, all at par
    let sessions = createMockSessions(rounds: [
        [
            (throws: 2, kubbs: 2),  // R1: par
            (throws: 2, kubbs: 3),  // R2: par
            (throws: 3, kubbs: 4),  // R3: par
            (throws: 3, kubbs: 5),  // R4: par
            (throws: 3, kubbs: 6),  // R5: par
            (throws: 4, kubbs: 7),  // R6: par
            (throws: 4, kubbs: 8),  // R7: par
            (throws: 4, kubbs: 9),  // R8: par
            (throws: 5, kubbs: 10)  // R9: par
        ]
    ], startDate: Date())

    // All rounds are par (0), so session score = 0
    let calculator = BlastingStatisticsCalculator(sessions: sessions)
    #expect(calculator.averageSessionScore == 0.0)
}
```

## Quick Reference: Creating Specific Scores

### To create birdies (-1):
- **Round 1**: 1 throw, 2 kubbs
- **Round 2**: 1 throw, 3 kubbs
- **Round 3**: 2 throws, 4 kubbs
- **Round 4**: 2 throws, 5 kubbs
- **Round 5**: 2 throws, 6 kubbs

### To create eagles (-2):
- **Round 3**: 1 throw, 4 kubbs
- **Round 6**: 2 throws, 7 kubbs
- **Round 9**: 3 throws, 10 kubbs

### To create par (0):
- Use exactly par throws and knock down all kubbs

### To create bogeys (+1):
- Use par + 1 throws and knock down all kubbs

## Testing Strategy

1. **Start with simple tests** (empty sessions, single par round)
2. **Add variety gradually** (mix of scores)
3. **Use helper to calculate expected values**
4. **Verify actual scores match expected**

## Updated Helper Functions Available

```swift
// Calculate what score SHOULD be for given data
expectedScore(roundNumber: Int, throws: Int, kubbsKnockedDown: Int) -> Int

// Get par for a round
parForRound(roundNumber: Int) -> Int
```

## Next Steps

1. Update each test method to use new format
2. Calculate expected scores using helper
3. Run tests and verify they pass
4. The test file structure remains the same - only the data creation changes
