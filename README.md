# MyFirstApp

A SwiftUI iOS application.

## Development Setup

This project uses a dual-IDE workflow:
- **VS Code** - Primary code editor with Claude AI assistance
- **Xcode** - Building, running, and debugging

## Getting Started

### Creating the Xcode Project

1. Open Xcode
2. Select **File → New → Project**
3. Choose **iOS → App**
4. Fill in the project details:
   - Product Name: `MyFirstApp`
   - Team: Select your development team
   - Organization Identifier: `com.yourname` (or your preferred identifier)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (or SwiftData if you want persistence)
5. **Important**: Save the project in this directory (`~/Developer/MyFirstApp`)
6. Xcode will create the project files here

### Development Workflow

1. **Edit code in VS Code**
   - Open this folder in VS Code
   - Write and modify Swift files with Claude's help
   - Save your changes

2. **Build and run in Xcode**
   - Open `MyFirstApp.xcodeproj` in Xcode
   - Select a simulator or device
   - Click the Play button (or Cmd+R) to build and run

3. **Version control with Git**
   - Initialize: `git init`
   - Add files: `git add .`
   - Commit: `git commit -m "Initial commit"`
   - Create GitHub repo and push

## Project Structure

```
MyFirstApp/
├── .vscode/
│   └── settings.json          # VS Code Swift configuration
├── .gitignore                 # Git ignore rules for iOS
├── MyFirstApp.xcodeproj/      # Xcode project (created by Xcode)
├── MyFirstApp/                # Source code (created by Xcode)
│   ├── MyFirstAppApp.swift    # App entry point
│   ├── ContentView.swift      # Main view
│   └── Assets.xcassets/       # Images and colors
└── README.md                  # This file
```

## Tips

- Always save files in VS Code before switching to Xcode to build
- Xcode will prompt to reload if files change externally - click "Reload"
- Use Claude in VS Code for code suggestions, refactoring, and learning
- Use Xcode's Interface Builder and debugging tools for UI work
