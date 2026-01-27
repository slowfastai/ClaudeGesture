import AVFoundation
import Cocoa
import SwiftUI

/// Controller for the floating camera preview window
class FloatingPreviewWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private let cameraManager: CameraManager
    private let gestureDetector: GestureDetector
    private let settings = AppSettings.shared
    /// Dedicated preview layer for the floating window (separate from popover's layer)
    private lazy var floatingPreviewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)

    /// Set to true before app termination to prevent clearing the preference
    var isAppTerminating = false

    // UserDefaults keys for window position/size persistence
    private enum Keys {
        static let windowFrame = "floatingPreviewWindowFrame"
    }

    init(cameraManager: CameraManager, gestureDetector: GestureDetector) {
        self.cameraManager = cameraManager
        self.gestureDetector = gestureDetector
        super.init()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Save position regardless of how window is closed
        saveWindowPosition()
        // Only change preference for user-initiated close, not app termination
        // Fall back to popover mode (not off) when user closes the floating window
        if !isAppTerminating {
            settings.cameraPreviewMode = .popover
        }
    }

    /// Show the floating preview window
    func show() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFront(nil)
    }

    /// Hide the floating preview window
    func hide() {
        saveWindowPosition()
        panel?.orderOut(nil)
    }

    /// Save window position to UserDefaults
    func saveWindowPosition() {
        guard let panel = panel else { return }
        let frameString = NSStringFromRect(panel.frame)
        UserDefaults.standard.set(frameString, forKey: Keys.windowFrame)
    }

    /// Load saved window position from UserDefaults
    private func loadWindowPosition() -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: Keys.windowFrame) else {
            return nil
        }
        let frame = NSRectFromString(frameString)
        // Validate the frame has non-zero dimensions
        guard frame.width > 0 && frame.height > 0 else {
            return nil
        }
        // Validate the frame intersects with at least one visible screen
        let isOnScreen = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
        return isOnScreen ? frame : nil
    }

    private func createPanel() {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        let defaultContentRect = NSRect(x: 100, y: 100, width: 200, height: 150)

        let panel = NSPanel(
            contentRect: defaultContentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        // Configure panel behavior
        panel.level = .floating
        panel.hidesOnDeactivate = false  // Keep visible when app loses focus
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.title = "Preview"
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 120, height: 90)
        panel.backgroundColor = .black
        panel.delegate = self

        // Restore saved window frame (frame rect, not content rect)
        if let savedFrame = loadWindowPosition() {
            panel.setFrame(savedFrame, display: false)
        }

        // Host the SwiftUI camera preview
        let contentView = FloatingPreviewContentView(
            cameraManager: cameraManager,
            gestureDetector: gestureDetector,
            previewLayer: floatingPreviewLayer
        )
        panel.contentView = NSHostingView(rootView: contentView)

        self.panel = panel
    }
}

/// SwiftUI content view for the floating preview window
struct FloatingPreviewContentView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var gestureDetector: GestureDetector
    let previewLayer: AVCaptureVideoPreviewLayer

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                if cameraManager.isRunning {
                    CameraPreviewView(previewLayer: previewLayer)
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text("Camera not available")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }

                // Gesture overlay (compact version for floating window)
                VStack {
                    Spacer()
                    HStack {
                        // Current gesture indicator
                        if gestureDetector.currentGesture != .none {
                            HStack(spacing: 4) {
                                Text(gestureDetector.currentGesture.emoji)
                                    .font(.caption)
                                Text(gestureDetector.currentGesture.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                        }
                        Spacer()
                        // Confidence indicator
                        if gestureDetector.detectionConfidence > 0 {
                            Text("\(Int(gestureDetector.detectionConfidence * 100))%")
                                .font(.caption2)
                                .padding(2)
                                .background(.ultraThinMaterial)
                                .cornerRadius(2)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .background(Color.black)
    }
}

#Preview {
    FloatingPreviewContentView(
        cameraManager: CameraManager(),
        gestureDetector: GestureDetector(),
        previewLayer: AVCaptureVideoPreviewLayer()
    )
    .frame(width: 200, height: 150)
}
