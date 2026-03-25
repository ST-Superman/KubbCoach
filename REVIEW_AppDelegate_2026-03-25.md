# Code Review: AppDelegate.swift

**Date**: 2026-03-25
**Reviewer**: Claude Code
**File**: `Kubb Coach/Kubb Coach/AppDelegate.swift`
**Lines of Code**: 148
**Created**: 2026-03-23

---

## 1. File Overview

### Purpose
`AppDelegate.swift` serves as the UIKit application lifecycle manager for Kubb Coach, handling:
- Push notification delegate setup and response handling
- Deep linking via custom URL scheme (`kubbcoach://`)
- Comeback notification scheduling based on user inactivity
- Bridge between UIKit (notifications) and SwiftUI (navigation)

### Key Dependencies
- **UIKit**: Application lifecycle and URL handling
- **UserNotifications**: Local notification management
- **OSLog**: Structured logging
- **NotificationService**: Custom service for notification permissions and settings

### Integration Points
- Notification responses trigger deep links via `NotificationCenter.default.post`
- SwiftUI layer listens for `"HandleDeepLink"` notifications
- NotificationService provides authorization checks
- (TODO) Will integrate with TrainingSessionManager for comeback logic

---

## 2. Architecture Analysis

### Design Patterns Used
✅ **Delegate Pattern**: Implements `UIApplicationDelegate` and `UNUserNotificationCenterDelegate`
✅ **Observer Pattern**: Posts notifications to `NotificationCenter` for SwiftUI coordination
✅ **Command Pattern**: Deep link URLs act as navigation commands
✅ **Strategy Pattern**: Switch statement routes notification categories to appropriate deep links

### SOLID Principles

| Principle | Assessment | Notes |
|-----------|------------|-------|
| **Single Responsibility** | ✅ Good | Focused on notification handling and deep linking |
| **Open/Closed** | ⚠️ Moderate | Adding new notification categories requires modifying switch statement |
| **Liskov Substitution** | ✅ N/A | No subclassing used |
| **Interface Segregation** | ✅ Good | Implements only required delegate methods |
| **Dependency Inversion** | ⚠️ Moderate | Direct dependency on `NotificationService.shared` singleton |

### Code Organization
```
AppDelegate.swift
├── Class Declaration & Properties
├── UIApplicationDelegate Methods
│   └── didFinishLaunchingWithOptions
├── UNUserNotificationCenterDelegate Methods
│   ├── willPresent (foreground notifications)
│   └── didReceive (notification tap handling)
├── Private Helper Methods
│   ├── handleNotificationResponse
│   └── checkForComebackNotifications
└── Deep Link Extension
    └── open URL handler
```

**Strengths**:
- Clear MARK sections separate concerns
- Logical top-to-bottom flow (lifecycle → delegates → helpers → extensions)
- Private implementation details properly hidden

**Areas for Improvement**:
- Deep link URL mapping could be extracted to separate router

### Separation of Concerns
✅ **Well-separated**:
- Notification handling isolated from business logic
- Deep linking abstracted via URL scheme
- Logging consistent and non-intrusive
- SwiftUI navigation handled by external observers

---

## 3. Code Quality

### SwiftUI/SwiftData Best Practices
✅ **Correct MainActor usage**: All async notification handlers properly annotated with `@MainActor`
✅ **Task wrapping**: Async work properly wrapped in `Task { @MainActor in }`
⚠️ **SwiftData integration pending**: TODO comment indicates TrainingSessionManager integration needed

### Error Handling Patterns
⚠️ **Limited error handling**:
- No try-catch blocks (none needed for current implementation)
- Silent failure on unauthorized notifications (guard statement with early return)
- No error reporting for failed deep links

**Recommendation**: Consider logging when guards fail (e.g., "Skipping comeback check - notifications not authorized")

### Optionals Management
✅ **Excellent**:
- No force-unwrapping (`!`) found
- Safe optional dictionary access in `didFinishLaunchingWithOptions`
- Guard statements used appropriately

### Async/Await Usage
✅ **Modern and correct**:
- `async` functions properly defined with `await` calls
- `@MainActor` annotations prevent threading issues
- Task creation follows best practices

### Memory Management
✅ **No obvious issues**:
- No strong reference cycles detected
- Delegate pattern properly configured (center holds weak reference)
- Completion handlers called exactly once

**Potential concern**: `NotificationService.shared` singleton - verify service doesn't create strong reference back to AppDelegate

---

## 4. Performance Considerations

### Potential Bottlenecks
✅ **Minimal performance impact**:
- Notification handling is event-driven (no polling)
- Deep link routing via switch statement is O(1) with compiler optimization
- Logging uses modern OSLog (optimized for production)

### Database Query Optimization
⚠️ **Not yet implemented**:
- Line 115 TODO: "Query last session from database"
- **Future recommendation**: Use indexed query on `createdAt` when implemented:
  ```swift
  let descriptor = FetchDescriptor<TrainingSession>(
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
  )
  descriptor.fetchLimit = 1
  ```

### UI Rendering Efficiency
✅ **N/A** - AppDelegate doesn't render UI

### Memory Usage Patterns
✅ **Lightweight**:
- Only one property: `logger` (minimal overhead)
- No large data structures held in memory
- Notification payloads deallocated after handling

---

## 5. Security & Data Safety

### Input Validation
⚠️ **Limited validation**:
- Deep link URLs built internally (safe)
- External URLs accepted in `open url:` without validation beyond scheme check
- **Risk**: Malicious `kubbcoach://` URLs could be crafted

**Recommendation**: Add URL path validation:
```swift
guard url.scheme == "kubbcoach",
      let host = url.host,
      ["home", "journey", "settings"].contains(host) else {
    logger.warning("Rejected invalid deep link: \(url)")
    return false
}
```

### Data Sanitization
✅ **No user input processed** - all strings are static or system-provided

### CloudKit Data Handling
✅ **N/A** - No CloudKit operations in this file

### Privacy Considerations
✅ **Privacy-conscious**:
- Checks authorization before scheduling notifications
- Logs identifiers but not user data
- No PII exposed in logs

⚠️ **Consideration**: Notification content should not include personal stats (check NotificationService)

---

## 6. Testing Considerations

### Testability of Current Implementation
⚠️ **Moderate testability challenges**:

**Barriers to testing**:
- Direct dependency on `NotificationService.shared` (singleton)
- `NotificationCenter.default.post` not easily mockable
- UIKit delegate methods require simulator/device context

**Can be tested**:
- Deep link URL scheme validation (via `open url:` method)
- Switch statement logic (notification category → URL mapping)

### Missing Test Coverage Areas
- ❌ No tests exist for AppDelegate yet
- Notification response handling logic untested
- Deep link routing untested
- Comeback notification scheduling logic untested

### Recommended Test Cases

**Unit Tests** (require refactoring for testability):
1. **testNotificationCategoryToDeepLinkMapping**
   - Input: Each notification category
   - Expected: Correct deep link URL generated

2. **testHandleDeepLinkPostedToNotificationCenter**
   - Verify NotificationCenter.post called with correct parameters

3. **testComebackNotificationSkippedWhenUnauthorized**
   - Mock NotificationService.isAuthorized() → false
   - Verify no notification scheduled

4. **testInvalidURLSchemeRejected**
   - Input: `https://example.com`
   - Expected: Returns false, no notification posted

**Integration Tests**:
5. **testNotificationTapNavigatesToCorrectScreen**
   - Simulate notification tap
   - Verify SwiftUI view changes

6. **testCustomURLSchemeOpensApp**
   - Test `kubbcoach://home` from external source

---

## 7. Issues Found

### Critical Issues
✅ **None identified**

### Potential Bugs
⚠️ **PB-1**: Race condition in comeback notification check
- **Location**: Line 25-27, `didFinishLaunchingWithOptions`
- **Issue**: `Task { @MainActor in }` is fire-and-forget - app launch may complete before check finishes
- **Impact**: Low - only affects timing of comeback notification
- **Fix**: Add `async` to method signature if needed, or accept fire-and-forget behavior

⚠️ **PB-2**: No handling for notification permission denial mid-flight
- **Location**: Line 112, `checkForComebackNotifications`
- **Issue**: If user revokes permission between `isAuthorized()` check and scheduling, no error handling
- **Impact**: Low - NotificationService should handle this, but AppDelegate won't know
- **Fix**: Add error handling when comeback notification scheduling is implemented

### Code Smells
🔶 **CS-1**: Magic string notification identifiers
- **Location**: Lines 78, 82, 86, 90 (notification categories), Line 100/141 ("HandleDeepLink")
- **Issue**: String literals repeated, no type safety
- **Recommendation**: Create enum:
  ```swift
  enum NotificationCategory: String {
      case streakWarning = "STREAK_WARNING"
      case dailyChallenge = "DAILY_CHALLENGE"
      case comebackPrompt = "COMEBACK_PROMPT"
      case preCompetition = "PRE_COMPETITION"
  }

  enum DeepLinkNotification {
      static let name = Notification.Name("HandleDeepLink")
      static let urlKey = "url"
  }
  ```

🔶 **CS-2**: Switch statement will grow with new notification types
- **Location**: Lines 76-96, `handleNotificationResponse`
- **Issue**: Violates Open/Closed Principle
- **Recommendation**: Extract to router with dictionary mapping:
  ```swift
  struct DeepLinkRouter {
      static let routes: [String: String] = [
          "STREAK_WARNING": "kubbcoach://home/start-session",
          "DAILY_CHALLENGE": "kubbcoach://journey/daily-challenge",
          // ...
      ]
  }
  ```

🔶 **CS-3**: Direct singleton dependency
- **Location**: Lines 112-113, `NotificationService.shared`
- **Issue**: Tight coupling, difficult to test
- **Recommendation**: Use protocol-based injection:
  ```swift
  protocol NotificationServiceProtocol {
      func isAuthorized() async -> Bool
      func isNotificationTypeEnabled(_ type: NotificationType) -> Bool
  }

  class AppDelegate {
      var notificationService: NotificationServiceProtocol = NotificationService.shared
  }
  ```

### Technical Debt
📋 **TD-1**: TODO on line 115-117
- **Description**: "Query last session from database when integrated with TrainingSessionManager"
- **Priority**: High (core feature incomplete)
- **Effort**: Medium (requires SwiftData query + date comparison logic)
- **Blocker for**: Comeback notification feature

📋 **TD-2**: No deep link URL validation
- **Description**: External `kubbcoach://` URLs accepted without path validation
- **Priority**: Medium (security consideration)
- **Effort**: Low (1-2 hours)

---

## 8. Recommendations

### High Priority
1. **Implement comeback notification database query** (Line 115 TODO)
   - Query TrainingSessionManager for last session
   - Calculate days since last activity
   - Schedule notification if > 7 days inactive
   - **Effort**: 4-6 hours
   - **Impact**: Enables user re-engagement feature

2. **Add deep link URL validation** (Security)
   - Whitelist valid URL paths
   - Log/reject malicious URLs
   - **Effort**: 2 hours
   - **Impact**: Prevents potential security issues

3. **Create notification category enum** (Code smell CS-1)
   - Replace magic strings with type-safe enum
   - Update NotificationService to use same enum
   - **Effort**: 2 hours
   - **Impact**: Prevents typos, improves maintainability

### Medium Priority
4. **Extract deep link router** (Code smell CS-2)
   - Create `DeepLinkRouter` class/struct
   - Move category → URL mapping out of AppDelegate
   - **Effort**: 3 hours
   - **Impact**: Easier to add new notification types

5. **Add unit tests for AppDelegate** (Testing gap)
   - Refactor for testability (inject dependencies)
   - Test notification routing logic
   - Test URL scheme handling
   - **Effort**: 6-8 hours
   - **Impact**: Prevent regressions in critical notification path

6. **Add error handling for notification failures**
   - Log when guards fail (permission denied, feature disabled)
   - Report metrics for notification engagement
   - **Effort**: 2 hours
   - **Impact**: Better observability

### Nice-to-Have
7. **Protocol-based dependency injection** (Code smell CS-3)
   - Create `NotificationServiceProtocol`
   - Inject into AppDelegate
   - **Effort**: 3 hours
   - **Impact**: Improves testability

8. **Add analytics tracking for notification taps**
   - Track which notification types drive engagement
   - Measure deep link success rate
   - **Effort**: 3 hours
   - **Impact**: Product insights

---

## 9. Compliance Checklist

### iOS Best Practices
- ✅ Uses modern `async/await` instead of completion handlers
- ✅ Implements notification delegate methods correctly
- ✅ Handles foreground notifications appropriately
- ✅ Uses structured logging (OSLog)
- ⚠️ Could benefit from error handling improvements

### SwiftData Patterns
- ⚠️ Not yet integrated (TODO on line 115)
- ⚠️ When implemented, ensure queries use `@MainActor`

### CloudKit Guidelines
- ✅ N/A - No CloudKit operations in this file

### Accessibility Considerations
- ✅ N/A - AppDelegate has no UI
- ✅ Deep links should navigate to accessible screens (verify in SwiftUI layer)

### App Store Guidelines
- ✅ Requests notification permission appropriately (handled in NotificationService)
- ✅ Uses custom URL scheme (registered in Info.plist)
- ⚠️ Ensure comeback notifications respect user preferences (frequency limits)

### Privacy Guidelines
- ✅ No PII logged
- ✅ Checks authorization before scheduling notifications
- ⚠️ Ensure notification content doesn't leak sensitive training stats

---

## 10. Summary

### Overall Assessment: **B+ (Good, with room for improvement)**

**Strengths**:
- ✅ Clean, well-organized code with clear separation of concerns
- ✅ Modern Swift patterns (`async/await`, `@MainActor`, OSLog)
- ✅ Proper delegate implementation
- ✅ No force-unwrapping or obvious bugs
- ✅ Privacy-conscious logging

**Weaknesses**:
- ⚠️ Core comeback notification feature incomplete (TODO)
- ⚠️ Limited testability due to singleton dependencies
- ⚠️ Magic strings instead of type-safe enums
- ⚠️ No deep link URL validation
- ⚠️ No unit tests exist yet

### Risk Level: **Low**
- No critical bugs identified
- Security concerns are minor (deep link validation)
- Performance impact minimal

### Action Items Before Production Release:
1. ✅ Code compiles and runs
2. ❌ Complete comeback notification database integration (TODO line 115)
3. ⚠️ Add deep link URL validation
4. ⚠️ Write unit tests for notification routing
5. ⚠️ Replace magic strings with enums

### Estimated Effort to Address All Issues: **16-24 hours**

---

## 11. Code Examples

### Recommended Refactor: Type-Safe Notification Categories

**Before** (current implementation):
```swift
switch category {
case "STREAK_WARNING":
    deepLink = "kubbcoach://home/start-session"
case "DAILY_CHALLENGE":
    deepLink = "kubbcoach://journey/daily-challenge"
// ...
}
```

**After** (recommended):
```swift
enum NotificationCategory: String, CaseIterable {
    case streakWarning = "STREAK_WARNING"
    case dailyChallenge = "DAILY_CHALLENGE"
    case comebackPrompt = "COMEBACK_PROMPT"
    case preCompetition = "PRE_COMPETITION"

    var deepLink: String {
        switch self {
        case .streakWarning, .comebackPrompt:
            return "kubbcoach://home/start-session"
        case .dailyChallenge:
            return "kubbcoach://journey/daily-challenge"
        case .preCompetition:
            return "kubbcoach://home/training-selection"
        }
    }
}

@MainActor
private func handleNotificationResponse(category: String, identifier: String) async {
    let deepLink: String

    if let notificationCategory = NotificationCategory(rawValue: category) {
        deepLink = notificationCategory.deepLink
        logger.info("Deep linking to \(deepLink) for category \(category)")
    } else {
        deepLink = "kubbcoach://home"
        logger.warning("Unknown notification category: \(category), using default")
    }

    NotificationCenter.default.post(
        name: .deepLinkReceived,
        object: nil,
        userInfo: [DeepLink.urlKey: deepLink]
    )
}

// Add to NotificationCenter extension
extension Notification.Name {
    static let deepLinkReceived = Notification.Name("HandleDeepLink")
}

enum DeepLink {
    static let urlKey = "url"
}
```

### Recommended Implementation: Comeback Notification Database Query

Replace TODO (lines 115-117) with:
```swift
@MainActor
private func checkForComebackNotifications() async {
    // Only check if notifications are authorized
    guard await NotificationService.shared.isAuthorized() else {
        logger.debug("Skipping comeback check - notifications not authorized")
        return
    }
    guard NotificationService.shared.isNotificationTypeEnabled(.comebackPrompt) else {
        logger.debug("Skipping comeback check - comeback prompts disabled")
        return
    }

    // Access TrainingSessionManager from environment
    guard let sessionManager = TrainingSessionManager.shared else {
        logger.error("Failed to access TrainingSessionManager")
        return
    }

    do {
        // Query most recent session
        let lastSession = try await sessionManager.getMostRecentSession()

        guard let lastSession else {
            // No sessions yet, don't schedule comeback notification
            logger.info("No previous sessions found, skipping comeback notification")
            return
        }

        // Calculate days since last activity
        let daysSinceLastSession = Calendar.current.dateComponents(
            [.day],
            from: lastSession.createdAt,
            to: Date()
        ).day ?? 0

        if daysSinceLastSession >= 7 {
            // Schedule comeback notification
            await NotificationService.shared.scheduleComebackNotification(daysSinceLastSession: daysSinceLastSession)
            logger.info("Scheduled comeback notification (inactive for \(daysSinceLastSession) days)")
        } else {
            logger.info("User active recently (\(daysSinceLastSession) days ago), no comeback needed")
        }
    } catch {
        logger.error("Failed to check for comeback notifications: \(error.localizedDescription)")
    }
}
```

**Note**: Requires adding `getMostRecentSession()` method to TrainingSessionManager:
```swift
// In TrainingSessionManager.swift
@MainActor
func getMostRecentSession() async throws -> TrainingSession? {
    let descriptor = FetchDescriptor<TrainingSession>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = 1

    return try modelContext.fetch(descriptor).first
}
```

---

## 12. Additional Notes

### Integration Checklist
When completing the comeback notification TODO:
- [ ] Add `getMostRecentSession()` to TrainingSessionManager
- [ ] Add `scheduleComebackNotification(daysSinceLastSession:)` to NotificationService
- [ ] Test with mock data (7+ days inactive)
- [ ] Verify notification doesn't fire for active users
- [ ] Add unit tests for comeback logic

### Documentation Gaps
- No inline documentation for deep link URL scheme format
- Missing documentation on expected SwiftUI observer setup
- Comeback notification cadence not documented (currently assuming 7 days)

### Future Enhancements
- Add support for notification actions (e.g., "Start Training" vs "Snooze")
- Track notification engagement metrics
- A/B test different comeback notification timing
- Add rich notifications with training stats preview

---

**Review completed**: 2026-03-25
**Reviewer**: Claude Code
**Confidence**: High (straightforward UIKit integration layer)
