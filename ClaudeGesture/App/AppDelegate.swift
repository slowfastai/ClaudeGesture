import Cocoa
import SwiftUI

/// App delegate for handling permissions and menubar setup
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    // Managers
    let cameraManager = CameraManager()
    let gestureDetector = GestureDetector()
    let keyboardSimulator = KeyboardSimulator()
    let voiceInputManager = VoiceInputManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupMenuBar()
        setupGestureHandling()
        checkPermissions()
    }

    /// Setup the menubar status item and popover
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Gesture Control")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover with SwiftUI content
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarView(
                cameraManager: cameraManager,
                gestureDetector: gestureDetector,
                keyboardSimulator: keyboardSimulator,
                voiceInputManager: voiceInputManager
            )
        )
    }

    /// Setup gesture detection callbacks
    private func setupGestureHandling() {
        // Connect camera frames to gesture detector
        cameraManager.onFrameCaptured = { [weak self] pixelBuffer in
            self?.gestureDetector.analyzeFrame(pixelBuffer)
        }

        // Handle confirmed gestures
        gestureDetector.onGestureConfirmed = { [weak self] gesture in
            self?.handleGesture(gesture)
        }

        // Handle voice transcription
        voiceInputManager.onTranscriptionComplete = { [weak self] text in
            self?.keyboardSimulator.typeText(text)
        }
    }

    /// Handle a confirmed gesture
    private func handleGesture(_ gesture: Gesture) {
        print("Gesture confirmed: \(gesture.rawValue)")

        // Update menubar icon briefly to show feedback
        updateStatusIcon(for: gesture)

        if gesture.triggersVoiceInput {
            // Toggle voice recording
            voiceInputManager.toggleRecording()
        } else if let _ = gesture.keyCode {
            // Simulate key press
            keyboardSimulator.simulateKey(for: gesture)
        }
    }

    /// Update menubar icon to show gesture feedback
    private func updateStatusIcon(for gesture: Gesture) {
        let originalImage = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Gesture Control")

        // Change icon color briefly
        if let button = statusItem?.button {
            let feedbackImage: NSImage?
            switch gesture {
            case .thumbsUp:
                feedbackImage = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice Input")
            case .closedFist:
                feedbackImage = NSImage(systemSymbolName: "escape", accessibilityDescription: "Escape")
            case .openPalm:
                feedbackImage = NSImage(systemSymbolName: "arrow.right.to.line", accessibilityDescription: "Tab")
            default:
                feedbackImage = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Key Press")
            }

            button.image = feedbackImage

            // Restore original icon after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                button.image = originalImage
            }
        }
    }

    /// Check and request necessary permissions
    private func checkPermissions() {
        // Camera permissions are requested by CameraManager
        // Accessibility permissions
        keyboardSimulator.checkAccessibilityPermissions()
    }

    /// Toggle the popover visibility
    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure popover is focused
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        cameraManager.stop()
    }
}
