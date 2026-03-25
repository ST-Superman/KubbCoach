# Code Review: PlayerPrestige.swift

**Date**: 2026-03-25
**File**: `Kubb Coach/Kubb Coach/Models/PlayerPrestige.swift`
**Lines**: 82

---

## Summary

**Overall Quality**: ⭐⭐⭐⭐☆ (4/5)

**Strengths**:
- Clean prestige/progression system
- Good computed properties for UI
- Clear title progression (CM → FM → IM → GM)

**Issues**:
1. **MEDIUM**: No validation for prestigeLevel (should be 1-60)
2. **MEDIUM**: No validation for totalPrestiges (should be >= 0)

---

## Recommendations

### Fix validation in init:

```swift
init(
    id: UUID = UUID(),
    prestigeLevel: Int = 1,
    totalPrestiges: Int = 0,
    lastPrestigedAt: Date? = nil
) {
    self.id = id

    // Validate prestigeLevel (1-60)
    if (1...60).contains(prestigeLevel) {
        self.prestigeLevel = prestigeLevel
    } else {
        AppLogger.database.warning("Invalid prestigeLevel: \(prestigeLevel). Defaulting to 1.")
        self.prestigeLevel = 1
    }

    // Validate totalPrestiges (>= 0)
    if totalPrestiges >= 0 {
        self.totalPrestiges = totalPrestiges
    } else {
        AppLogger.database.warning("Invalid totalPrestiges: \(totalPrestiges). Defaulting to 0.")
        self.totalPrestiges = 0
    }

    self.lastPrestigedAt = lastPrestigedAt
}
```

---

**Next Steps**:
1. ✅ Add validation
2. Build and test
