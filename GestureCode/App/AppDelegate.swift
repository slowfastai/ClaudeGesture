import Cocoa
import Combine
import SwiftUI

/// App delegate for handling permissions and menubar setup
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    // Managers
    let cameraManager = CameraManager()
    let gestureDetector = GestureDetector()
    let keyboardSimulator = KeyboardSimulator()
    let settings = AppSettings.shared

    // Floating preview window controller
    var floatingPreviewController: FloatingPreviewWindowController?

    // Track the previously active app for focus restoration
    private var previousActiveApp: NSRunningApplication?

    // Track when we were last activated (to determine if URL event caused activation)
    private var lastActivationTime: Date?

    // Monitors Claude Code process to auto-stop camera on exit
    private var processMonitor: ProcessMonitor?

    // Combine cancellables for observing camera state
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent multiple instances — quit if another GestureCode is already running
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
        if running.count > 1 {
            NSApplication.shared.terminate(nil)
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        setupMenuBar()
        setupGestureHandling()
        setupURLHandler()
        setupFocusTracking()
        setupCameraStateObserver()
        setupFloatingPreview()
        checkPermissions()
    }

    /// Track when another app is about to lose focus to us
    private func setupFocusTracking() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillBecomeActive),
            name: NSApplication.willBecomeActiveNotification,
            object: nil
        )
    }

    /// Capture the frontmost app BEFORE we become active (critical for focus restoration)
    @objc private func appWillBecomeActive(_ notification: Notification) {
        // Record activation time to detect if URL event caused this activation
        lastActivationTime = Date()

        // At this moment, we're about to become active but haven't yet
        // So frontmostApplication is still the PREVIOUS app
        let frontmost = NSWorkspace.shared.frontmostApplication

        // Only capture if it's not ourselves (avoid self-reference)
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousActiveApp = frontmost
            print("📍 Captured previous app: \(frontmost?.localizedName ?? "unknown")")
        }
    }

    /// Observe camera state changes to keep menubar icon in sync
    private func setupCameraStateObserver() {
        cameraManager.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                guard let self = self,
                      self.settings.cameraControlMode == .hookControlled else { return }
                self.updateStatusIconForHookState(active: isRunning)
            }
            .store(in: &cancellables)
    }

    /// Setup floating preview window and observe relevant state changes
    private func setupFloatingPreview() {
        floatingPreviewController = FloatingPreviewWindowController(
            cameraManager: cameraManager,
            gestureDetector: gestureDetector
        )

        // Observe all relevant state changes for floating preview visibility
        Publishers.CombineLatest4(
            settings.$cameraPreviewMode,
            settings.$isEnabled,
            settings.$cameraControlMode,
            cameraManager.$isRunning
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] previewMode, _, _, cameraRunning in
            // Defer to next run loop to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                guard let self = self else { return }

                // Floating preview should show when:
                // 1. Preview mode is floating AND
                // 2. Camera is actually running (ensures frames are being captured)
                let shouldShow = previewMode == .floating && cameraRunning

                if shouldShow {
                    self.floatingPreviewController?.show()
                } else {
                    self.floatingPreviewController?.hide()
                }
            }
        }
        .store(in: &cancellables)
    }

    /// Register handler for custom URL scheme (gesturecode://)
    private func setupURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    /// Handle incoming URL events (gesturecode://camera/start or gesturecode://camera/stop)
    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // Note: previousActiveApp is already captured by appWillBecomeActive notification
        // which fires BEFORE we become active (correct timing for focus restoration)

        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        // Parse URL: gesturecode://camera/start -> host="camera", path="/start"
        guard url.scheme == "gesturecode",
              url.host == "camera" else {
            print("Unknown URL: \(urlString)")
            return
        }

        let command = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Parse optional pid query parameter
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pidValue = components?.queryItems?.first(where: { $0.name == "pid" })
            .flatMap { $0.value }
            .flatMap { Int32($0) }

        switch command {
        case "start":
            handleCameraStartCommand(pid: pidValue)
        case "stop":
            handleCameraStopCommand()
        default:
            print("Unknown camera command: \(command)")
        }

        // Only restore focus if we were JUST activated (within last 500ms)
        // This indicates the URL event caused the activation, not a prior user action
        let wasJustActivated = lastActivationTime.map { Date().timeIntervalSince($0) < 0.5 } ?? false
        if wasJustActivated {
            restoreFocusToPreviousApp()
        }
        lastActivationTime = nil
    }

    /// Handle camera start command from URL scheme
    private func handleCameraStartCommand(pid: pid_t? = nil) {
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

        // Monitor Claude Code process for unexpected exit
        processMonitor?.stop()
        processMonitor = nil
        if let pid = pid {
            let monitor = ProcessMonitor(pid: pid)
            monitor.onProcessTerminated = { [weak self] in
                DispatchQueue.main.async {
                    print("Claude Code process \(pid) terminated, stopping camera")
                    self?.handleCameraStopCommand()
                }
            }
            monitor.start()
            processMonitor = monitor
            print("Monitoring Claude Code process \(pid)")
        }
    }

    /// Handle camera stop command from URL scheme
    private func handleCameraStopCommand() {
        // Only respond to stop if mode is hook-controlled
        guard settings.cameraControlMode == .hookControlled else {
            print("Camera stop ignored: mode=\(settings.cameraControlMode)")
            return
        }

        keyboardSimulator.releaseFnKeyIfNeeded()
        // Always reset icon to standby (handles failed starts or rapid stop after start)
        updateStatusIconForHookState(active: false)

        processMonitor?.stop()
        processMonitor = nil

        if cameraManager.isRunning {
            cameraManager.stop()
            print("Camera stopped via hook")
        }
    }

    /// Restore focus to the previous app to prevent focus stealing from URL scheme activation
    private func restoreFocusToPreviousApp() {
        // Use a small delay to ensure URL event is fully processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            // Deactivate ourselves first
            NSApp.deactivate()

            // Restore focus to the previously tracked app
            if let previous = self.previousActiveApp, !previous.isTerminated {
                let success = previous.activate(options: [.activateIgnoringOtherApps])
                if success {
                    print("✓ Restored focus to \(previous.localizedName ?? "app")")
                } else {
                    print("✗ Failed to restore focus to \(previous.localizedName ?? "app")")
                    // Fallback: hide ourselves to let system restore
                    NSApp.hide(nil)
                }
            } else {
                // No previous app or it terminated, hide ourselves
                NSApp.hide(nil)
                print("⚠ No previous app available, hiding GestureCode")
            }

            // Clear the tracked app
            self.previousActiveApp = nil
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
                keyboardSimulator: keyboardSimulator
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

        gestureDetector.onActionDetected = { [weak self] action in
            self?.handleAction(action)
        }
    }

    /// Handle a confirmed gesture
    private func handleGesture(_ gesture: Gesture) {
        print("Gesture confirmed: \(gesture.rawValue)")

        // Update menubar icon briefly to show feedback
        updateStatusIcon(for: gesture)

        if gesture.triggersVoiceInput {
            // Toggle fn key for Wispr Flow integration
            keyboardSimulator.toggleFnKey()
        } else if let _ = gesture.keyCode {
            // Simulate key press
            keyboardSimulator.simulateKey(for: gesture)
        }

        // In hook-controlled mode, auto-stop camera after number gestures (1-5).
        // Selecting an option via keypress doesn't trigger the UserPromptSubmit
        // hook, so camera/stop would never be sent otherwise.
        if settings.cameraControlMode == .hookControlled,
           cameraManager.isRunning,
           gesture.isNumberGesture {
            handleCameraStopCommand()
        }
    }

    private func handleAction(_ action: HandAction) {
        print("Action detected: \(action.rawValue)")
        updateStatusIcon(for: action)
        keyboardSimulator.simulateAction(action)
    }

    /// Update menubar icon to show gesture feedback
    private func updateStatusIcon(for gesture: Gesture) {
        switch gesture {
        case .thumbsUp:
            showTemporaryStatusIcon(systemName: "mic.fill", accessibilityDescription: "Voice Input")
        case .thumbsDown:
            showTemporaryStatusIcon(systemName: "escape", accessibilityDescription: "Escape")
        case .pinkyUp:
            showTemporaryStatusIcon(systemName: "return", accessibilityDescription: "Enter")
        case .closedFist:
            showTemporaryStatusIcon(systemName: "arrow.left.to.line", accessibilityDescription: "Shift+Tab")
        case .fourFingers, .fiveFingers:
            showTemporaryStatusIcon(systemName: "keyboard", accessibilityDescription: "Number Key")
        default:
            showTemporaryStatusIcon(systemName: "keyboard", accessibilityDescription: "Key Press")
        }
    }

    private func updateStatusIcon(for action: HandAction) {
        switch action {
        case .swipeLeft:
            showTemporaryStatusIcon(systemName: "arrow.left", accessibilityDescription: "Swipe Left")
        case .swipeRight:
            showTemporaryStatusIcon(systemName: "arrow.right", accessibilityDescription: "Swipe Right")
        case .pinch:
            showTemporaryStatusIcon(systemName: "cursorarrow", accessibilityDescription: "Pinch Click")
        }
    }

    private func showTemporaryStatusIcon(systemName: String, accessibilityDescription: String) {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: accessibilityDescription)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.restoreStatusIcon()
        }
    }

    private func restoreStatusIcon() {
        guard let button = statusItem?.button else { return }
        let restoredImage: NSImage?
        if settings.cameraControlMode == .hookControlled && !cameraManager.isRunning {
            restoredImage = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: "Gesture Control Standby")
        } else {
            restoredImage = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Gesture Control")
        }
        button.image = restoredImage
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
        // Mark as terminating so windowWillClose doesn't reset the preference
        floatingPreviewController?.isAppTerminating = true
        // Save floating window position before terminating
        floatingPreviewController?.saveWindowPosition()
        // Cleanup
        processMonitor?.stop()
        processMonitor = nil
        keyboardSimulator.releaseFnKeyIfNeeded()
        cameraManager.stop()
    }
}
