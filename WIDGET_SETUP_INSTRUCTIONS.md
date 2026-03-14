# Lock Screen Widget Setup Instructions

Follow these steps to add the lock screen widget to your Kubb Coach app.

## Phase 1: Create App Group

1. **Open Xcode** and select your project in the navigator
2. Select the **Kubb Coach** target (iOS app)
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Add **App Groups**
6. Click **+** under App Groups
7. Enter: `group.com.sathomps.kubbcoach`
8. Click **OK**

## Phase 2: Create Widget Extension Target

1. In Xcode, go to **File → New → Target**
2. Select **Widget Extension**
3. Click **Next**
4. Configure the widget:
   - **Product Name**: `KubbCoachWidget`
   - **Include Configuration Intent**: ❌ (unchecked)
   - Click **Finish**
5. When asked "Activate 'KubbCoachWidget' scheme?", click **Activate**

## Phase 3: Add App Group to Widget Target

1. Select the **KubbCoachWidget** target (the one you just created)
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Check the box next to `group.com.sathomps.kubbcoach` (should already exist from Phase 1)

## Phase 4: Replace Widget Template Files

Xcode created template files. We need to replace them with our implementation:

1. **Delete** the following files Xcode auto-generated in the `KubbCoachWidget` folder:
   - `KubbCoachWidget.swift` (the template one)
   - `KubbCoachWidgetBundle.swift` (the template one)
   - `KubbCoachWidgetLiveActivity.swift` (if it exists)
   - `AppIntent.swift` (if it exists)

2. **Add** the widget files we created:
   - In Project Navigator, right-click on `KubbCoachWidget` folder
   - Select **Add Files to "Kubb Coach"...**
   - Navigate to `Kubb Coach/KubbCoachWidget/`
   - Select **both**:
     - `KubbCoachWidget.swift`
     - `KubbCoachWidgetBundle.swift`
   - **IMPORTANT**: In the dialog:
     - ✅ Check "Copy items if needed"
     - ✅ Under "Add to targets", check **KubbCoachWidget** ONLY
   - Click **Add**

## Phase 5: Add Shared Files to Widget Target

The widget needs access to some files from the main app:

1. Select `WidgetDataService.swift` in Project Navigator
2. Open **File Inspector** (right sidebar, first tab)
3. Under **Target Membership**:
   - ✅ Kubb Coach (already checked)
   - ✅ KubbCoachWidget (CHECK THIS)

Do the same for these files:
- `AppLogger.swift`

## Phase 6: Build and Test

1. **Select the KubbCoachWidget scheme** in Xcode toolbar
2. Choose your iPhone or iPhone simulator as destination
3. Click **Run** (Cmd+R)
4. Xcode will build and show widget preview options:
   - Select widget size to preview
   - You should see your streak and competition countdown

5. **To test on device**:
   - Run the main app first (Kubb Coach scheme)
   - Complete a session or update competition settings
   - Lock your iPhone
   - Long-press on lock screen
   - Tap **Customize**
   - Tap on widget area below the time
   - Search for "Kubb Coach" or scroll to find it
   - Tap the widget to add it
   - Tap **Done**

## Phase 7: Verify Widget Updates

1. Open the main Kubb Coach app
2. Complete a training session → Widget should update streak
3. Go to Settings → Competition → Set a competition date → Widget should show countdown
4. Return to home → Widget should display current data

## Troubleshooting

### "App Group not found" error
- Make sure you created the exact same App Group identifier (`group.com.sathomps.kubbcoach`) in both targets
- Try cleaning build folder (Cmd+Shift+K) and rebuilding

### Widget shows "0 days" streak even though you have sessions
- The widget reads from App Groups shared storage
- Make sure you've opened the main app at least once after installing
- Check that `WidgetDataService.swift` is added to both targets

### Widget doesn't update after changes
- Widgets update on their own schedule
- Force update by:
  1. Long-press widget on lock screen
  2. Remove it
  3. Re-add it
- Or use: `killall SpringBoard` in Terminal (device will respring)

### Build errors about missing symbols
- Make sure all shared files are added to widget target membership
- Check that App Group identifier matches exactly in both places

## Success Checklist

- [ ] App Group created with identifier `group.com.sathomps.kubbcoach`
- [ ] Both main app and widget have App Group enabled with same identifier
- [ ] Widget extension target created named "KubbCoachWidget"
- [ ] Template files deleted, custom files added
- [ ] `WidgetDataService.swift` and `AppLogger.swift` added to widget target
- [ ] Widget builds successfully
- [ ] Widget shows on lock screen
- [ ] Streak displays correctly
- [ ] Competition countdown shows (if set)
- [ ] Widget updates when app data changes

---

**After completing setup, test by:**
1. Running main app and completing a session
2. Checking widget shows updated streak
3. Setting a competition date in settings
4. Verifying widget shows countdown
