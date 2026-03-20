# App Store Submission Guide for Kubb Coach

**Complete Step-by-Step Instructions for Launching on the App Store**

Version 1.1.0 | Last Updated: March 16, 2026

---

## Table of Contents

1. [Pre-Submission Checklist](#pre-submission-checklist)
2. [Creating Screenshots](#creating-screenshots)
3. [Privacy Policy Setup](#privacy-policy-setup)
4. [App Store Connect Setup](#app-store-connect-setup)
5. [Archiving and Uploading](#archiving-and-uploading)
6. [Submission Process](#submission-process)
7. [Launch Day Preparation](#launch-day-preparation)
8. [Social Media Templates](#social-media-templates)
9. [Troubleshooting](#troubleshooting)

---

## Pre-Submission Checklist

### 1. Apple Developer Account

- [x] Active Apple Developer Program membership ($99/year)
- [x] Logged into [App Store Connect](https://appstoreconnect.apple.com)
- [x] Team ID verified: `KU56QJD48N`

### 2. Technical Verification

Open your project in Xcode and verify:

- [x] **Version Number**: Set to `1.1.0`
  - Location: Target → General → Version
- [x] **Build Number**: Set to `1` (increment if resubmitting)
  - Location: Target → General → Build
- [x] **Bundle ID**: `ST-Superman.Kubb-Coach`
  - Location: Target → General → Bundle Identifier
- [x] **Deployment Target**: iOS 17.0, watchOS 10.0
  - Location: Target → General → Deployment Info
- [x] **Code Signing**: "Automatically manage signing" enabled
  - Location: Target → Signing & Capabilities

### 3. CloudKit Production Setup

⚠️ **IMPORTANT**: CloudKit must be deployed to production, not just development.

1. Open [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Select your container: `iCloud.ST-Superman.Kubb-Coach`
3. Verify schema is deployed to **Production** environment
4. Required record types:
   - `TrainingSession`
   - `TrainingRound`
   - `ThrowRecord`
5. Deploy schema: Schema → Deploy to Production

### 4. Test on Physical Devices

- [ ] Test on iPhone (ideally iPhone 15 or newer)
- [ ] Test on Apple Watch (paired with iPhone)
- [ ] Complete full onboarding flow
- [ ] Complete one training session in each mode
- [ ] Verify CloudKit sync between Watch and iPhone
- [ ] Test Inkasting camera permissions
- [ ] Verify widget displays correctly

---

## Creating Screenshots

### Required Screenshot Sizes

Apple requires screenshots for multiple device sizes:

**iPhone:**
- 6.9" display (2868 x 1320 px) - iPhone 16 Pro Max
- 6.7" display (1290 x 2796 px) - iPhone 15 Pro Max
- 5.5" display (1242 x 2208 px) - iPhone 8 Plus

**Apple Watch:**
- Varies by watch model (capture on Apple Watch Series 9 or Ultra)

### Screenshot Capture Instructions

#### Option A: Using Xcode Simulator (iPhone)

1. **Launch Simulator**
   ```bash
   # Open Xcode
   # Select Product → Destination → iPhone 15 Pro Max
   # Run the app (Cmd+R)
   ```

2. **Prepare App State**
   - Complete onboarding if first launch
   - Create sample training data:
     - Complete 2-3 training sessions with good accuracy (75%+)
     - Set up an active goal
     - Advance to Level 15+ (or modify SwiftData for demo)
     - Set up a 7+ day streak (or modify for demo)

3. **Capture Screenshots**
   - Navigate to each screen listed below
   - Press `Cmd+S` to save screenshot to Desktop
   - Screenshot saves at correct resolution automatically

4. **Export from Simulator**
   - Screenshots saved to: `~/Desktop/`
   - Already at correct resolution for App Store

#### Option B: Using Physical iPhone

1. **Take Screenshot**
   - Press Side Button + Volume Up simultaneously
   - Screenshots save to Photos app

2. **Export via AirDrop or Mac**
   - AirDrop to Mac
   - Or use Image Capture app to transfer

3. **Verify Resolution**
   - iPhone 15 Pro Max: 1290 x 2796 px
   - If wrong size, use Xcode simulator instead

### 8 Required iPhone Screenshots (In Order)

Capture these screens in this specific order for maximum App Store conversion:

#### Screenshot 1: Home Screen (HERO SHOT) ⭐

**What to Capture:**
- [HomeView.swift](Kubb%20Coach/Kubb%20Coach/Views/Home/HomeView.swift)
- Player at Level 15+ ("Viking" rank)
- Active streak of 7+ days
- Training mode cards visible
- At least one active goal

**How to Set Up:**
1. Launch app
2. Navigate to home screen
3. Ensure player card shows high level
4. Verify streak counter is visible
5. Scroll to show all three training mode cards

**Add Overlay Text** (optional but recommended):
- Text: "Your Personal Kubb Training Companion"
- Position: Top third of image
- Font: SF Pro Display Heavy, 60pt
- Color: White text with dark semi-transparent background

---

#### Screenshot 2: Training Mode Selection

**What to Capture:**
- Three training mode cards clearly visible
- 8M Precision with crosshair icon
- 4M Blasting with blast icon
- Inkasting with camera icon

**How to Set Up:**
1. Scroll on home screen to center the three mode cards
2. Ensure all card titles and icons are visible

**Add Overlay Text:**
- Text: "Three Distinct Training Modes"
- Position: Top or bottom third

---

#### Screenshot 3: Active 8M Training Session

**What to Capture:**
- [ActiveTrainingView.swift](Kubb%20Coach/Kubb%20Coach/Views/EightMeter/ActiveTrainingView.swift)
- Mid-session: Round 3-5 of 10
- Accuracy: 70-80%
- Hit/Miss buttons clearly visible

**How to Set Up:**
1. Start 8M training session (10 rounds)
2. Record throws until Round 3-5
3. Maintain 70-80% accuracy
4. Take screenshot during throw recording screen

**Add Overlay Text:**
- Text: "Real-Time Performance Tracking"
- Position: Top third

---

#### Screenshot 4: Inkasting Computer Vision

**What to Capture:**
- Inkasting analysis screen showing detected kubbs
- Cluster area visualization
- Outlier detection indicators

**How to Set Up:**
1. Start Inkasting training
2. Take/select photo of inkasted kubbs
3. Allow analysis to complete
4. Capture results screen showing bounding boxes

**Add Overlay Text:**
- Text: "Advanced Computer Vision Analysis"
- Position: Top third

---

#### Screenshot 5: Personal Records & Statistics

**What to Capture:**
- [StatisticsView.swift](Kubb%20Coach/Kubb%20Coach/Views/Statistics/StatisticsView.swift)
- Personal bests grid
- Best accuracy 75%+
- Multiple records with dates

**How to Set Up:**
1. Navigate to Statistics tab
2. Ensure you have impressive stats (complete several sessions first)
3. Scroll to show personal bests grid

**Add Overlay Text:**
- Text: "Comprehensive Analytics"
- Position: Top third

---

#### Screenshot 6: Level Up or Milestone Achievement

**What to Capture:**
- Level up celebration overlay OR
- Milestone achievement screen

**How to Set Up:**
1. Option A: Trigger level up by earning enough XP
2. Option B: View milestone achievements from home screen
3. Capture celebration animation or achievement card

**Add Overlay Text:**
- Text: "Unlock Achievements & Level Up"
- Position: Bottom third

---

#### Screenshot 7: Training Goals

**What to Capture:**
- [GoalManagementView.swift](Kubb%20Coach/Kubb%20Coach/Views/Goals/GoalManagementView.swift)
- 2-3 active goals
- Progress bars with varying completion
- XP rewards visible

**How to Set Up:**
1. Navigate to home screen
2. Tap on goals section
3. Ensure you have 2-3 active goals set up
4. Show goal management view

**Add Overlay Text:**
- Text: "Set Goals & Earn Bonus XP"
- Position: Top third

---

#### Screenshot 8: Session History

**What to Capture:**
- History view with session timeline
- Multiple sessions visible
- Mix of iPhone/Watch device badges
- Sparklines showing trends

**How to Set Up:**
1. Navigate to History tab
2. Scroll to show 4-5 recent sessions
3. Ensure device badges (iPhone/Watch icons) are visible

**Add Overlay Text:**
- Text: "Visualize Your Progress"
- Position: Top third

---

### 4 Required Apple Watch Screenshots

#### Watch Screenshot 1: Round Configuration

**What to Capture:**
- [RoundConfigurationView.swift](Kubb%20Coach/Kubb%20Coach%20Watch%20Watch%20App/Views/RoundConfigurationView.swift)
- Round selection picker
- Clear, glanceable UI

**How to Set Up:**
1. Launch Kubb Coach on Apple Watch
2. Tap "Start Training"
3. Capture round configuration screen

#### Watch Screenshot 2: Active Training

**What to Capture:**
- [ActiveTrainingView.swift](Kubb%20Coach/Kubb%20Coach%20Watch%20Watch%20App/Views/ActiveTrainingView.swift)
- Mid-round with Hit/Miss buttons
- Accuracy percentage visible

**How to Set Up:**
1. Start training session on Watch
2. Record a few throws
3. Capture during active throw recording

#### Watch Screenshot 3: Round Completion

**What to Capture:**
- [RoundCompletionView.swift](Kubb%20Coach/Kubb%20Coach%20Watch%20Watch%20App/Views/RoundCompletionView.swift)
- Round statistics
- Next round button

**How to Set Up:**
1. Complete a full round
2. Capture round completion screen before tapping "Next Round"

#### Watch Screenshot 4: Session Complete

**What to Capture:**
- [SessionCompleteView.swift](Kubb%20Coach/Kubb%20Coach%20Watch%20Watch%20App/Views/SessionCompleteView.swift)
- Final session accuracy
- Total statistics

**How to Set Up:**
1. Complete full training session
2. Capture final session summary screen

---

### Adding Overlay Text to Screenshots (Optional)

**Tools:**
- **Figma** (free): https://figma.com
- **Sketch** (Mac): https://sketch.com
- **Keynote** (Mac, free): Built-in
- **Screenshot Studio**: https://screenshot.studio

**Design Guidelines:**
- Font: SF Pro Display Heavy or similar bold sans-serif
- Size: 48-60pt
- Color: White text with 50% black background OR solid color matching brand
- Position: Top third or bottom third (never center)
- Text length: 3-8 words maximum
- Padding: 40px from edges

**Keynote Method:**
1. Create new presentation (1290 x 2796 for iPhone 15 Pro Max)
2. Insert screenshot as background
3. Add text box with overlay text
4. Style with bold font, white text, dark background
5. Export as PNG at full resolution

---

## Privacy Policy Setup

Apple **requires** a privacy policy URL for apps that collect data or use iCloud.

### Option 1: GitHub Pages (Recommended - Free)

1. **Create Privacy Policy File**

   Create a new file in your repository: `privacy-policy.html`

   ```html
   <!DOCTYPE html>
   <html lang="en">
   <head>
       <meta charset="UTF-8">
       <meta name="viewport" content="width=device-width, initial-scale=1.0">
       <title>Kubb Coach - Privacy Policy</title>
       <style>
           body {
               font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
               line-height: 1.6;
               max-width: 800px;
               margin: 40px auto;
               padding: 0 20px;
               color: #333;
           }
           h1 { color: #2c3e50; }
           h2 { color: #34495e; margin-top: 30px; }
           .updated { color: #7f8c8d; font-style: italic; }
       </style>
   </head>
   <body>
       <h1>Privacy Policy for Kubb Coach</h1>
       <p class="updated">Last updated: March 16, 2026</p>

       <h2>Overview</h2>
       <p>Kubb Coach is committed to protecting your privacy. This policy explains how we handle your data.</p>

       <h2>Data Collection and Storage</h2>
       <p>Kubb Coach stores all training data in your personal iCloud account using Apple's CloudKit service. We do not collect, access, share, or sell any user data. All data remains in your private iCloud storage.</p>

       <h3>Data Types Stored:</h3>
       <ul>
           <li>Training session records (date, time, throw results, accuracy statistics)</li>
           <li>Personal preferences and app settings</li>
           <li>Training goals and achievements</li>
           <li>Device type information (iPhone or Apple Watch) for sync purposes</li>
       </ul>

       <h2>Camera and Photo Library Access</h2>
       <p>Kubb Coach requests camera and photo library access solely for the Inkasting training mode to analyze kubb placement using computer vision. All photo processing occurs locally on your device. We do not store, upload, transmit, or access these photos unless you explicitly choose to save them.</p>

       <h2>iCloud Synchronization</h2>
       <p>Training sessions may be synchronized between your devices (iPhone and Apple Watch) using your personal iCloud account. This data is stored in your private CloudKit database and is not accessible to us, Apple (beyond standard iCloud infrastructure), or any third parties.</p>

       <h2>Data Control</h2>
       <p>You have full control over your data:</p>
       <ul>
           <li>All data can be deleted from within the app</li>
           <li>You can disable iCloud sync at any time in iOS Settings</li>
           <li>Deleting the app removes all local data from your device</li>
           <li>You can delete your iCloud data through the app's settings</li>
       </ul>

       <h2>Third-Party Services</h2>
       <p>Kubb Coach does not use any third-party analytics, advertising, or tracking services. We do not integrate with any external services that collect user data.</p>

       <h2>Children's Privacy</h2>
       <p>Kubb Coach does not knowingly collect data from children under 13. The app is designed for general audiences and does not contain content specifically targeting children.</p>

       <h2>Changes to This Policy</h2>
       <p>We may update this privacy policy occasionally to reflect changes in the app or legal requirements. Changes will be posted on this page with an updated "Last updated" date. Continued use of the app after changes constitutes acceptance of the updated policy.</p>

       <h2>Contact</h2>
       <p>For privacy questions, concerns, or requests regarding your data, please contact:</p>
       <p><strong>Email:</strong> sathomps@gmail.com</p>

       <h2>Your Rights</h2>
       <p>Depending on your location, you may have rights under privacy laws (such as GDPR, CCPA) including:</p>
       <ul>
           <li>Right to access your data</li>
           <li>Right to delete your data</li>
           <li>Right to data portability</li>
       </ul>
       <p>Since all data is stored in your personal iCloud account, you have direct control and can exercise these rights through the app or your iCloud settings.</p>

       <hr>
       <p><small>Kubb Coach is an independent app and is not affiliated with Apple Inc.</small></p>
   </body>
   </html>
   ```

2. **Enable GitHub Pages**
   - Push the file to your repository
   - Go to repository Settings → Pages
   - Source: Deploy from a branch
   - Branch: main, folder: / (root)
   - Save

3. **Privacy Policy URL**
   ```
   https://st-superman.github.io/KubbCoach/privacy-policy.html
   ```

### Option 2: Simple Text File on GitHub

Use the raw GitHub URL:
```
https://raw.githubusercontent.com/ST-Superman/KubbCoach/main/PRIVACY_POLICY.md
```

Create `PRIVACY_POLICY.md` in your repo with the privacy policy text.

### Option 3: Third-Party Generator

Use a service like:
- https://www.termsfeed.com/privacy-policy-generator/
- https://www.privacypolicies.com/

---

## App Store Connect Setup

### Step 1: Create App Record

1. **Log into App Store Connect**
   - Visit: https://appstoreconnect.apple.com
   - Click "My Apps"

2. **Create New App**
   - Click ➕ button
   - Select "New App"
   - Platform: **iOS** (Watch app is bundled)
   - Name: **Kubb Coach**
   - Primary Language: **English (U.S.)**
   - Bundle ID: Select `ST-Superman.Kubb-Coach` from dropdown
   - SKU: `kubb-coach-001` (unique identifier, can be anything)
   - User Access: **Full Access**

3. **Click "Create"**

### Step 2: App Information

Navigate to: App Store → App Information

**General Information:**
- Subtitle: `Master precision & track stats`
- Primary Category: `Sports`
- Secondary Category: `Health & Fitness`
- Content Rights: Check box "I confirm..."

**Privacy Policy:**
- URL: `https://st-superman.github.io/KubbCoach/privacy-policy.html` (or your URL)

**Age Rating:**
- Click "Edit"
- Answer questionnaire (all "No" answers)
- Result should be: **4+**
- Save

### Step 3: Pricing and Availability

Navigate to: App Store → Pricing and Availability

**Price:**
- Price: **$4.99 USD** (Tier 5)
- Start Date: Today

**Availability:**
- All Countries/Regions (or select specific)

**Save**

### Step 4: App Privacy

Navigate to: App Store → App Privacy

**Click "Get Started"**

1. **Data Collection:**
   - Question: "Does your app collect data from this app?"
   - Answer: **Yes** (for iCloud sync)

2. **Data Types:**
   - User Content → **Training session data** (not linked to user)
   - Device ID (for sync purposes, not linked to identity)

3. **Data Usage:**
   - Purpose: App Functionality
   - Linked to User: **No**
   - Used for Tracking: **No**

4. **Privacy Policy:**
   - Verify your privacy policy URL is entered

**Publish**

---

## Archiving and Uploading

### Step 1: Prepare Xcode Project

1. **Clean Build Folder**
   ```bash
   # In Xcode
   Product → Clean Build Folder (Shift+Cmd+K)
   ```

2. **Select "Any iOS Device"**
   - In Xcode toolbar
   - Select destination: "Any iOS Device (arm64)"

3. **Verify Version & Build**
   - Target → General
   - Version: `1.1.0`
   - Build: `1`

### Step 2: Archive the App

1. **Create Archive**
   ```bash
   # In Xcode
   Product → Archive
   ```
   - This takes 2-5 minutes
   - Archives window opens automatically when done

2. **Verify Archive**
   - Check: Name shows "Kubb Coach"
   - Check: Version shows "1.1.0"
   - Check: Date is today

### Step 3: Validate Archive

**Before uploading, validate the archive to catch issues early**

1. Click "Validate App"
2. Select your Apple ID (Team: KU56QJD48N)
3. **App Store Connect distribution options:**
   - Upload your app's symbols: ✓ (recommended)
   - Manage Version and Build Number: ☐ (leave unchecked)
4. Click "Next"
5. **Validation:**
   - Automatic signing: Select certificate
   - Click "Validate"
6. Wait for validation (1-3 minutes)
7. **Result should be: "Archive validation successful"**

**If validation fails, see [Troubleshooting](#troubleshooting) section**

### Step 4: Distribute to App Store

1. Click "Distribute App"
2. Method: **App Store Connect**
3. Destination: **Upload**
4. **Distribution options:**
   - Upload your app's symbols: ✓
   - Manage Version and Build Number: ☐
5. Click "Next"
6. **Automatic signing:**
   - Select certificate (should auto-select)
7. **Review:**
   - Verify: Kubb Coach, Version 1.1.0, Build 1
8. Click "Upload"
9. **Wait for upload** (3-10 minutes depending on connection)
10. **Success message:** "Upload Successful"

### Step 5: Wait for Processing

1. **Check App Store Connect**
   - Go to: My Apps → Kubb Coach → TestFlight or App Store
   - Build status: "Processing" (yellow icon)

2. **Processing Time**
   - Usually: 10-30 minutes
   - Can take up to 2 hours

3. **Email Notification**
   - You'll receive email when processing completes
   - Subject: "App Store Connect: Your build has completed processing"

4. **Processing Complete**
   - Build status changes to: "Ready to Submit"
   - Blue checkmark icon appears

---

## Submission Process

**Wait for build processing to complete before starting this section**

### Step 1: Version Information

Navigate to: App Store → 1.1.0 (Prepare for Submission)

**Screenshots and App Previews:**

Upload screenshots for each required size:

**iPhone 6.7" Display:**
1. Drag and drop 8-10 screenshots (in order)
2. Screenshots must be: 1290 x 2796 px
3. Can rearrange by dragging

**iPhone 5.5" Display:**
1. Upload same 8-10 screenshots
2. Size: 1242 x 2208 px
3. If you only captured 6.7", you may need to resize

**Apple Watch:**
1. Upload 3-4 Watch screenshots
2. Size varies by watch model

**Promotional Text (Optional):**
```
NEW: Lock screen widget shows your training streak & competition countdown. Plus improved goal tracking with AI suggestions and bonus XP rewards!
```

**Description:**
```
YOUR PERSONAL KUBB TRAINING COMPANION

Kubb Coach is the ultimate training app for players who want to master their throwing accuracy and dominate on the field. Whether you're preparing for tournaments or leveling up your recreational game, Kubb Coach provides structured drills, detailed analytics, and engaging progression systems across both iPhone and Apple Watch.

TRAINING MODES

• 8-METER PRECISION TRAINING
Practice regulation-distance baseline throws with round-by-round tracking. Record hits and misses for kubbs and king throws, view accuracy percentages in real-time, and build consistency with structured practice.

• 4-METER BLASTING (GOLF-STYLE SCORING)
Master close-range kubb clearing with golf-inspired scoring. Every throw counts - go under par to prove your skill. Track your best rounds, analyze score trends with sparklines, and celebrate perfect sessions.

• INKASTING DRILLING (COMPUTER VISION)
Use your iPhone camera to analyze kubb placement with advanced computer vision. Get instant feedback on cluster area, outlier detection, and placement consistency. Choose 5-kubb or 10-kubb rounds to match your training goals.

GAMIFICATION & PROGRESSION

• 60-LEVEL PROGRESSION SYSTEM: Earn XP from every training session and advance through Swedish-inspired ranks from "Nybörjare" (Beginner) to "Kung" (King)

• PRESTIGE SYSTEM: Reach level 60? Start over with prestige titles and keep climbing

• 22+ MILESTONE ACHIEVEMENTS: Unlock achievements for session counts, training streaks, perfect rounds, hitting streaks, and performance milestones

• DAILY STREAK TRACKING: Build training consistency with daily streaks, earn freeze shields at 10/20/30-day milestones to protect your progress

• PERSONAL BESTS: Automatically track your highest accuracy, longest session, best hitting streak, perfect rounds, and mode-specific records

• AI-SUGGESTED GOALS: Set training goals with intelligent recommendations based on your performance history. Earn bonus XP for early completion

APPLE WATCH INTEGRATION

Train completely from your wrist with the standalone Apple Watch app:
• Full training session support (8M precision and 4M blasting)
• Haptic feedback for recorded throws
• Automatic CloudKit sync to iPhone after completion
• Quick session configuration with optimized Watch UI

ANALYTICS & INSIGHTS

• COMPREHENSIVE STATISTICS: View session history, accuracy trends, and performance sparklines across all training modes
• DETAILED SESSION BREAKDOWNS: Round-by-round analysis with throw-by-throw records
• PHASE-SPECIFIC METRICS: Track mode-specific stats like blasting scores and inkasting cluster areas
• TRAINING HEAT MAPS: Visualize your training activity over time

COMPETITION READY

• TOURNAMENT COUNTDOWN: Set your next competition date and track days remaining with motivational reminders
• LOCK SCREEN WIDGET: Keep your streak and competition countdown visible at a glance
• TRAINING REMINDERS: Stay on track with your preparation schedule

WHY KUBB COACH?

✓ Native SwiftUI design optimized for iOS 17 and watchOS 10
✓ CloudKit sync keeps iPhone and Watch perfectly synchronized
✓ Offline-capable with intelligent local caching
✓ Dark mode support throughout
✓ Rich haptics and sound effects for satisfying feedback
✓ No subscriptions - one-time purchase, lifetime access
✓ Privacy-focused: all data stored in your personal iCloud

ABOUT KUBB

Kubb (pronounced "koob") is a Swedish lawn game involving throwing wooden batons at blocks to knock them over. Often called "Viking Chess," it requires accuracy, strategy, and consistency. Kubb Coach focuses on the throwing accuracy component to help you build muscle memory and improve performance.

REQUIREMENTS

• iPhone running iOS 17.0 or later
• Apple Watch running watchOS 10.0 or later (optional)
• iCloud account for cross-device sync (optional)
• Camera access for Inkasting mode (optional)

Perfect for competitive Kubb players, tournament preparation, recreational league members, and anyone looking to track their throwing improvement scientifically.

Download Kubb Coach today and take your training to the next level!
```

**Keywords:**
```
kubb,kubb game,viking chess,lawn game,outdoor game,throwing,accuracy,training,sports,stats
```

**Support URL:**
```
https://github.com/ST-Superman/KubbCoach/issues
```
or
```
mailto:sathomps@gmail.com
```

**Marketing URL (Optional):**
```
https://github.com/ST-Superman/KubbCoach
```

**What's New in This Version:**
```
MAJOR FEATURE UPDATE

🎯 AI-SUGGESTED TRAINING GOALS
• Get personalized goal recommendations based on your training history
• Earn bonus XP for early goal completion
• Track up to 5 active goals simultaneously
• Performance and consistency challenges unlock at Level 4

📱 LOCK SCREEN WIDGET
• Quick glance at your training streak
• Competition countdown always visible
• Motivational reminders right from your lock screen

🔥 ENHANCED STREAK SYSTEM
• Earn freeze shields at 10, 20, and 30-day milestones
• Automatic streak protection when you need it
• Visual indicator shows active freeze protection

🎮 IMPROVED GAMIFICATION
• Prestige system: Reach level 60 and start over with prestige titles
• Feature unlock celebrations when you reach Levels 2, 3, and 4
• Enhanced XP calculations for Inkasting mode

🎨 REFINED ONBOARDING
• Streamlined 3-step onboarding flow
• Experience level selection
• Interactive guided training session

🐛 BUG FIXES & IMPROVEMENTS
• Fixed king throw counting in round completion
• Improved CloudKit sync reliability
• Better handling of tournament countdown edge cases
• Performance optimizations across all training modes
• Enhanced haptic feedback timing
• More reliable freeze shield detection

Train smarter. Level up faster. Dominate the field.
```

**Save**

### Step 2: Build Selection

**Build Section:**
1. Click "+" next to Build
2. Select your build: Version 1.1.0, Build 1
3. Click "Done"

### Step 3: App Review Information

**Sign-In Information:**
- Sign-in required: **No**

**Contact Information:**
- First Name: [Your First Name]
- Last Name: [Your Last Name]
- Email: sathomps@gmail.com
- Phone: [Your Phone Number]

**Notes:**
```
TESTING NOTES FOR APP REVIEW:

Thank you for reviewing Kubb Coach. Here's what you need to know to test the app:

1. ONBOARDING: On first launch, you'll see a 3-step onboarding flow. Complete it to access the main app.

2. TRAINING MODES:
   • 8M Precision: Tap Hit/Miss buttons to record throws. Complete a round to see statistics.
   • 4M Blasting: Golf-style scoring where lower scores are better. Record throws and complete rounds.
   • Inkasting: Requires camera permission. Tap "Allow" when prompted. Take a photo of kubbs (any rectangular objects work for testing) to see computer vision analysis.

3. APPLE WATCH APP: The app includes a companion Apple Watch app. To test CloudKit sync:
   • Launch Kubb Coach on paired Apple Watch
   • Complete a training session on Watch
   • Open iPhone app and pull to refresh History tab
   • Watch session should appear with Watch badge

4. iCloud REQUIREMENT: The app uses CloudKit for Watch-to-iPhone sync. Please sign in with an iCloud account to test the full experience. All data stays in the user's private iCloud database.

5. CAMERA ACCESS: Inkasting mode requests camera permission for computer vision analysis of kubb placement. This is used solely for training analysis. No photos are stored or transmitted.

6. KEY FEATURES TO TEST:
   • Complete one training session (any mode)
   • Check Statistics tab for personal records
   • Verify streak counter on home screen
   • Create a training goal (unlocks at Level 4, or after first session)
   • Test lock screen widget (add from widget gallery)

For any questions during review: sathomps@gmail.com

Thank you!
```

**Attachment:**
- None required

### Step 4: Version Release

**How should this version be released:**
- Option 1: **Automatically release this version** (recommended)
- Option 2: Manually release this version (you control release date)

Select your preference and **Save**

### Step 5: Export Compliance

**Export Compliance Information:**

Question: "Is your app designed to use cryptography or does it contain or incorporate cryptography?"

Answer: **No**

(Even though the app uses HTTPS and CloudKit encryption, these are standard iOS APIs and don't require export documentation)

**Save**

### Step 6: Submit for Review

1. **Final Review:**
   - Verify all sections have green checkmarks
   - Required: Screenshots, Description, Keywords, Build, Review Info

2. **Click "Submit for Review"**
   - Confirmation dialog appears
   - Review your selections

3. **Confirm Submission**
   - Click "Submit"
   - Status changes to: "Waiting for Review"

4. **Email Confirmation**
   - You'll receive email: "App Status Update: Waiting for Review"

---

## After Submission

### Review Timeline

**Typical Timeline:**
- **Waiting for Review**: 1-24 hours
- **In Review**: 12-48 hours
- **Total time**: Usually 24-72 hours

**Check Status:**
- App Store Connect → My Apps → Kubb Coach
- Status shown at top of page

### Possible Outcomes

#### 1. Approved ✅
- Status: "Ready for Sale"
- Email: "Your App Status is Now Ready for Sale"
- **Action**: Proceed to [Launch Day](#launch-day-preparation)

#### 2. Rejected ❌
- Status: "Rejected"
- Email: "Your App Status is Rejected" (includes reasons)
- **Action**: See [Troubleshooting](#troubleshooting) section

#### 3. Metadata Rejected
- Status: "Metadata Rejected"
- Problem with screenshots, description, or keywords
- **Action**: Fix metadata and resubmit (no new build required)

#### 4. In Review for Extended Time
- If stuck in "In Review" for >72 hours:
  - Contact App Review: https://developer.apple.com/contact/app-store/?topic=review
  - Be patient and polite

---

## Launch Day Preparation

**Once your app status is "Ready for Sale"**

### Immediate Actions (Within 1 hour)

- [ ] **Download Your Own App**
  - Search "Kubb Coach" in App Store
  - Download and verify it works

- [ ] **Take Screenshots of App Store Listing**
  - Capture for social media posts
  - Save App Store search results

- [ ] **Update GitHub Repository**
  - Add App Store link to README
  - Add App Store badge image:
    ```markdown
    [![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/app/idYOUR_APP_ID)
    ```

### Launch Announcement (First 24 hours)

- [ ] Post to all social media channels
- [ ] Announce in Kubb communities
- [ ] Email friends and beta testers
- [ ] Monitor App Store reviews

---

## Social Media Templates

### Twitter/X Post

```
🎯 Kubb Coach is now live on the App Store!

Train like a pro with:
✅ 3 distinct training modes
✅ Computer vision analysis
✅ 60-level progression system
✅ Apple Watch support
✅ Full analytics & insights

Perfect for tournament prep or leveling up your game.

Download: [Your App Store Link]

#Kubb #VikingChess #AppLaunch
```

### Facebook Post

```
🎉 Big news, Kubb players!

I'm excited to announce that Kubb Coach is now available on the App Store!

After [X months] of development, I've created the ultimate training app for Kubb players who want to improve their throwing accuracy and track their progress.

Features include:
🎯 8-Meter Precision Training
💥 4-Meter Blasting (golf-style scoring)
📸 Inkasting with Computer Vision Analysis
⌚ Full Apple Watch Support
📊 Comprehensive Statistics & Analytics
🏆 60-Level Progression System with Achievements

Whether you're training for tournaments or just want to get better, Kubb Coach provides the structure and motivation to improve.

Download it here: [Your App Store Link]

I'd love to hear your feedback!
```

### Reddit r/kubb Post

**Title:** "I built an iOS app for Kubb training - Kubb Coach is now on the App Store"

```
Hi r/kubb!

Over the past [X months], I've been working on a comprehensive training app for Kubb players, and it's finally live on the App Store!

**What is Kubb Coach?**

Kubb Coach helps you improve your throwing accuracy through structured training drills, detailed analytics, and gamified progression.

**Key Features:**
- 3 Training Modes: 8M precision, 4M blasting, and Inkasting drills
- Computer vision analysis for inkasting placement
- Full Apple Watch support (train from your wrist!)
- 60-level progression system with achievements
- Comprehensive statistics and personal records
- Training goals with AI suggestions
- CloudKit sync between iPhone and Watch

**Why I Built This:**

As a competitive Kubb player, I wanted a better way to track my practice sessions and see measurable improvement. There weren't any dedicated Kubb training apps, so I decided to build one.

**Pricing:**
$4.99 one-time purchase (no subscriptions, no ads)

**Download:**
[Your App Store Link]

I'm active in this community and would love to hear your feedback, suggestions, or bug reports. You can also reach me at [email] or open an issue on GitHub.

Happy kubbing! 🎯
```

### Instagram Post Caption

```
🎯 Kubb Coach is LIVE! 🎉

Your personal training companion for mastering Kubb is now available on the App Store.

✨ Features:
• 3 distinct training modes
• Computer vision analysis
• Apple Watch support
• 60-level progression
• Full analytics

Perfect for tournament prep or casual improvement.

Link in bio! ⬆️

#Kubb #VikingChess #AppLaunch #iOS #AppleWatch #Training #GameDay
```

### Email to Beta Testers / Friends

**Subject:** Kubb Coach is Now Live on the App Store!

```
Hi [Name],

Great news! Kubb Coach is officially live on the App Store!

[If beta tester: Thank you so much for your help testing and providing feedback. Your input was invaluable in making the app better.]

You can now download the full version here: [Your App Store Link]

What's New in Version 1.1.0:
- Lock screen widget
- AI-suggested training goals
- Enhanced streak system with freeze shields
- Prestige system for infinite progression
- Tons of bug fixes and performance improvements

If you enjoy the app, I'd really appreciate it if you could leave a review on the App Store. It helps more Kubb players discover it!

And as always, I'd love to hear your thoughts, feedback, or suggestions.

Thanks for your support!

[Your Name]
```

---

## Troubleshooting

### Common Rejection Reasons & Fixes

#### 1. Guideline 2.1 - App Completeness

**Reason:** App crashes during review or features don't work.

**Fix:**
- Test thoroughly on physical devices before resubmission
- Ensure CloudKit is deployed to **production**, not just development
- Verify all permissions (camera, photo library) work correctly
- Test with a fresh iCloud account
- Resubmit with detailed testing notes

#### 2. Guideline 2.3.10 - Accurate Metadata

**Reason:** Screenshots don't match app functionality.

**Fix:**
- Ensure screenshots show actual app features
- Remove any mockup or placeholder content
- Use real data, not "Lorem ipsum"
- Resubmit with updated screenshots

#### 3. Guideline 4.2 - Minimum Functionality

**Reason:** App appears too simple or limited.

**Fix:**
- Emphasize rich features in review notes:
  - Three distinct training modes
  - Computer vision analysis
  - Gamification with 60 levels
  - Apple Watch integration
  - Comprehensive analytics
- Provide more detailed testing instructions
- Resubmit with enhanced review notes

#### 4. Guideline 5.1.1 - Privacy Policy

**Reason:** Privacy policy missing or inadequate.

**Fix:**
- Ensure privacy policy URL is accessible (not 404)
- Verify policy covers all data collection (CloudKit, camera)
- Update policy if needed
- Resubmit with corrected URL

#### 5. Guideline 2.3.8 - Metadata

**Reason:** Keywords or description contain inappropriate content.

**Fix:**
- Remove any keyword stuffing
- Ensure description is accurate, not misleading
- Remove competitor app names from keywords
- Resubmit with cleaned metadata

### Build Upload Issues

#### "Invalid Bundle" Error

**Cause:** Code signing or capabilities misconfigured

**Fix:**
1. Verify automatic signing is enabled
2. Clean build folder (Shift+Cmd+K)
3. Archive again
4. Ensure all targets have correct bundle IDs

#### "Missing Compliance" Error

**Cause:** Export compliance not answered

**Fix:**
1. App Store Connect → App Information
2. Scroll to Export Compliance
3. Answer "No" (uses only standard encryption)
4. Save and resubmit

#### "Invalid Entitlements" Error

**Cause:** Capabilities don't match provisioning profile

**Fix:**
1. Target → Signing & Capabilities
2. Remove any unused capabilities
3. Verify CloudKit container is correct
4. Clean and archive again

### Screenshot Issues

#### "Invalid Screenshot Dimensions"

**Cause:** Screenshot not exactly the required size

**Fix:**
1. Verify screenshot size:
   - iPhone 6.7": 1290 x 2796 px
   - iPhone 5.5": 1242 x 2208 px
2. Use Xcode simulator (auto-sizes correctly)
3. Don't resize manually (use correct simulator)

#### "Not Enough Screenshots"

**Cause:** Need at least 1 screenshot per device size

**Fix:**
1. Upload at least 1 screenshot for each required size
2. Can use same content, just resize appropriately

---

## Post-Launch Monitoring

### First Week Actions

- [ ] **Monitor Reviews Daily**
  - Respond to reviews (especially negative ones)
  - Thank users for positive feedback
  - Address bug reports quickly

- [ ] **Track Analytics**
  - App Store Connect → Analytics
  - Monitor: Impressions, Downloads, Conversion Rate
  - Check which screenshots users engage with most

- [ ] **Watch for Crash Reports**
  - Xcode → Window → Organizer → Crashes
  - Fix critical crashes immediately
  - Prepare version 1.1.1 if needed

### Getting Reviews

**How to Get Reviews:**
1. Ask friends and beta testers to review
2. Email Kubb leagues and tournament organizers
3. Post in Kubb communities asking for feedback
4. Respond to all reviews (shows you care)
5. Consider adding in-app review prompt (use SKStoreReviewController) in future update

**Respond to Reviews:**
- Thank positive reviewers
- Address concerns in negative reviews
- Be professional and helpful
- Never argue with reviewers

### Success Metrics

**Track These Numbers:**
- Total downloads
- Daily active users
- Session completion rate
- Average rating (goal: 4.5+)
- Number of reviews (goal: 10+ in first month)
- Crash-free rate (goal: 99%+)

---

## Next Steps After Launch

### Version 1.2.0 Planning

Based on user feedback and reviews, plan your next update:

**Potential Features:**
- User-requested features
- Bug fixes from reviews
- Performance improvements
- Additional training modes
- Social features (compare with friends)
- Export session data

**Update Cycle:**
- Minor updates (bug fixes): Every 2-4 weeks
- Feature updates: Every 2-3 months
- Keep users engaged with regular improvements

### Community Building

- Create subreddit or Discord for users
- Share training tips and techniques
- Feature user success stories
- Partner with Kubb tournaments for promotion
- Consider tournament sponsorship (promo codes)

### Marketing Continued

- App Store Search Ads ($100-200/month)
- YouTube tutorial videos
- Blog posts about Kubb training
- Reach out to Kubb influencers
- Podcast appearances (niche sports podcasts)

---

## Resources

### Apple Documentation
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### App Store Connect
- [App Store Connect](https://appstoreconnect.apple.com)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/)

### Support
- [Apple Developer Forums](https://developer.apple.com/forums/)
- [App Review Contact](https://developer.apple.com/contact/app-store/)
- GitHub Issues: https://github.com/ST-Superman/KubbCoach/issues

---

## Checklist Summary

**Before Submission:**
- [ ] Version set to 1.1.0
- [ ] CloudKit deployed to production
- [ ] Privacy policy URL ready
- [ ] Screenshots captured and styled (8-10 iPhone, 3-4 Watch)
- [ ] App Store copy ready (title, description, keywords)
- [ ] Tested on physical devices

**Submission:**
- [ ] Archive created in Xcode
- [ ] Archive validated successfully
- [ ] Build uploaded to App Store Connect
- [ ] Build processing completed
- [ ] All metadata entered in App Store Connect
- [ ] Screenshots uploaded
- [ ] App submitted for review

**Post-Submission:**
- [ ] Monitor review status daily
- [ ] Prepare launch announcements
- [ ] Plan social media posts
- [ ] Ready to respond to reviews

**Launch Day:**
- [ ] Download your own app
- [ ] Post to all social channels
- [ ] Update GitHub README
- [ ] Email friends and testers
- [ ] Monitor reviews and analytics

---

**Good luck with your launch! 🎉🎯**

For questions or issues during submission, feel free to reach out or check Apple's documentation.
