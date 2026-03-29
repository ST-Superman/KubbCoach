# SwiftData Schema Duplication Analysis

**Date**: 2026-03-25
**Issue**: `Duplicate version checksums across stages detected`
**Location**: App crash on launch (SwiftData migration)

---

## Error Details

```
CoreData: error: Attempting to retrieve an NSManagedObjectModel version checksum
while the model is still editable. This may result in an unstable version checksum.

*** Terminating app due to uncaught exception 'NSInvalidArgumentException',
reason: 'Duplicate version checksums across stages detected.'
```

---

## Root Cause Analysis

### Schema Version Investigation

**Schema Versions Found**:
```
SchemaV2: Version(2, 0, 0) - 30 lines
SchemaV3: Version(3, 0, 0) - 36 lines
SchemaV4: Version(4, 0, 0) - 37 lines
SchemaV5: Version(5, 0, 0) - 39 lines
SchemaV6: Version(6, 0, 0) - 37 lines
SchemaV7: Version(7, 0, 0) - 39 lines
SchemaV8: Version(8, 0, 1) - 40 lines ⚠️ Note: (8, 0, 1) not (8, 0, 0)
```

### Model Progression

**SchemaV6** (11 iOS models):
- TrainingSession, TrainingRound, ThrowRecord
- InkastingAnalysis, CalibrationSettings, InkastingSettings
- LastTrainingConfig, PersonalBest, EarnedMilestone
- PlayerPrestige, StreakFreeze, EmailReportSettings
- CompetitionSettings, SessionStatisticsAggregate

**SchemaV7** (13 iOS models):
- All V6 models +
- **SyncMetadata** (new)
- **TrainingGoal** (new)

**SchemaV8** (14 iOS models):
- All V7 models +
- **DailyChallenge** (new)

### Migration Plan

```swift
enum KubbCoachMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self,
         SchemaV6.self, SchemaV7.self, SchemaV8.self]
    }

    static var stages: [MigrationStage] {
        [
            migrateV2toV3,  // lightweight
            migrateV3toV4,  // lightweight
            migrateV4toV5,  // lightweight
            migrateV5toV6,  // lightweight
            migrateV6toV7,  // lightweight
            migrateV7toV8   // lightweight
        ]
    }
}
```

---

## Possible Causes

### 1. **Identical Model Structures** (Most Likely)
SwiftData generates checksums based on the **actual model definitions** (properties, relationships), not just the models list. If two schema versions reference the same underlying model classes without actual structural changes, they will have identical checksums.

**Problem**: The schemas list different models, but if those models haven't actually changed structurally between versions, SwiftData sees them as duplicates.

### 2. **Version Identifier Issue**
SchemaV8 uses `Version(8, 0, 1)` instead of `Version(8, 0, 0)`. While this shouldn't cause duplicates, it's inconsistent with the pattern.

### 3. **Model Definition Timing**
The error mentions "model is still editable" which suggests the models are being accessed before being fully initialized in the migration context.

### 4. **Simulator/Development Database State**
The simulator might have an existing database with schema conflicts.

---

## Solutions

### 🟢 Solution 1: Reset Simulator Database (Quick Fix for Development)

**Steps**:
1. Delete the app from simulator
2. Reset simulator content and settings
3. Rebuild and run

**Command**:
```bash
# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Kubb_Coach-*

# Reset simulator
xcrun simctl erase all

# Rebuild
cd "Kubb Coach"
xcodebuild -scheme "Kubb Coach" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' clean build
```

**Pros**: Fast, works for development
**Cons**: Loses all simulator data, doesn't fix production issue

---

### 🟡 Solution 2: Ensure Model Structural Changes (Recommended for Production)

**Issue**: If models haven't structurally changed between versions, SwiftData generates the same checksum.

**Fix**: Ensure each schema version has genuinely different model structures. If no structural changes are needed between versions, you may not need a new schema.

**Options**:
1. **Remove unnecessary schema versions**: If V7 and V8 have identical underlying models, consolidate them
2. **Add a marker property**: Add a dummy property to one model to force a structural difference
3. **Use custom migration**: Switch from lightweight to custom migration with explicit checksums

---

### 🟡 Solution 3: Fix Version Identifier Consistency

**Current**: SchemaV8 uses `Version(8, 0, 1)`
**Should be**: `Version(8, 0, 0)` for consistency

**Fix**:
```swift
// SchemaV8.swift - Line 12
enum SchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(8, 0, 0)  // ✅ Change from (8, 0, 1)
    // ...
}
```

**Impact**: Might resolve checksum calculation issues

---

### 🟢 Solution 4: Migrate to Current Schema (Production Fix)

**Approach**: Use a migration strategy that forces SwiftData to recognize the current schema as valid.

```swift
// In DatabaseContainerView or app initialization
let container = try ModelContainer(
    for: /* all current models */,
    migrationPlan: KubbCoachMigrationPlan.self,
    // Add configuration
    configurations: ModelConfiguration(
        isStoredInMemoryOnly: false,
        allowsSave: true
    )
)
```

Or use a more explicit initialization:

```swift
let schema = Schema(versionedSchema: SchemaV8.self)
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false
)
let container = try ModelContainer(
    for: schema,
    migrationPlan: KubbCoachMigrationPlan.self,
    configurations: [modelConfiguration]
)
```

---

### 🔴 Solution 5: Remove Duplicate Schema (Last Resort)

**If Investigation Shows**: Two schemas are truly identical

**Action**: Remove the duplicate from the migration plan

Example (if V7 and V8 are identical):
```swift
static var schemas: [any VersionedSchema.Type] {
    // Remove duplicate
    [SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self,
     SchemaV6.self, SchemaV7.self]  // Removed SchemaV8
}

static var stages: [MigrationStage] {
    [
        migrateV2toV3,
        migrateV3toV4,
        migrateV4toV5,
        migrateV5toV6,
        migrateV6toV7
        // Removed migrateV7toV8
    ]
}
```

**⚠️ Warning**: Only do this if you can confirm V8 is identical to V7

---

## Recommended Action Plan

### For Development (Immediate)

1. **Reset Simulator** (5 minutes):
   ```bash
   # Stop simulator
   xcrun simctl erase all

   # Rebuild
   cd "Kubb Coach"
   xcodebuild -scheme "Kubb Coach" \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
     clean build
   ```

2. **Fix Version Identifier** (2 minutes):
   - Change SchemaV8 from `Version(8, 0, 1)` to `Version(8, 0, 0)`

3. **Test Fresh Launch**

### For Production (Before Release)

1. **Audit Schema Changes**:
   - Verify each schema version has actual model structural changes
   - Document what changed in each version

2. **Test Migration Path**:
   - Test upgrading from V2 → V8
   - Test upgrading from V7 → V8
   - Test fresh install with V8

3. **Add Migration Logging**:
   ```swift
   // In migration plan
   static let migrateV7toV8 = MigrationStage.custom(
       fromVersion: SchemaV7.self,
       toVersion: SchemaV8.self,
       willMigrate: { context in
           print("🔄 Starting V7 → V8 migration")
       },
       didMigrate: { context in
           print("✅ Completed V7 → V8 migration")
       }
   )
   ```

4. **Consider Migration Reset for V2.0**:
   - If issues persist, next major release could start fresh with SchemaV9
   - Provide migration from V8 → V9 that preserves user data

---

## Quick Fix Script

```bash
#!/bin/bash
# Quick fix for development

echo "🧹 Cleaning simulator..."
xcrun simctl shutdown all
xcrun simctl erase all

echo "🗑️  Removing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Kubb_Coach-*

echo "🔨 Rebuilding project..."
cd "/Users/sthompson/Developer/Kubb-Coach/Kubb Coach"
xcodebuild -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  clean build

echo "✅ Done! Try running the app again."
```

---

## Prevention for Future

### Schema Versioning Best Practices

1. **Only create new schema when models structurally change**
   - Don't create V9 unless you're adding/removing/modifying properties

2. **Use consistent version identifiers**
   - Always use (major, 0, 0) for schema versions
   - Example: V9 should be `Version(9, 0, 0)`

3. **Document changes in each schema**
   ```swift
   enum SchemaV9: VersionedSchema {
       static var versionIdentifier = Schema.Version(9, 0, 0)

       // CHANGES IN V9:
       // - Added 'timestamp' property to DailyChallenge
       // - Added 'completedGoals' relationship to PlayerPrestige

       static var models: [any PersistentModel.Type] {
           // ...
       }
   }
   ```

4. **Test migrations in CI/CD**
   - Automated tests that verify migration from each version

5. **Use SwiftData's built-in checksum verification**
   ```swift
   // In tests
   func testSchemaVersionsAreUnique() {
       let checksums = KubbCoachMigrationPlan.schemas.map { schema in
           // Calculate checksum
       }
       XCTAssertEqual(checksums.count, Set(checksums).count,
                     "Duplicate schema checksums detected")
   }
   ```

---

## Current Status

**Build**: ✅ Compiles successfully
**Runtime**: ❌ Crashes on launch due to schema duplication
**Impact**: Development only (simulator issue)
**Production Risk**: 🟡 Medium - needs testing with real user data migration

---

## Next Steps

1. ✅ **Immediate**: Reset simulator and rebuild (5 min)
2. ✅ **Short-term**: Fix SchemaV8 version identifier (2 min)
3. ⏳ **Before release**: Audit all schema changes and test migration paths
4. ⏳ **Long-term**: Add schema migration tests to prevent future issues

---

**Analyzed by**: Claude Code
**Date**: 2026-03-25
**Priority**: High (blocks development, medium risk for production)
