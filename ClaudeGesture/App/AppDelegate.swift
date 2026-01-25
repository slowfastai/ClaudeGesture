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
    let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupMenuBar()
        setupGestureHandling()
        setupURLHandler()
        checkPermissions()
    }

    /// Register handler for custom URL scheme (claudegesture://)
    private func setupURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    /// Handle incoming URL events (claudegesture://camera/start or claudegesture://camera/stop)
    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        // Parse URL: claudegesture://camera/start -> host="camera", path="/start"
        guard url.scheme == "claudegesture",
              url.host == "camera" else {
            print("Unknown URL: \(urlString)")
            return
        }

        let command = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch command {
        case "start":
            handleCameraStartCommand()
        case "stop":
            handleCameraStopCommand()
        default:
            print("Unknown camera command: \(command)")
        }
    }

    /// Handle camera start command from URL scheme
    private func handleCameraStartCommand() {
        // Only start camera if: master toggle is ON and mode is hook-controlled
        guard settings.isEnabled,
              settings.cameraControlMode == .hookControlled else {
            print("Camera start ignored: isEnabled=\(settings.isEnabled), mode=\(settings.cameraControlMode)")
            return
        }

        if !cameraManager.isRunning {
            cameraManager.start()
            updateStatusIconForHookState(active: true)
            print("Camera started via hook")
        }
    }

    /// Handle camera stop command from URL scheme
    private func handleCameraStopCommand() {
        // Only respond to stop if mode is hook-controlled
        guard settings.cameraControlMode == .hookControlled else {
            print("Camera stop ignored: mode=\(settings.cameraControlMode)")
            return
        }

        // Always reset icon to standby (handles failed starts or rapid stop after start)
        updateStatusIconForHookState(active: false)

        if cameraManager.isRunning {
            cameraManager.stop()
            print("Camera stopped via hook")
        }
    }

    /// Update status icon to show hook-controlled state
    private func updateStatusIconForHookState(active: Bool) {
        guard settings.cameraControlMode == .hookControlled,
              let button = statusItem?.button else { return }

        if active {
            button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Gesture Control Active")
        } else {
            button.image = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: "Gesture Control Standby")
        }
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

            // Restore icon after delay, respecting current mode and camera state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                let restoredImage: NSImage?
                if self.settings.cameraControlMode == .hookControlled && !self.cameraManager.isRunning {
                    // Hook mode with camera stopped: show standby (unfilled) icon
                    restoredImage = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: "Gesture Control Standby")
                } else {
                    // Manual mode or camera running: show active (filled) icon
                    restoredImage = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Gesture Control")
                }
                button.image = restoredImage
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
