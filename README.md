# Kubb Coach

<div align="center">
  <img src="Kubb Coach/Kubb Coach/Assets.xcassets/coach4kubb.imageset/coach4kubbtransparent.png" alt="Kubb Coach Logo" width="200"/>

  **Your Personal Kubb Training Companion**

  Track, analyze, and improve your Kubb throwing skills with structured training drills on iOS and Apple Watch.
</div>

---

## Overview

Kubb Coach is a native iOS and watchOS training application designed to help Kubb players improve their throwing accuracy and consistency through structured practice sessions. Whether you're training for tournaments or just looking to level up your game, Kubb Coach provides the tools to track your progress and identify areas for improvement.

## Features

### 🎯 Structured Training Sessions
- **8-Meter Training**: Standard baseline throwing practice at regulation distance
- **Configurable Rounds**: Choose the number of rounds for each training session
- **Real-time Tracking**: Record hits and misses for baseline kubbs and king throws
- **Session Types**: Standard practice with more types coming soon

### ⌚ Apple Watch Support
- Complete training sessions entirely from your Apple Watch
- Haptic feedback for recorded throws
- Optimized Watch UI for quick throw recording
- Automatic CloudKit sync after session completion

### ☁️ CloudKit Sync
- Seamless synchronization between iPhone and Apple Watch
- Training sessions completed on Watch automatically sync to iPhone
- Unified training history across all devices
- Intelligent local caching for instant loading and offline access

### 📊 Comprehensive Statistics
- **Personal Records**: Track your best achievements including:
  - Best session accuracy with throw count and date
  - Longest training session
  - Most productive session
  - Best hitting streak
  - King throw accuracy
  - Perfect rounds count
- **Session History**: Complete timeline of all training sessions with device badges
- **Detailed Analysis**: View round-by-round performance for every session
- **Info System**: Learn how each statistic is calculated with helpful explanations

### 🎨 Modern Design
- Native SwiftUI interface optimized for iOS 17 and watchOS 10
- Custom design system with consistent styling
- Smooth animations and transitions
- Dark mode support

## Technologies

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Local data persistence with relationships
- **CloudKit**: Cross-device synchronization with private database
- **Combine**: Reactive data flow
- **Async/Await**: Modern Swift concurrency

## Architecture

### Data Models
```swift
TrainingSession (Local Storage)
├── TrainingRound
│   └── ThrowRecord

CloudSession (CloudKit Records)
├── CloudRound
│   └── CloudThrow

CachedCloudSession (Local Cache)
├── CachedCloudRound
│   └── CachedCloudThrow
```

### Sync Strategy
1. **Watch → CloudKit**: Sessions upload immediately after completion
2. **CloudKit → iPhone**: Cached locally for instant access
3. **iPhone Only**: Sessions remain in local SwiftData storage
4. **Unified Display**: Merge local and cloud sessions in all views

### Key Services
- `CloudKitSyncService`: Handles all CloudKit operations with intelligent caching
- `TrainingSessionManager`: Manages active training sessions and state
- Platform-specific compilation for iOS-only caching features

## Requirements

- iOS 17.0+ / watchOS 10.0+
- Xcode 15.0+
- Swift 5.9+
- iCloud account for CloudKit sync

## Installation

1. Clone the repository:
```bash
git clone https://github.com/ST-Superman/KubbCoach.git
cd KubbCoach
```

2. Open the project in Xcode:
```bash
open "Kubb Coach.xcodeproj"
```

3. Configure CloudKit:
   - Enable CloudKit capability in your Apple Developer account
   - Update the bundle identifier and team
   - Ensure iCloud container is configured

4. Build and run:
   - Select your target device (iPhone or Apple Watch)
   - Press `Cmd+R` to build and run

## Usage

### Starting a Training Session

**On iPhone:**
1. Open Kubb Coach and tap "Training" on the home screen
2. Select your training phase (8 Meters, 4m Blasting, or Inkasting)
3. Choose session type (Standard)
4. Configure number of rounds
5. Begin training and record each throw
6. Complete the session to save locally

**On Apple Watch:**
1. Open Kubb Coach on your Watch
2. Tap "Start Training"
3. Configure rounds and baseline
4. Record throws with simple tap interface
5. Session automatically uploads to CloudKit when complete

### Viewing Statistics

1. Navigate to the **Statistics** tab
2. View your Personal Records in the grid layout
3. Tap the info button (ⓘ) on any record to learn more
4. Tap on a record to jump to the related session details

### Session History

1. Navigate to the **History** tab
2. View all sessions sorted by date (most recent first)
3. Device badges show whether session was completed on iPhone or Watch
4. Tap any session to view detailed round-by-round breakdown
5. Pull to refresh to sync latest Watch sessions

## Project Structure

```
Kubb Coach/
├── Kubb Coach/                     # iOS App
│   ├── Models/                     # Data models and enums
│   │   ├── TrainingSession.swift   # Local session model
│   │   ├── CloudSession.swift      # CloudKit session model
│   │   ├── CachedCloudSession.swift # Cache models
│   │   └── Enums.swift             # Training phases, types, results
│   ├── Services/                   # Business logic
│   │   ├── CloudKitSyncService.swift
│   │   └── TrainingSessionManager.swift
│   ├── Views/                      # SwiftUI views
│   │   ├── Home/                   # Home and setup views
│   │   ├── EightMeter/             # Training session views
│   │   ├── History/                # Session history and details
│   │   ├── Statistics/             # Stats and records
│   │   └── Components/             # Reusable UI components
│   └── Assets.xcassets/            # Images and icons
└── Kubb Coach Watch Watch App/     # watchOS App
    ├── Views/                      # Watch-specific views
    └── Assets.xcassets/            # Watch icons
```

## Roadmap

### Planned Features
- [ ] 4-Meter Blasting training mode
- [ ] Inkasting (corner throw) training mode
- [ ] Progressive session types (increasing difficulty)
- [ ] Timed session types (speed training)
- [ ] Custom training programs
- [ ] Social features (compare stats with friends)
- [ ] Export training data (CSV/JSON)
- [ ] Advanced analytics and trends
- [ ] Training reminders and goals
- [ ] iPad support with enhanced layouts

## CloudKit Setup

For developers wanting to use CloudKit sync:

1. **Enable CloudKit** in Xcode capabilities
2. **Create Record Types** in CloudKit Console:
   - `TrainingSession` with indexed fields: `recordName`, `createdAt`, `phase`, `sessionType`
   - `TrainingRound` with indexed fields: `recordName`, `sessionId`, `roundNumber`
   - `ThrowRecord` with indexed fields: `recordName`, `roundId`, `throwNumber`
3. **Deploy Schema** to production when ready

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## About Kubb

Kubb (pronounced "koob") is a Swedish lawn game that involves throwing wooden batons at wooden blocks (kubbs) and ultimately knocking over the king. It's often called "Viking Chess" and requires accuracy, strategy, and consistency. This app focuses on the throwing accuracy component of the game.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with ❤️ for the Kubb community
- Developed with [Claude Code](https://claude.com/claude-code)
- Icons and assets created specifically for Kubb Coach

---

<div align="center">
  Made for Kubb players, by Kubb players 🎯

  [Report Bug](https://github.com/ST-Superman/KubbCoach/issues) · [Request Feature](https://github.com/ST-Superman/KubbCoach/issues)
</div>
