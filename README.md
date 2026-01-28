# ClaudeGesture

**Hands-free gesture control for Claude Code on macOS.**

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

<!-- Add a demo GIF here: ![Demo](assets/demo.gif) -->

ClaudeGesture is a macOS menubar app that uses your camera to detect hand gestures and translate them into keyboard input — letting you control Claude Code (or Codex CLI) without touching the keyboard.

## Features

- **Hand pose detection** via Apple's Vision framework
- **9 distinct gestures** mapped to keyboard shortcuts
- **Voice input** mode triggered by thumbs up (toggles fn key for Wispr Flow)
- **Hook-controlled camera** — camera activates only when Claude is waiting for input
- **Camera preview** — off, popover, or floating window with gesture overlay
- **Single instance enforcement** — prevents duplicate instances when launched via hooks
- **Menubar-only app** — no dock icon, stays out of the way

## Gesture Reference

| Emoji | Gesture | Action |
|-------|---------|--------|
| ☝️ | One Finger | Type `1` |
| ✌️ | Peace Sign | Type `2` |
| 🤟 | Three Fingers | Type `3` |
| 🖐️ | Four Fingers | Type `4` |
| ✋ | Five Fingers | Type `5` |
| ✊ | Closed Fist | Shift+Tab |
| 👍 | Thumbs Up | Toggle Voice Input |
| 👎 | Thumbs Down | Escape |
| 🤙 | Pinky Up | Enter |

## Installation

### Download

Grab the latest `.dmg` from [Releases](../../releases), open it, and drag ClaudeGesture to Applications.

### Build from Source

```bash
git clone https://github.com/anthropics/ClaudeGesture.git
cd ClaudeGesture
xcodebuild -project ClaudeGesture.xcodeproj -scheme ClaudeGesture -configuration Release build
```

## Setup

1. **Launch** ClaudeGesture — it appears as a hand icon in your menubar
2. **Grant Camera access** when prompted (required for gesture detection)
3. **Grant Accessibility access** — go to System Settings > Privacy & Security > Accessibility and enable ClaudeGesture (required for keyboard simulation)
4. **Enable the master toggle** in the menubar popover

## Claude Code Integration

ClaudeGesture can automatically activate the camera only when Claude Code is waiting for your input, using Claude Code hooks.

Add this to `~/.claude/settings.json` (global) or `.claude/settings.json` (project-specific):

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "open 'claudegesture://camera/start'", "timeout": 5 }]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "open 'claudegesture://camera/stop'", "timeout": 5 }]
      }
    ]
  }
}
```

Then select **Hook-Controlled** mode in the ClaudeGesture settings.

## Configuration

Open the settings panel from the menubar popover:

- **Gesture Sensitivity** — Vision framework confidence threshold
- **Hold Duration** — how long a gesture must be held before it triggers
- **Cooldown** — minimum time between repeated triggers
- **Camera Preview** — Off, Popover, or Floating window
- **Camera Control Mode** — Manual or Hook-Controlled

## License

MIT — SlowFast AI
