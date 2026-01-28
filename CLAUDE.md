# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project
xcodebuild -project ClaudeGesture.xcodeproj -scheme ClaudeGesture build

# Build for release
xcodebuild -project ClaudeGesture.xcodeproj -scheme ClaudeGesture -configuration Release build

# Clean build
xcodebuild -project ClaudeGesture.xcodeproj -scheme ClaudeGesture clean build
```

## Packaging

```bash
# Create a .dmg installer (requires: brew install create-dmg)
./scripts/create-dmg.sh /path/to/ClaudeGesture.app
```

## Architecture

ClaudeGesture is a macOS menubar-only app for hands-free gesture control. It uses the Vision framework for hand pose detection and simulates keyboard input based on recognized gestures.

### App Lifecycle

- `ClaudeGestureApp.swift`: Entry point, sets app to `.accessory` activation policy (no dock icon)
- `AppDelegate`: Creates menubar status item with popover, instantiates all managers, wires up the gesture → action pipeline

### Data Flow

```
CameraManager → GestureDetector → AppDelegate.handleGesture() → KeyboardSimulator/VoiceInputManager
     ↓                ↓
 onFrameCaptured  onGestureConfirmed
```

1. `CameraManager` captures frames from front camera, calls `onFrameCaptured` callback
2. `GestureDetector` receives pixel buffers, uses `VNDetectHumanHandPoseRequest` to classify gestures
3. Gestures are debounced (hold duration + cooldown) before triggering `onGestureConfirmed`
4. `AppDelegate` routes confirmed gestures to either `KeyboardSimulator` (key presses) or `VoiceInputManager` (thumbs up toggles recording)

### Gesture Recognition

The `Gesture` enum defines recognized gestures and their mapped actions:
- Finger counts map to key codes (1-5 fingers → "1", "2", "3", "4", "5" keys)
- Closed fist → Shift+Tab
- Thumbs up → Toggle voice input mode
- Thumbs down → Escape key
- Pinky up → Enter key

`GestureDetector` uses Vision framework finger tip positions relative to PIP joints to determine which fingers are extended.

### Required Permissions

- **Camera**: For hand gesture detection (Info.plist: `NSCameraUsageDescription`)
- **Microphone**: For voice-to-text (Info.plist: `NSMicrophoneUsageDescription`)
- **Accessibility**: For keyboard simulation (requested at runtime via `AXIsProcessTrusted`)

### Settings

`AppSettings` is a singleton storing user preferences in `UserDefaults`:
- `gestureSensitivity`: Vision confidence threshold
- `gestureHoldDuration`: Seconds gesture must be held before triggering
- `gestureCooldown`: Seconds between repeated triggers
- `deepgramApiKey`: For voice transcription API
- `cameraControlMode`: Manual or hook-controlled camera activation

### Hook-Controlled Camera Mode

ClaudeGesture supports automatic camera activation via Claude Code hooks. When enabled, the camera only runs while Claude is waiting for user input.

**URL Scheme:** `claudegesture://camera/start?pid=<PID>` and `claudegesture://camera/stop`

The `pid` query parameter is optional. When provided, ClaudeGesture monitors the process and auto-stops the camera if it exits (e.g., user kills Claude Code with ctrl+c). Old hooks without `?pid=` still work, just without auto-stop on session termination.

**Claude Code Hooks** (add to `~/.claude/settings.json` for global, or `.claude/settings.json` for project-specific):
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "open -g \"claudegesture://camera/start?pid=$PPID\"", "timeout": 5 }]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "open -g 'claudegesture://camera/stop'", "timeout": 5 }]
      }
    ]
  }
}
```

The `-g` flag prevents macOS from activating ClaudeGesture and switching desktops when the hook runs. This ensures you stay on your current desktop regardless of where ClaudeGesture was launched.

**Setup:**
1. Run ClaudeGesture and grant camera permission (do this before relying on hooks)
2. Enable master toggle and select "Hook-Controlled" mode
3. Camera activates when Claude finishes responding, deactivates when you submit

**Note:** Number gestures (1-5) automatically stop the camera after acting, since selecting an option doesn't trigger the `UserPromptSubmit` hook. Non-number gestures and manual mode are unaffected.

### TODO

- [ ] Cancel the 0.3s delayed icon restore in `updateStatusIcon(for:)` when `handleCameraStopCommand()` runs, to eliminate a theoretical race where the restore could briefly show the wrong icon state (self-corrects via `setupCameraStateObserver`, so low priority)
