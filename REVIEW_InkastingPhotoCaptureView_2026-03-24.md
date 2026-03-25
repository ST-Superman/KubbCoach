# Code Review: InkastingPhotoCaptureView.swift

**Date**: 2026-03-24
**Reviewer**: Claude Code
**File**: `Kubb Coach/Kubb Coach/Views/Inkasting/InkastingPhotoCaptureView.swift`
**Lines of Code**: 255
**Created**: 2/24/26

---

## 1. File Overview

### Purpose
A custom camera capture interface for the Inkasting training mode, allowing users to photograph kubbs for computer vision analysis. Provides both live camera capture and photo library selection.

### Key Responsibilities
- Display live camera preview with overlay instructions
- Capture photos using AVFoundation
- Allow photo library selection as alternative
- Handle image capture callbacks to parent view

### Dependencies
- **SwiftUI**: Primary UI framework
- **UIKit**: UIImagePickerController, UIViewController bridging
- **AVFoundation**: Camera capture (AVCaptureSession, AVCaptureDevice, AVCapturePhotoOutput)
- **OSLog**: Logging via AppLogger

### Integration Points
- Called from parent Inkasting training flow with `kubbCount` and `onCapture` callback
- Returns captured UIImage to parent via closure
- Parent controls dismissal (camera view does not self-dismiss)

---

## 2. Architecture Analysis

### Design Patterns Used
✅ **UIViewControllerRepresentable Pattern**: Clean bridging between SwiftUI and UIKit
✅ **Coordinator Pattern**: Used for UIImagePickerController delegation
✅ **Callback/Closure Pattern**: Parent communication via `onCapture`
✅ **Composition**: Three distinct components (SwiftUI shell, Camera controller, Image picker)

### SOLID Principles

**Single Responsibility Principle**: ⚠️ **Partial**
- `CameraViewController` handles both UI setup and camera logic
- Consider extracting camera session management to separate service

**Open/Closed Principle**: ✅ **Good**
- Extensible through callback pattern
- Could add new image sources without modifying existing code

**Liskov Substitution Principle**: ✅ **N/A**
- No inheritance hierarchy

**Interface Segregation Principle**: ✅ **Good**
- Simple, focused interfaces for each representable

**Dependency Inversion Principle**: ⚠️ **Partial**
- Tightly coupled to AVFoundation (not abstracted)
- Hard to test or swap implementations

### Code Organization
```
InkastingPhotoCaptureView (SwiftUI)
├── CameraViewControllerRepresentable
│   └── CameraViewController (UIKit)
│       └── AVCapturePhotoCaptureDelegate
└── ImagePickerRepresentable
    └── Coordinator (UIImagePickerControllerDelegate)
```

**Structure**: ✅ Logical, well-organized
**Separation of Concerns**: ✅ Good separation between SwiftUI and UIKit layers

---

## 3. Code Quality

### Strengths

1. **Clean SwiftUI/UIKit Bridging**
   - Proper use of UIViewControllerRepresentable
   - Good lifecycle management with Coordinator pattern

2. **Proper Error Handling**
   ```swift
   guard let camera = AVCaptureDevice.default(...) else { return }
   do {
       let input = try AVCaptureDeviceInput(device: camera)
       // ...
   } catch {
       AppLogger.inkasting.error("Error setting up camera: \(error)")
   }
   ```

3. **Background Threading**
   ```swift
   DispatchQueue.global(qos: .userInitiated).async {
       captureSession.startRunning()
   }
   ```
   ✅ Camera session starts on background thread (Apple best practice)

4. **Lifecycle Awareness**
   ```swift
   override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       captureSession?.stopRunning()
   }
   ```
   ✅ Properly stops camera when view disappears

5. **Guard Statement Usage**
   - Consistent use of `guard` for early returns
   - Clean optional handling

### Issues

#### 🔴 Critical: Missing Camera Permission Handling
```swift
private func setupCamera() {
    captureSession = AVCaptureSession()
    // ❌ No AVCaptureDevice.authorizationStatus check!
```

**Problem**: App will crash or fail silently if user denies camera permission.

**Recommended Fix**:
```swift
private func setupCamera() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        configureCaptureSession()
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                DispatchQueue.main.async {
                    self.configureCaptureSession()
                }
            }
        }
    case .denied, .restricted:
        // Show error UI
        showPermissionDeniedAlert()
    @unknown default:
        break
    }
}
```

#### 🟡 Medium: No Error UI Feedback
When camera setup fails, errors are logged but user sees nothing:
```swift
guard let camera = AVCaptureDevice.default(...) else {
    return // ❌ Silent failure - user sees blank screen
}
```

**Recommendation**: Add error state UI with helpful message

#### 🟡 Medium: Potential Memory Leak
```swift
class CameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)? // ⚠️ Strong reference to closure
```

**Issue**: If closure captures `self` in parent, could create retain cycle.

**Recommended Fix**: Document that closure should use `[weak self]` or make it explicitly `weak`:
```swift
// Add documentation
/// - Note: Ensure closure uses [weak self] if capturing parent view
var onCapture: ((UIImage) -> Void)?
```

#### 🟢 Minor: Unused State Variable
```swift
@State private var sourceType: UIImagePickerController.SourceType = .camera
```
Only used for `.photoLibrary`, never for `.camera`. The camera is always shown via `CameraViewControllerRepresentable`.

#### 🟢 Minor: No Loading State
Camera initialization can take 1-2 seconds. User sees blank screen during setup.

**Recommendation**: Add loading indicator:
```swift
@State private var isCameraReady = false

VStack {
    if isCameraReady {
        // Show camera UI
    } else {
        ProgressView("Initializing camera...")
    }
}
```

---

## 4. Performance Considerations

### Strengths
✅ **Background Threading**: Camera session starts on background queue
✅ **Session Lifecycle**: Stops running when view disappears
✅ **Photo Preset**: Uses `.photo` preset (optimized for still images)

### Potential Issues

1. **Layout Thrashing** (Minor)
   ```swift
   override func viewDidLayoutSubviews() {
       previewLayer?.frame = view.bounds
   }
   ```
   Called frequently during animations. Consider caching bounds if performance issue arises.

2. **No Image Compression**
   ```swift
   guard let imageData = photo.fileDataRepresentation() else { return }
   ```
   Full-resolution image passed to parent. For vision processing, might want to resize:
   ```swift
   let resizedImage = image.resized(to: CGSize(width: 1024, height: 1024))
   ```

3. **Capture Session Cleanup** (Medium Priority)
   If SwiftUI view is dismissed programmatically, `viewWillDisappear` might not be called.

   **Recommendation**: Add explicit cleanup in `deinit`:
   ```swift
   deinit {
       captureSession?.stopRunning()
       captureSession = nil
   }
   ```

---

## 5. Security & Data Safety

### Current State
⚠️ **Incomplete** - Missing critical permission handling

### Issues

1. **No Permission Checking** (Critical)
   - Camera access not verified before use
   - Could trigger App Store rejection if Info.plist missing `NSCameraUsageDescription`

   **Checklist**:
   - [ ] Verify `Info.plist` contains `NSCameraUsageDescription`
   - [ ] Verify `Info.plist` contains `NSPhotoLibraryUsageDescription`
   - [ ] Add runtime permission checks

2. **No Image Validation** (Low Priority)
   - Captured image not validated before processing
   - Large images could cause memory issues

   **Recommendation**: Add basic validation:
   ```swift
   func validateImage(_ image: UIImage) -> Bool {
       guard let cgImage = image.cgImage else { return false }
       let megapixels = (cgImage.width * cgImage.height) / 1_000_000
       return megapixels <= 12 // Reasonable limit
   }
   ```

### Privacy Considerations
✅ **Good**: No image data stored or transmitted without user action
✅ **Good**: Camera stops when view disappears
⚠️ **Missing**: No privacy policy reference in UI

---

## 6. Testing Considerations

### Current Testability: ⚠️ **Limited**

**Challenges**:
1. **Tight Coupling to AVFoundation**: Can't test camera logic without real device
2. **UIKit Dependencies**: Requires UIViewController infrastructure
3. **No Dependency Injection**: Camera device hardcoded

### Missing Test Coverage

1. **Permission Handling** (not implemented yet)
2. **Error States**: Camera unavailable, no photos available
3. **Image Capture Flow**: Callback execution
4. **Lifecycle**: Session start/stop
5. **UI State**: Button interactions

### Recommended Test Strategy

#### Unit Tests (via Mock Camera Service)
```swift
protocol CameraServiceProtocol {
    func startSession()
    func stopSession()
    func capturePhoto(completion: @escaping (UIImage?, Error?) -> Void)
}

class MockCameraService: CameraServiceProtocol {
    var shouldSucceed = true
    var mockImage: UIImage?

    func capturePhoto(completion: @escaping (UIImage?, Error?) -> Void) {
        if shouldSucceed {
            completion(mockImage ?? UIImage(), nil)
        } else {
            completion(nil, NSError(domain: "test", code: -1))
        }
    }
}
```

#### UI Tests
- Test photo library picker flow (can be tested in simulator)
- Test dismiss button functionality
- Test instruction text displays correct kubb count

#### Manual Testing Checklist
- [ ] Camera preview displays on physical device
- [ ] Capture button takes photo
- [ ] Photo library button opens picker
- [ ] Close button dismisses view
- [ ] Camera stops when view dismissed
- [ ] Works on iPhone with front camera
- [ ] Works on iPad

---

## 7. Issues Found

### Critical 🔴

1. **Missing Camera Permission Handling**
   - **Location**: Line 116 (`setupCamera()`)
   - **Impact**: App crash or blank screen on first launch
   - **Fix Priority**: High
   - **Effort**: 30 minutes

### High Priority 🟠

2. **No Error UI Feedback**
   - **Location**: Lines 123-125, 151-153
   - **Impact**: Poor UX when camera fails
   - **Fix Priority**: High
   - **Effort**: 1 hour

3. **Incomplete Capture Session Lifecycle**
   - **Location**: Class `CameraViewController`
   - **Impact**: Potential battery drain, session not stopped on SwiftUI dismissal
   - **Fix Priority**: Medium-High
   - **Effort**: 15 minutes

### Medium Priority 🟡

4. **No Loading State During Camera Init**
   - **Location**: Lines 21-78
   - **Impact**: Blank screen for 1-2 seconds
   - **Fix Priority**: Medium
   - **Effort**: 30 minutes

5. **Potential Memory Leak with Closure**
   - **Location**: Line 98
   - **Impact**: Possible retain cycle
   - **Fix Priority**: Medium
   - **Effort**: 10 minutes (documentation) or 30 minutes (weak reference wrapper)

6. **No Image Size Validation**
   - **Location**: Line 204
   - **Impact**: Potential memory pressure with large images
   - **Fix Priority**: Low-Medium
   - **Effort**: 20 minutes

### Low Priority 🟢

7. **Unused State Variable**
   - **Location**: Line 16 (`sourceType`)
   - **Impact**: Code clarity
   - **Fix Priority**: Low
   - **Effort**: 5 minutes

8. **No Orientation Support**
   - **Location**: Camera capture
   - **Impact**: Photos may be rotated incorrectly
   - **Fix Priority**: Low (depends on Vision API handling)
   - **Effort**: 1 hour

---

## 8. Recommendations

### Immediate Actions (Before Production)

1. **Add Camera Permission Flow** ✅ Critical
   ```swift
   @State private var permissionState: CameraPermission = .notDetermined

   enum CameraPermission {
       case notDetermined, granted, denied
   }
   ```

2. **Add Error Handling UI** ✅ Critical
   - Show alert when camera unavailable
   - Provide "Open Settings" button for denied permissions
   - Graceful fallback to photo library only

3. **Add Cleanup in deinit** ✅ Important
   ```swift
   deinit {
       captureSession?.stopRunning()
   }
   ```

### High-Priority Improvements

4. **Add Loading State**
   ```swift
   @State private var isCameraReady = false

   // Update after session starts
   DispatchQueue.main.async {
       self.isCameraReady = true
   }
   ```

5. **Extract Camera Logic to Service**
   ```swift
   class CameraService: ObservableObject {
       @Published var previewLayer: AVCaptureVideoPreviewLayer?
       @Published var error: CameraError?

       func startSession() { }
       func capturePhoto(completion: @escaping (UIImage?) -> Void) { }
   }
   ```
   Benefits: Testable, reusable, cleaner separation

6. **Add Image Validation**
   - Check image size before passing to parent
   - Resize if needed for vision processing
   - Validate image is not corrupt

### Medium-Priority Enhancements

7. **Consider PhotosPicker for iOS 16+**
   ```swift
   import PhotosUI

   PhotosPicker(selection: $selectedItem, matching: .images) {
       Label("Photo Library", systemImage: "photo.on.rectangle")
   }
   ```
   Benefits: Modern API, better permissions handling, SwiftUI native

8. **Add Capture Feedback**
   - Flash animation on capture
   - Haptic feedback
   - Thumbnail preview of captured image

9. **Add Orientation Support**
   - Read device orientation
   - Set photo output orientation
   - Ensure images always upright

### Nice-to-Have Features

10. **Flash Control** (if needed for low-light)
11. **Focus/Exposure Tap-to-Set**
12. **Zoom Pinch Gesture**
13. **Grid Overlay** (rule of thirds for better framing)

---

## 9. Compliance Checklist

### iOS Best Practices
- [x] Uses modern SwiftUI patterns
- [ ] **Missing**: Camera permission handling (Privacy requirement)
- [x] Follows Apple HIG for camera UI
- [ ] **Incomplete**: Error state handling
- [x] Background threading for heavy operations
- [ ] **Missing**: Accessibility labels for buttons

### SwiftData Patterns
- [x] N/A - No SwiftData usage in this file

### CloudKit Guidelines
- [x] N/A - No CloudKit usage in this file

### AVFoundation Best Practices
- [x] Uses background queue for session start
- [x] Stops session on viewWillDisappear
- [ ] **Missing**: Permission checks
- [x] Uses .photo preset for still images
- [ ] **Missing**: Error recovery mechanisms

### Accessibility
- [ ] **Missing**: Accessibility labels on buttons
  ```swift
  .accessibilityLabel("Open photo library")
  .accessibilityHint("Select a photo of kubbs from your library")
  ```
- [ ] **Missing**: VoiceOver support for camera capture
- [ ] **Missing**: Dynamic Type support (uses fixed `.title` font)

### App Store Guidelines
- [ ] **Critical**: Verify `Info.plist` contains required permission descriptions
  - `NSCameraUsageDescription`: "Required to photograph kubbs for training analysis"
  - `NSPhotoLibraryUsageDescription`: "Select photos of kubbs for training analysis"
- [ ] **Recommended**: Add error handling to avoid negative reviews

---

## 10. Code Examples

### Recommended Permission Handling

```swift
struct InkastingPhotoCaptureView: View {
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var showPermissionAlert = false

    var body: some View {
        Group {
            switch cameraPermission {
            case .authorized:
                cameraView
            case .denied, .restricted:
                permissionDeniedView
            case .notDetermined:
                ProgressView("Checking permissions...")
                    .onAppear {
                        checkPermissions()
                    }
            @unknown default:
                permissionDeniedView
            }
        }
    }

    private func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        } else {
            cameraPermission = status
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.headline)

            Text("Please enable camera access in Settings to photograph kubbs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Use Photo Library Instead") {
                sourceType = .photoLibrary
                showImagePicker = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var cameraView: some View {
        // Existing camera UI
    }
}
```

### Recommended Error Handling

```swift
class CameraViewController: UIViewController {
    private var errorLabel: UILabel?

    private func setupCamera() {
        do {
            try configureCaptureSession()
        } catch {
            showError("Camera unavailable: \(error.localizedDescription)")
        }
    }

    private func configureCaptureSession() throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back) else {
            throw CameraError.deviceUnavailable
        }

        // ... rest of setup
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        errorLabel = label
    }
}

enum CameraError: Error {
    case deviceUnavailable
    case sessionConfigurationFailed
}
```

---

## Summary

### Overall Assessment: ⚠️ **Good Foundation, Needs Production Hardening**

**Strengths**:
- Clean architecture with good SwiftUI/UIKit separation
- Proper threading and lifecycle management
- Well-organized code structure
- Good logging for debugging

**Critical Gaps**:
- Missing camera permission handling (App Store rejection risk)
- No error UI feedback (poor UX)
- Incomplete testing strategy

**Recommendation**: **DO NOT SHIP without addressing critical issues**. Add permission handling and error UI before production release.

### Effort Estimate for Production-Ready
- **Critical fixes**: 2-3 hours
- **High-priority improvements**: 3-4 hours
- **Testing**: 2-3 hours
- **Total**: ~8-10 hours

### Risk Level: 🟡 MEDIUM
- Low risk for data loss/corruption
- Medium risk for user experience (permission denial, errors)
- Medium risk for App Store rejection (missing permission handling)

---

## Action Items

### Before Next Release
1. [ ] Add camera permission checking and UI
2. [ ] Add error state handling and user feedback
3. [ ] Add `deinit` cleanup for capture session
4. [ ] Verify Info.plist contains required permission keys
5. [ ] Add accessibility labels to all buttons

### Future Enhancements
6. [ ] Extract camera logic to testable service
7. [ ] Add loading state during initialization
8. [ ] Add image size validation/compression
9. [ ] Consider PhotosPicker migration for iOS 16+
10. [ ] Add orientation handling if needed

---

**Review completed**: 2026-03-24
**Reviewed by**: Claude Code
**Next review recommended**: After implementing critical fixes
