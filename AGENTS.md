# Repository Guidelines

## Project Structure & Module Organization
- `GestureCode/`: Main app source.
  - `App/`: App entry point and lifecycle (`GestureCodeApp.swift`, `AppDelegate.swift`).
  - `Models/`: Core types like `Gesture` and settings.
  - `Services/`: Camera capture, gesture detection, keyboard simulation, voice input.
  - `Views/`: SwiftUI views for the menu bar UI.
  - `Resources/`: Assets and app icons.
- `GestureCode.xcodeproj/`: Xcode project configuration.
- `CLAUDE.md`: Architecture notes and build commands.

## Build, Test, and Development Commands
Run from the repo root:
- `xcodebuild -project GestureCode.xcodeproj -scheme GestureCode build` — Build the app.
- `xcodebuild -project GestureCode.xcodeproj -scheme GestureCode -configuration Release build` — Release build.
- `xcodebuild -project GestureCode.xcodeproj -scheme GestureCode clean build` — Clean rebuild.

## Coding Style & Naming Conventions
- Language: Swift (SwiftUI + AppKit).
- Indentation: 4 spaces, no tabs.
- Naming: PascalCase for types (`CameraManager`), camelCase for methods/properties (`onFrameCaptured`).
- Files generally match the primary type name (e.g., `GestureDetector.swift`).
- No formatter or linter is configured; keep edits minimal and consistent with surrounding style.

## Testing Guidelines
- No automated test target is present.
- If adding tests, prefer XCTest in a new `GestureCodeTests` target and mirror source folders (e.g., `Services/`).
- Name test files after the type under test, e.g., `GestureDetectorTests.swift`.

## Commit & Pull Request Guidelines
- Commit messages follow an emoji + type prefix, e.g., `✨ feat: add GestureCode menubar app`, `📝 docs: add CLAUDE.md`.
- Keep commits focused and imperative.
- PRs should include: a brief description, relevant screenshots for UI changes, and any required setup steps (permissions, API keys).

## Security & Configuration Tips
- Required permissions: Camera, Microphone, and Accessibility (see `GestureCode/Info.plist`).
- Voice transcription uses a Deepgram API key stored in user settings; avoid hardcoding secrets.
- When changing entitlements, update `GestureCode/GestureCode.entitlements` and verify build signing.

## Agent-Specific Instructions
- Review `CLAUDE.md` for architecture details and the gesture pipeline before modifying core services.
