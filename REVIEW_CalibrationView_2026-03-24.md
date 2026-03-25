# Code Review: CalibrationView.swift

**File**: `Kubb Coach/Kubb Coach/Views/Inkasting/CalibrationView.swift`
**Review Date**: 2026-03-24
**Reviewer**: Claude Code
**Lines of Code**: 293

---

## 1. File Overview

### Purpose
`CalibrationView` is a SwiftUI view that guides users through the camera calibration process for the inkasting feature. It allows users to photograph two kubbs at a known distance apart and mark their positions to calculate a pixels-per-meter calibration factor for accurate distance measurements in future inkasting sessions.

### Key Responsibilities
- Capture calibration photo via camera
- Guide user through two-kubb placement instructions
- Allow user to tap and mark kubb positions on the captured image
- Convert between screen and image coordinate systems
- Calculate calibration factor using `CalibrationService`
- Save calibration to SwiftData persistence layer
- Handle errors with user-friendly messages

### Key Dependencies
- **SwiftUI**: UI framework
- **OSLog**: Logging (via `AppLogger.inkasting`)
- **CalibrationService**: Business logic for calibration calculations and persistence
- **CalibrationError**: Custom error types
- **InkastingPhotoCaptureView**: Custom camera view
- **ImagePickerRepresentable**: Photo library picker (currently unused but available)
- **KubbColors**: App color constants

### Integration Points
- Called by parent views when user initiates inkasting calibration
- Provides `onComplete` callback with calibration factor
- Uses shared `ModelContext` from environment
- Integrates with `CalibrationService` for validation and persistence

---

## 2. Architecture Analysis

### Design Patterns

**MVVM Pattern**
- ✅ **View**: CalibrationView handles UI and user interaction
- ✅ **Model**: CalibrationSettings persisted via SwiftData
- ✅ **Service Layer**: CalibrationService handles business logic
- Clean separation between presentation and business logic

**State Management**
- Uses `@State` for local UI state (positions, images, errors)
- Uses `@Environment` for shared dependencies (ModelContext, dismiss)
- Unidirectional data flow with clear state transitions

**Coordinator Pattern**
- Uses completion handler (`onComplete`) to communicate results to parent
- Properly dismisses itself after successful calibration
- Clean delegation pattern

### SOLID Principles

**Single Responsibility** ✅
- View focuses solely on UI and coordinate transformation
- Delegates calculation logic to `CalibrationService`
- Clear separation of concerns

**Open/Closed** ✅
- Coordinate transformation logic is self-contained
- Could be extended with different calibration methods without modification

**Liskov Substitution** ✅
- Standard SwiftUI View conformance
- No inheritance concerns

**Interface Segregation** ✅
- Simple, focused callback interface (`onComplete: (Double) -> Void`)
- Uses standard SwiftUI environment values

**Dependency Inversion** ✅
- Depends on `CalibrationService` abstraction
- Uses protocol-based ModelContext from environment

### Code Organization

**Structure**: Well-organized with clear sections
- Public interface (body)
- Private views (instructionsView, positionMarkerView)
- Private helper methods (coordinate transformations, tap handling, save logic)

**Complexity**: Moderate
- Main view logic is straightforward
- Coordinate transformation math is well-isolated
- positionMarkerView is complex (90 lines) but cohesive

---

## 3. Code Quality

### SwiftUI Best Practices

✅ **Proper State Management**
```swift
@State private var capturedImage: UIImage?
@State private var kubb1Position: CGPoint?
@State private var kubb2Position: CGPoint?
```
- All mutable state properly marked with `@State`
- Private access prevents external mutation

✅ **Environment Usage**
```swift
@Environment(\.modelContext) private var modelContext
@Environment(\.dismiss) private var dismiss
```
- Correctly uses environment for shared dependencies

✅ **View Composition**
- Well-decomposed into `instructionsView` and `positionMarkerView`
- Logical separation of concerns

✅ **Conditional Rendering**
```swift
if let image = capturedImage {
    positionMarkerView(image: image)
} else {
    instructionsView
}
```
- Clean state-based navigation

### Error Handling

✅ **Comprehensive Error Handling**
```swift
do {
    let calibration = try service.calculateCalibration(...)
    // ...
} catch let error as CalibrationError {
    errorMessage = error.errorDescription
    showingError = true
} catch {
    errorMessage = "Failed to calculate calibration: \(error.localizedDescription)"
    showingError = true
}
```
- Handles both specific `CalibrationError` types and general errors
- User-friendly error messages via alert
- Allows retry by resetting positions

✅ **Guard Statements**
```swift
guard let pos1 = kubb1Position, let pos2 = kubb2Position else { return }
```
- Proper optional unwrapping

### Async/Await & Threading

✅ **MainActor Usage**
```swift
Task { @MainActor in
    do {
        try service.saveCalibration(calibration, modelContext: modelContext)
        onComplete(calibration)
        dismiss()
    } catch {
        errorMessage = "Failed to save calibration: \(error.localizedDescription)"
        showingError = true
    }
}
```
- **Excellent**: Ensures ModelContext operations happen on main thread
- Proper async handling for persistence operations
- Follows SwiftData threading requirements

### Optionals Management

✅ **Safe Optional Handling**
- Uses optional binding (`if let`) appropriately
- Uses optional chaining where appropriate
- No force-unwrapping (`!`) found
- Good use of nil-coalescing in alert: `errorMessage ?? "An unknown error occurred"`

### Memory Management

✅ **No Retain Cycles Detected**
- Closures capture `self` implicitly (safe in SwiftUI views)
- No `@escaping` closures that could create cycles
- `@State` properties properly managed by SwiftUI

⚠️ **Image Memory Consideration**
- `UIImage` stored in `@State` could be large
- Not a critical issue for single calibration image
- Consider releasing image after calibration completes

### Logging

✅ **Comprehensive Debug Logging**
```swift
AppLogger.inkasting.debug("Tap detected at: \(value.location.debugDescription)")
AppLogger.inkasting.debug("Container size: \(containerSize.debugDescription)")
AppLogger.inkasting.debug("Image size: \(imageSize.debugDescription)")
// etc.
```
- Excellent debugging support for coordinate transformations
- Uses structured logging via OSLog
- Debug-level logging (won't spam production logs)

---

## 4. Performance Considerations

### Potential Bottlenecks

⚠️ **Canvas Redrawing**
```swift
Canvas { context, size in
    if let pos1 = kubb1Position {
        // Draw markers
    }
}
```
- Canvas redraws on every state change
- Not a significant concern for two simple markers
- Could optimize with `Canvas(rendersAsynchronously: true)` if needed

✅ **Image Loading**
- Image loaded once and cached in `@State`
- No redundant image processing
- `.aspectRatio(contentMode: .fit)` is efficient

✅ **Coordinate Calculations**
- Coordinate transformations are O(1)
- No expensive operations in hot paths
- Calculations only triggered on tap and draw

### UI Rendering Efficiency

✅ **View Updates**
- Minimal view hierarchy
- Conditional rendering prevents unnecessary views
- No observed performance issues

✅ **Geometry Reader**
```swift
GeometryReader { geometry in
    // ...
}
.frame(maxHeight: 500)
```
- Properly constrained with `maxHeight`
- Prevents excessive layout calculations

---

## 5. Security & Data Safety

### Input Validation

✅ **Delegate to Service Layer**
- All validation happens in `CalibrationService`
- Checks for invalid distances, unreasonable calibration values
- Points-too-close validation

✅ **Distance Input Validation**
```swift
Stepper("Distance: \(Int(distance))m", value: $distance, in: 1...3, step: 1)
```
- UI enforces valid range (1-3 meters)
- No way to input invalid values

### Data Sanitization

✅ **Coordinate Bounds**
- Coordinate transformations naturally bounded by image dimensions
- No risk of out-of-bounds access

⚠️ **Image Source**
- Currently only camera input (via `InkastingPhotoCaptureView`)
- Photo library option exists but not exposed in UI
- No validation on image source or content

### Privacy Considerations

✅ **Camera Access**
- Uses system camera view
- No unauthorized image capture
- Image only stored locally for calibration reference

✅ **Data Persistence**
- Calibration stored in local SwiftData
- No external data transmission
- Image data optional in persistence

---

## 6. Testing Considerations

### Testability Assessment

✅ **Service Layer Testable**
- Business logic isolated in `CalibrationService`
- Tests exist: `CalibrationServiceTests.swift`
- Pure functions for calculations

⚠️ **View Logic Testing**
- Coordinate transformation logic embedded in view
- Difficult to unit test without SwiftUI test harness
- Consider extracting to separate utility class

**Recommendation**: Extract coordinate transformation logic
```swift
// Proposed refactoring
struct CoordinateTransformer {
    func screenToImageCoordinates(_ point: CGPoint,
                                   containerSize: CGSize,
                                   imageSize: CGSize) -> CGPoint { ... }

    func imageToScreenCoordinates(_ point: CGPoint,
                                   containerSize: CGSize,
                                   imageSize: CGSize) -> CGPoint { ... }
}
```

### Missing Test Coverage

📝 **Coordinate Transformation Tests**
- Test aspect ratio edge cases (square, ultra-wide, tall images)
- Test coordinate roundtrip accuracy
- Test edge/corner tap positions
- Test zero-sized containers

📝 **UI State Tests**
- Test state transitions (no markers → marker 1 → marker 2 → reset)
- Test error state handling
- Test image capture flow

📝 **Integration Tests**
- Test full calibration flow (camera → mark → save)
- Test error recovery flows
- Test dismiss behavior

### Recommended Test Cases

```swift
// Unit tests for coordinate transformations
func testScreenToImageCoordinates_WideImage()
func testScreenToImageCoordinates_TallImage()
func testScreenToImageCoordinates_SquareImage()
func testCoordinateRoundtrip()
func testTapOutsideImageBounds()

// UI tests (SwiftUI preview or UI test target)
func testMarkerPlacementSequence()
func testMarkerReset()
func testCalibrationCompletion()
func testErrorAlertAppearance()
```

---

## 7. Issues Found

### Critical Issues
**None found** ✅

### Potential Bugs

⚠️ **Issue 1: Tap Outside Image Bounds**
- **Location**: Lines 185-206 (`handleTap`)
- **Description**: User can tap outside the displayed image area in the GeometryReader container. The `screenToImageCoordinates` function will convert this to image coordinates, but they may be outside the actual image bounds (negative or beyond image dimensions).
- **Impact**: Could result in invalid calibration points
- **Recommendation**: Add bounds checking:
```swift
private func handleTap(at location: CGPoint, containerSize: CGSize, imageSize: CGSize) {
    let imagePosition = screenToImageCoordinates(location, containerSize: containerSize, imageSize: imageSize)

    // Validate position is within image bounds
    guard imagePosition.x >= 0 && imagePosition.x <= imageSize.width &&
          imagePosition.y >= 0 && imagePosition.y <= imageSize.height else {
        AppLogger.inkasting.debug("Tap outside image bounds: \(imagePosition.debugDescription)")
        return
    }

    // ... rest of method
}
```

⚠️ **Issue 2: Division by Zero Risk**
- **Location**: Lines 209-231, 234-259 (coordinate transformations)
- **Description**: If `imageSize.height` or `containerSize.height` is 0, division will result in NaN/Infinity
- **Impact**: Crashes or invalid calculations
- **Likelihood**: Very low (SwiftUI generally provides valid sizes)
- **Recommendation**: Add defensive guards:
```swift
guard imageSize.width > 0 && imageSize.height > 0 &&
      containerSize.width > 0 && containerSize.height > 0 else {
    return CGPoint.zero // or appropriate fallback
}
```

### Code Smells

⚠️ **Smell 1: Long Method**
- **Location**: Lines 94-183 (`positionMarkerView`)
- **Description**: 90-line method doing multiple things (instruction text, image display, canvas drawing, gesture handling, button, toolbar)
- **Recommendation**: Extract sub-views:
```swift
private func positionMarkerView(image: UIImage) -> some View {
    VStack {
        markerInstructionText
        imageWithMarkersView(image: image)
        if bothMarkersPlaced {
            completeButton
        }
    }
    .toolbar { retakeButton }
    .alert("Calibration Error", isPresented: $showingError) { ... }
}
```

⚠️ **Smell 2: Magic Numbers**
- **Location**: Lines 124, 130 (marker drawing)
- **Description**: Hardcoded values `15`, `30` for marker size
- **Recommendation**: Extract to constants:
```swift
private enum MarkerConstants {
    static let radius: CGFloat = 15
    static let diameter: CGFloat = 30
    static let strokeWidth: CGFloat = 2
    static let opacity: Double = 0.7
}
```

⚠️ **Smell 3: Code Duplication**
- **Location**: Lines 209-231 and 234-259
- **Description**: Similar aspect ratio calculation logic in both coordinate transformation methods
- **Recommendation**: Extract shared logic:
```swift
private struct ImageLayout {
    let displayedSize: CGSize
    let offset: CGPoint

    init(imageSize: CGSize, containerSize: CGSize) {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            displayedSize = CGSize(width: containerSize.width,
                                   height: containerSize.width / imageAspect)
            offset = CGPoint(x: 0, y: (containerSize.height - displayedSize.height) / 2)
        } else {
            displayedSize = CGSize(width: containerSize.height * imageAspect,
                                   height: containerSize.height)
            offset = CGPoint(x: (containerSize.width - displayedSize.width) / 2, y: 0)
        }
    }
}
```

⚠️ **Smell 4: Unused Feature**
- **Location**: Lines 16, 80-84
- **Description**: `showingImagePicker` state and sheet defined but never triggered
- **Recommendation**: Either remove if not needed, or add UI button to trigger photo library picker

### Technical Debt

📝 **Localization**
- **Location**: Lines 38-49 (instructions text)
- **Description**: Long instruction strings not localized
- **Recommendation**: Extract to `Localizable.strings`:
```swift
Text("calibration.instructions.step1", comment: "Place kubbs apart")
Text("calibration.instructions.step2", comment: "Set up tripod")
// etc.
```

📝 **Accessibility**
- **Location**: Throughout view
- **Description**: No accessibility labels for image, markers, or gestures
- **Recommendation**: Add accessibility support:
```swift
Image(uiImage: image)
    .resizable()
    .accessibilityLabel("Calibration reference photo")
    .accessibilityHint("Tap to mark kubb positions")
```

---

## 8. Recommendations

### High Priority

🔴 **P0: Add Bounds Checking for Tap Positions**
- **Rationale**: Prevents invalid calibration data from out-of-bounds taps
- **Effort**: Low (5 minutes)
- **Impact**: High (data integrity)

🔴 **P0: Add Defensive Guards for Division**
- **Rationale**: Prevents potential crashes from zero-sized geometries
- **Effort**: Low (5 minutes)
- **Impact**: High (app stability)

### Medium Priority

🟡 **P1: Extract Coordinate Transformation Logic**
- **Rationale**: Improves testability, reusability
- **Effort**: Medium (30 minutes)
- **Impact**: Medium (code quality, maintainability)
- **Benefit**: Enable unit testing of coordinate math

🟡 **P1: Break Down positionMarkerView**
- **Rationale**: Improves readability, reduces cognitive load
- **Effort**: Medium (45 minutes)
- **Impact**: Medium (maintainability)

🟡 **P1: Extract Magic Numbers to Constants**
- **Rationale**: Improves maintainability, makes design intent clear
- **Effort**: Low (10 minutes)
- **Impact**: Low (code clarity)

### Low Priority (Nice to Have)

🟢 **P2: Add Localization Support**
- **Rationale**: Future internationalization
- **Effort**: Medium (1 hour for full app)
- **Impact**: Low (unless planning international release)

🟢 **P2: Add Accessibility Labels**
- **Rationale**: Better user experience for VoiceOver users
- **Effort**: Medium (30 minutes)
- **Impact**: Medium (accessibility compliance)

🟢 **P2: Remove Unused showingImagePicker**
- **Rationale**: Code cleanliness
- **Effort**: Low (2 minutes)
- **Impact**: Low (minor tech debt)

🟢 **P2: Add Haptic Feedback**
- **Rationale**: Better UX when tapping to place markers
- **Effort**: Low (10 minutes)
- **Impact**: Low (user experience polish)
```swift
private func handleTap(...) {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    // ... existing logic
}
```

### Future Enhancements

💡 **Feature: Zoom/Pan Support**
- Allow users to zoom into image for precise marker placement
- Particularly useful for distant kubbs or low-resolution images

💡 **Feature: Undo Individual Markers**
- Add separate "Undo Last" button instead of tapping to reset
- More intuitive UX

💡 **Feature: Visual Feedback**
- Show distance in pixels between markers while placing
- Show calculated calibration factor before completing

💡 **Feature: Reference Grid Overlay**
- Overlay grid or measurement guides to help with placement accuracy

---

## 9. Compliance Checklist

### iOS Best Practices

✅ **SwiftUI Patterns**
- Proper use of `@State`, `@Environment`
- View composition and decomposition
- Conditional rendering

✅ **System Integration**
- Camera access via standard system UI
- Photo library integration available
- Proper dismiss behavior

⚠️ **Accessibility**
- Missing VoiceOver labels
- No accessibility hints
- Gesture accessibility not addressed

✅ **Error Handling**
- User-friendly error messages
- Proper error recovery flows
- Alert-based error presentation

### SwiftData Patterns

✅ **ModelContext Usage**
- Accessed via `@Environment`
- Operations properly wrapped in `@MainActor`
- No off-main-thread access

✅ **Persistence**
- Delegates to service layer
- Proper error handling
- No direct ModelContext manipulation in view

### CloudKit Guidelines

✅ **N/A for this view**
- Calibration is local-only data
- No CloudKit sync required

### Accessibility Considerations

⚠️ **VoiceOver Support**: Missing
- Image needs accessibility label
- Markers need description
- Tap gesture needs accessibility action

⚠️ **Dynamic Type**: Partial
- Uses standard SwiftUI fonts (will scale)
- Layout may need adjustment for large text sizes

✅ **Color Contrast**: Good
- Blue and green markers on photo
- White stroke provides contrast

### App Store Guidelines

✅ **Camera Usage**
- Needs `NSCameraUsageDescription` in Info.plist (assumed present)
- User consent required (handled by system)

✅ **Photo Library**
- Needs `NSPhotoLibraryUsageDescription` if enabled (currently unused)

✅ **User Experience**
- Clear instructions
- Error handling
- Cancel/dismiss options

---

## 10. Summary

### Overall Assessment

**Quality Rating**: ⭐⭐⭐⭐ (4/5 stars)

`CalibrationView.swift` is a **well-implemented SwiftUI view** with solid architecture, proper error handling, and good separation of concerns. The coordinate transformation logic is mathematically sound and the integration with `CalibrationService` follows best practices.

### Strengths

1. ✅ **Excellent threading safety** - Proper `@MainActor` usage for ModelContext
2. ✅ **Clean architecture** - MVVM with service layer separation
3. ✅ **Comprehensive error handling** - User-friendly messages and recovery
4. ✅ **Good logging** - Debug logging for coordinate transformations
5. ✅ **No force-unwrapping** - Safe optional handling throughout
6. ✅ **Clear user guidance** - Step-by-step instructions

### Weaknesses

1. ⚠️ **Missing bounds checking** - Taps outside image not validated
2. ⚠️ **Coordinate transformation not unit testable** - Logic embedded in view
3. ⚠️ **Long method** - `positionMarkerView` does too much
4. ⚠️ **Missing accessibility** - No VoiceOver support
5. ⚠️ **Code duplication** - Similar logic in coordinate transformations

### Recommended Actions (Priority Order)

1. **Add bounds checking** to tap handler (5 min, prevents bugs)
2. **Add defensive guards** for zero-sized geometries (5 min, prevents crashes)
3. **Extract coordinate transformation** to testable utility (30 min, enables testing)
4. **Refactor long method** into smaller views (45 min, improves maintainability)
5. **Add accessibility labels** (30 min, compliance)

### Test Coverage Status

- ✅ Service layer tested (`CalibrationServiceTests.swift`)
- ⚠️ View logic not tested (coordinate transformations)
- ❌ UI flow not tested

### Suitable for Production?

**Yes, with minor fixes**. The view is functional and safe for production use. The recommended P0 fixes (bounds checking and defensive guards) should be implemented before release to prevent edge case issues. The view would benefit from accessibility improvements for App Store compliance.

---

**Review Complete** ✅

Generated by Claude Code on 2026-03-24
