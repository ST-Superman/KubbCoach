# Kubb Coach - iOS Development Guide

This document provides workflows and guidelines for working on the Kubb Coach iOS app with Claude Code.

## Project Overview

**Type**: Native iOS + watchOS fitness/training app
**Stack**: SwiftUI, SwiftData, CloudKit
**Targets**: iOS 17.0+, watchOS 10.0+, Widget Extension
**Architecture**: MVVM with Services layer

**Key Features**:
- Cross-device sync (iPhone ↔ Apple Watch via CloudKit)
- Training session tracking (8m, 4m, Inkasting modes)
- Personal bests, goals, milestones, and statistics
- Vision-based inkasting analysis
- Widget extension for quick stats

---

## Common iOS Development Workflows

### Default Build Behavior

**IMPORTANT**: Unless otherwise specified, all build requests should use **"Build + Install"** mode. This means:
- Build the app
- Install to device/simulator
- User launches manually when ready
- Use Console.app or Xcode for viewing logs

**Why this is the default:**
- Fast command-line builds
- Reliable installation without debugger dependencies
- User controls when to launch and test
- Logs available via Console.app (Applications/Utilities/Console.app)

**Alternative workflows** (if explicitly requested):
- "build and launch with logs" - Attempts ios-deploy debug session
- "just build, don't install" - Build only, no installation

### 1. Building the App

#### Build for iPhone Simulator (DEFAULT: Build + Install)
```bash
# Default: Build and install to simulator
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  clean build
```

**Optional: Launch with logs** (if explicitly requested):
```bash
# Build, then launch with console output
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  clean build && \
xcrun simctl launch --console booted com.sathomps.kubbcoach
```

#### Build for iPhone 15 Pro Simulator
```bash
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build
```

#### Build for Generic iOS Device (No Code Signing)
```bash
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'generic/platform=iOS' \
  build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

#### Build for Physical iPhone (Connected via USB)

**DEFAULT: Build + Install**
```bash
# Build and install to physical device
cd "Kubb Coach" && \
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'platform=iOS,name=Scott - personal' clean build
```

**To view logs after manual launch:**
- Open **Console.app** (Applications/Utilities/Console.app)
- Select "Scott - personal" in sidebar
- Filter for "Kubb Coach"
- Launch app on iPhone to see live logs

**Alternative: Build + Install Only (don't install, just compile)**
```bash
# First, list connected devices to find your device name
xcrun xctrace list devices
# or: instruments -s devices

# Build and install to specific device
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'platform=iOS,name=YOUR_DEVICE_NAME' \
  clean build

# Example for device named "Scott - personal"
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'platform=iOS,name=Scott - personal' \
  clean build
```

**Option B: Build + Launch + Debug (Advanced - requires developer disk images)**
```bash
# 1. Build the app first
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'platform=iOS,name=Scott - personal' \
  clean build

# 2. Find the built .app bundle
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Debug-iphoneos/Kubb Coach.app" -type d | grep -v "Index.noindex" | head -1)

# 3. Launch with ios-deploy (auto-launches and streams logs)
ios-deploy --bundle "$APP_PATH" --debug --justlaunch
```

**Option C: Advanced Debug Launch (may fail without developer disk images)**
```bash
# Build, install, launch, and stream console logs in one command
cd "Kubb Coach" && \
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach" \
  -destination 'platform=iOS,name=Scott - personal' clean build && \
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Debug-iphoneos/Kubb Coach.app" -type d | grep -v "Index.noindex" | head -1) && \
ios-deploy --bundle "$APP_PATH" --debug --justlaunch
```

**ios-deploy Options**:
- `--debug` - Attach debugger and show console output
- `--justlaunch` - Launch the app and exit (keeps logs streaming)
- `--noninteractive` - Don't wait for user input
- `--noinstall` - Launch without reinstalling (faster for testing)

**Requirements for Physical Device Builds**:
- Device connected via USB and unlocked
- Developer Mode enabled (Settings → Privacy & Security → Developer Mode)
- Valid code signing certificate and provisioning profile
- Device registered in Apple Developer account
- "Trust This Computer" accepted on device
- **ios-deploy installed**: `brew install ios-deploy`

#### Build Watch App (Simulator)
```bash
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach Watch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)' \
  clean build
```

#### Build Watch App (Physical Apple Watch)
```bash
# List connected Watch devices
xcrun xctrace list devices | grep "Watch"

# Build to physical Watch (paired with iPhone)
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach Watch Watch App" \
  -destination 'platform=watchOS,name=YOUR_WATCH_NAME' \
  clean build
```

#### Build Widget Extension
```bash
xcodebuild -project "Kubb Coach.xcodeproj" -scheme "KubbCoachWidgetExtension" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

#### Capture Build Logs
```bash
xcodebuild ... 2>&1 | tee /tmp/build.log
# Then read with: cat /tmp/build.log
```

---

### 2. Running Tests

#### Run All Unit Tests (102 tests across 6 suites)
```bash
xcodebuild clean test -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -testPlan KubbCoachUnitTests
```

#### Run Specific Test Suite
```bash
# GoalServiceTests (18 tests)
xcodebuild test -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Kubb_CoachTests/GoalServiceTests

# CloudSessionConverterTests (13 tests)
xcodebuild test -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Kubb_CoachTests/CloudSessionConverterTests

# StreakCalculatorTests (23 tests)
xcodebuild test -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Kubb_CoachTests/StreakCalculatorTests
```

#### Test Suites Overview
- **PlayerLevelServiceTests**: 15 tests - XP and leveling system
- **MilestoneServiceTests**: 14 tests - Achievement tracking
- **GoalServiceTests**: 18 tests - Goal creation and evaluation
- **StreakCalculatorTests**: 23 tests - Streak computation logic
- **CloudSessionConverterTests**: 13 tests - Watch ↔ iPhone data conversion
- **PersonalBestServiceTests**: 19 tests - Personal record tracking

---

### 3. Watch ↔ iPhone Sync Verification

The app uses CloudKit to sync training sessions from Apple Watch to iPhone.

#### Test Sync Workflow Manually

**Step 1: Launch Paired Simulators**
```bash
# List available simulators
xcrun simctl list devices available

# Boot iPhone simulator
xcrun simctl boot "iPhone 16 Pro"

# Boot paired Watch simulator
xcrun simctl boot "Apple Watch Ultra 2 (49mm)"

# Open Simulator app
open -a Simulator
```

**Step 2: Install Apps**
```bash
# Build and install iPhone app
xcodebuild -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -configuration Debug install

# Build and install Watch app
xcodebuild -scheme "Kubb Coach Watch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)' \
  -configuration Debug install
```

**Step 3: Verify Sync**
1. Create a training session on Watch app
2. Complete the session
3. Watch app uploads to CloudKit (check logs: "Uploaded session to CloudKit")
4. Switch to iPhone app
5. Trigger sync (pull to refresh or wait for automatic sync)
6. Verify session appears in History tab

#### Key Sync Files to Monitor
- `Services/CloudKitSyncService.swift` - Core sync logic
- `Services/TrainingSessionManager.swift` - Session lifecycle
- `Models/CloudSession.swift` - CloudKit data model
- `Services/CloudSessionConverter.swift` - Watch→iPhone conversion

#### Common Sync Issues
- **Session not syncing**: Check CloudKit container permissions in Xcode
- **Data mismatch**: Verify schema versions match (V2-V8)
- **Threading crashes**: Ensure ModelContext operations on MainActor

---

### 4. Schema Migrations

The app has evolved through 8 schema versions (V2-V8).

#### Schema Files
- `Models/SchemaV2.swift` through `Models/SchemaV8.swift`
- `Models/KubbCoachMigrationPlan.swift` - Migration strategy

#### Test Migration Path
```bash
# Run migration tests
xcodebuild test -scheme "Kubb Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Kubb_CoachTests/MigrationTests
```

#### Validate Schema Consistency
Before making schema changes:
1. Review `KubbCoachMigrationPlan.swift`
2. Add new schema version (e.g., SchemaV9.swift)
3. Update migration plan with transformation logic
4. Test migration with existing data
5. Verify CloudKit schema matches local SwiftData schema

---

### 5. Git Workflows

#### Smart Staging by Category
```bash
# Stage all Model changes
git add "Kubb Coach/Kubb Coach/Models/"**/*.swift

# Stage all Service changes
git add "Kubb Coach/Kubb Coach/Services/"**/*.swift

# Stage all View changes
git add "Kubb Coach/Kubb Coach/Views/"**/*.swift

# Stage Watch app changes
git add "Kubb Coach/Kubb Coach Watch Watch App/"**/*.swift

# Stage test files
git add "Kubb Coach/Kubb CoachTests/"**/*.swift

# Stage project configuration
git add "Kubb Coach/Kubb Coach.xcodeproj/"
```

#### Commit Message Conventions
Follow semantic commit format:
```bash
# New feature
git commit -m "feat: add session recovery on app launch"

# Bug fix
git commit -m "fix: correct undo throwing removing wrong record"

# Refactoring
git commit -m "refactor: extract CloudKit sync logic to separate service"

# Testing
git commit -m "test: add comprehensive CloudSessionConverter tests"
```

#### Branch Strategy
- `main` - Production-ready code
- `replitReWork` - Major refactoring branch (historical)
- Feature branches - For new features or experiments

---

## Project Structure

```
Kubb Coach/
├── Kubb Coach/                    # iOS App
│   ├── Views/                     # 98 SwiftUI views
│   │   ├── EightMeter/           # 8m training mode
│   │   ├── FourMeter/            # 4m blasting mode
│   │   ├── Inkasting/            # Inkasting training
│   │   ├── Statistics/           # Charts and analytics
│   │   ├── History/              # Session history
│   │   ├── Goals/                # Goal management
│   │   ├── Settings/             # App settings
│   │   └── Home/                 # Main dashboard
│   ├── Services/                  # 24 service classes
│   │   ├── CloudKitSyncService.swift
│   │   ├── TrainingSessionManager.swift
│   │   ├── InkastingAnalysisService.swift
│   │   ├── GoalService.swift
│   │   ├── StatisticsAggregator.swift
│   │   └── ...
│   ├── Models/                    # 33 data models
│   │   ├── TrainingSession.swift  # Local SwiftData
│   │   ├── CloudSession.swift     # CloudKit records
│   │   ├── SchemaV2-V8.swift      # Migrations
│   │   └── ...
│   └── Utilities/                 # Helpers and extensions
├── Kubb Coach Watch Watch App/    # watchOS App
│   └── Views/                     # Watch-optimized UI
├── KubbCoachWidget/               # Widget Extension
└── Kubb CoachTests/               # 102 unit tests

Documentation:
├── CLAUDE.md                      # This file
├── README.md                      # Project overview
├── TESTING_SUMMARY.md             # Test coverage details
└── APP_STORE_SUBMISSION.md        # Release checklist
```

---

## Development Best Practices

### When Adding New Features

1. **Read Existing Code First**
   - Use Grep to find similar implementations
   - Check Services layer for reusable logic
   - Review Models for data structure

2. **Follow Architecture Patterns**
   - Views: SwiftUI, MVVM pattern
   - Services: Business logic, stateless when possible
   - Models: SwiftData entities, CloudKit mappings

3. **Maintain Cross-Platform Compatibility**
   - Test on both iPhone and Watch simulators
   - Verify CloudKit sync works bidirectionally
   - Check widget updates correctly

4. **Write Tests**
   - Add unit tests for new Services
   - Update existing test suites if modifying core logic
   - Run full test suite before committing

5. **Update Schema Carefully**
   - Never modify existing schema versions (V2-V8 are immutable)
   - Create new schema version (V9, V10, etc.)
   - Update KubbCoachMigrationPlan.swift
   - Test migration from previous version

### Code Review Checklist

Before committing:
- [ ] Builds successfully on iPhone and Watch simulators
- [ ] All 102 unit tests pass
- [ ] No force-unwraps (!) in new code (use guard/if let)
- [ ] CloudKit sync tested if data models changed
- [ ] SwiftData queries use proper sort descriptors
- [ ] MainActor annotations correct for ModelContext usage
- [ ] No hardcoded strings (use localization when appropriate)
- [ ] Accessibility labels added for new UI elements

---

## Common Issues & Solutions

### Build Failures

**Issue**: "Command CodeSign failed"
**Solution**: Use `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` for simulator builds

**Issue**: "No such module 'SwiftData'"
**Solution**: Clean build folder: `xcodebuild clean`

**Issue**: Watch app won't build
**Solution**: Ensure Watch simulator is paired with iPhone simulator

### Test Failures

**Issue**: "Failed to launch test runner"
**Solution**: Reset simulator: `xcrun simctl erase "iPhone 16"`

**Issue**: SwiftData tests fail with "context is not on main thread"
**Solution**: Wrap ModelContext operations in `await MainActor.run {}`

### Sync Issues

**Issue**: Watch sessions not appearing on iPhone
**Solution**: Check CloudKit dashboard, verify container ID matches

**Issue**: "ModelContext unbinding from main queue" crash
**Solution**: Goal evaluation must run on MainActor (fixed in commit 2a147f9)

### Undo Bug (Fixed)

**Issue**: Undo button removes wrong throw
**Solution**: SwiftData arrays are unordered - always sort by `throwNumber` before accessing (fixed in latest commit)

---

## Swift Code Review Workflow

### Purpose
Generate comprehensive, official documentation reviews of Swift files for testing and fine-tuning.

### How to Request a Review

Simply say:
```
"Review [filename].swift"
"Code review TrainingSessionManager.swift"
"Analyze CloudKitSyncService.swift"
```

### Review Output Format

Reviews are saved as: `REVIEW_[filename]_[date].md`

Example: `REVIEW_TrainingSessionManager_2026-03-22.md`

### Review Coverage

Each review includes:

1. **File Overview**
   - Purpose and responsibility
   - Key dependencies
   - Integration points

2. **Architecture Analysis**
   - Design patterns used
   - SOLID principles adherence
   - Code organization
   - Separation of concerns

3. **Code Quality**
   - SwiftUI/SwiftData best practices
   - Error handling patterns
   - Optionals management (avoid force-unwrapping)
   - Async/await usage
   - Memory management (weak/unowned references)

4. **Performance Considerations**
   - Potential bottlenecks
   - Database query optimization
   - UI rendering efficiency
   - Memory usage patterns

5. **Security & Data Safety**
   - Input validation
   - Data sanitization
   - CloudKit data handling
   - Privacy considerations

6. **Testing Considerations**
   - Testability of current implementation
   - Missing test coverage areas
   - Recommended test cases

7. **Issues Found**
   - Critical bugs (if any)
   - Potential bugs or edge cases
   - Code smells
   - Technical debt

8. **Recommendations**
   - High-priority improvements
   - Medium-priority enhancements
   - Nice-to-have optimizations
   - Refactoring suggestions

9. **Compliance Checklist**
   - iOS best practices
   - SwiftData patterns
   - CloudKit guidelines
   - Accessibility considerations
   - App Store guidelines

### Example Usage

```
User: "Review TrainingSessionManager.swift"
```

Claude will:
1. Read the Swift file
2. Perform comprehensive analysis
3. Generate detailed review markdown
4. Save as `REVIEW_TrainingSessionManager_2026-03-22.md`
5. Summarize key findings

---

## Quick Reference Commands

### Most Used Build Commands
```bash
# Quick iPhone build
xcodebuild -scheme "Kubb Coach" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Quick test run
xcodebuild test -scheme "Kubb Coach" -destination 'platform=iOS Simulator,name=iPhone 16'

# Check build settings
xcodebuild -showBuildSettings -project "Kubb Coach.xcodeproj" -scheme "Kubb Coach"
```

### Most Used Git Commands
```bash
# Status with short format
git status --short

# Diff stats
git diff --stat

# Stage all Swift files
git add **/*.swift

# Commit with sign-off
git commit -m "feat: description" -s

# Push to main
git push origin main
```

### Simulator Management
```bash
# List all simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot "iPhone 16 Pro"

# Reset simulator
xcrun simctl erase "iPhone 16 Pro"

# Uninstall app from simulator
xcrun simctl uninstall booted com.sathomps.kubbcoach
```

### Physical Device Management
```bash
# List all connected physical devices
xcrun xctrace list devices
# or: instruments -s devices

# List only physical devices (no simulators)
xcrun xctrace list devices | grep -v "Simulator"

# Get device info
ideviceinfo -u DEVICE_UDID

# View device logs in real-time
idevicesyslog

# Install IPA to device (if you have .ipa file)
xcrun devicectl device install app --device DEVICE_ID path/to/app.ipa
```

---

## Performance Optimization Tips

1. **CloudKit Sync**: Use delta sync (already implemented) to minimize data transfer
2. **SwiftData Queries**: Add indexes on frequently queried properties
3. **View Rendering**: Use `.task` instead of `.onAppear` for async operations
4. **Watch App**: Minimize UI complexity - Watch has limited resources
5. **Widget**: Keep widget code lightweight - it runs in extension

---

## Release Checklist

Before submitting to App Store:

- [ ] Increment version/build number
- [ ] Run all tests (102 tests pass)
- [ ] Test on physical iPhone and Apple Watch
- [ ] Verify CloudKit sync in production environment
- [ ] Update App Store screenshots if UI changed
- [ ] Review privacy policy for new data collection
- [ ] Test widget on all supported sizes
- [ ] Verify accessibility with VoiceOver
- [ ] Check app size (target: under 50MB)

See `APP_STORE_SUBMISSION.md` for full checklist.

---

## Contact & Resources

**Developer**: sthompson
**Repository**: https://github.com/ST-Superman/KubbCoach
**CloudKit Container**: iCloud.com.sathomps.kubbcoach
**App Bundle ID**: com.sathomps.kubbcoach

**Key Dates**:
- Last major commit: 2026-03-22 (Session recovery + undo fixes)
- Test suite added: 2026-03-20 (102 tests)
- CloudKit delta sync: 2026-03-18

---

*This guide is maintained for Claude Code to efficiently work on the Kubb Coach iOS project. Update as workflows evolve.*
