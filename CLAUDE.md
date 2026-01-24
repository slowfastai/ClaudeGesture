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
- Finger counts map to key codes (1-3 fingers → "1", "2", "3" keys)
- Open palm → Tab key
- Closed fist → Escape key
- Thumbs up → Toggle voice input mode

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
