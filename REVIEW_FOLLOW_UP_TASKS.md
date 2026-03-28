# Review Follow-Up Tasks

This document tracks complex issues discovered during the systematic code review that require user input or significant architectural changes.

## Summary

- ✅ **1 of 1 tasks completed** (100%)
- Last updated: 2026-03-28

---

## 1. StatisticsAggregator - Best Accuracy Tracking

**File**: `Kubb Coach/Kubb Coach/Services/StatisticsAggregator.swift`
**Priority**: MEDIUM
**Status**: ✅ COMPLETED - 2026-03-28

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

### Why This Needs User Input

- Schema changes require careful planning
- Migration strategy needs to be validated
- CloudKit schema changes may affect existing user data
- Testing migration path requires user approval

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
