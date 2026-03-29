# Review Follow-Up Tasks

This document tracks complex issues discovered during the systematic code review that require user input or significant architectural changes.

## Summary

- ✅ **1 of 1 tasks completed** (100%)
- Last updated: 2026-03-28

---

## 1. StatisticsAggregator - Best Accuracy Tracking

**File**: `Kubb Coach/Kubb Coach/Services/StatisticsAggregator.swift`
**Priority**: MEDIUM
**Status**: ⚠️ BLOCKED - SwiftData Versioning Limitation

### Problem

The current implementation tracks `bestEightMeterAccuracySessionId` but doesn't store the actual best accuracy value. This makes it impossible to accurately compare new sessions against the current best without fetching the best session from the database (expensive operation).

The temporary fix removes the broken comparison logic and only sets the first session as "best".

### Required Changes

1. **Add property to SessionStatisticsAggregate model**:
   ```swift
   var bestEightMeterAccuracy: Double?
   ```

2. **Create new schema version** (e.g., SchemaV9):
   - Add `bestEightMeterAccuracy` property to SessionStatisticsAggregate
   - Update KubbCoachMigrationPlan.swift
   - Test migration from V8 to V9

3. **Update StatisticsAggregator logic**:
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

4. **Test thoroughly**:
   - Migration from existing data
   - CloudKit sync compatibility
   - Rebuild aggregates functionality

### Why This Failed

**SwiftData Versioned Schema Limitation**: When you modify a model class (like adding `bestEightMeterAccuracy`), ALL schema versions (V2-V8) that reference `SessionStatisticsAggregate.self` see the modified version. This causes duplicate checksums across migration stages because SwiftData calculates checksums based on the **current** state of model classes, not historical snapshots.

### Alternative Approaches

Since we can't modify SessionStatisticsAggregate without breaking versioned schemas, here are alternatives:

**Option A: Separate Model (Recommended)**
Create a new `BestAccuracyCache` model that's NOT referenced by old schemas:
```swift
@Model
final class BestAccuracyCache {
    var phase: String
    var timeRange: String
    var bestAccuracy: Double
    var bestSessionId: UUID
    var lastUpdated: Date
}
```
Add this ONLY to SchemaV9 (new major version), not to existing schemas.

**Option B: UserDefaults**
Store best accuracy values in UserDefaults as a temporary workaround:
```swift
// Store: key = "best_8m_accuracy_week"
UserDefaults.standard.set(session.accuracy, forKey: "best_\(phase)_\(timeRange)")
```

**Option C: Accept Limitation**
Keep current approach: store only session ID, fetch actual accuracy when displaying:
```swift
if let sessionId = aggregate.bestEightMeterAccuracySessionId {
    let session = try? context.fetch(FetchDescriptor<TrainingSession>(
        predicate: #Predicate { $0.id == sessionId }
    )).first
    return session?.accuracy
}
```

**Option D: JSON File**
Store best accuracy values in a JSON file separate from SwiftData.

---

## Next Steps

When ready to tackle this issue:
1. Review migration strategy in KubbCoachMigrationPlan.swift
2. Create SchemaV9.swift with updated SessionStatisticsAggregate
3. Add migration logic
4. Test on simulator with existing data
5. Verify CloudKit sync still works
6. Update StatisticsAggregator.swift with proper comparison logic

---

**Last Updated**: 2026-03-25
