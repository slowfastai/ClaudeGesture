import Cocoa
import SwiftUI

/// Controller for the floating virtual keyboard window
class FloatingKeyboardWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private let gestureDetector: GestureDetector
    private let keyboardSimulator: KeyboardSimulator
    private let settings = AppSettings.shared

    /// Set to true before app termination to prevent clearing the preference
    var isAppTerminating = false

    private enum Keys {
        static let windowFrame = "floatingKeyboardWindowFrame"
    }

    init(gestureDetector: GestureDetector, keyboardSimulator: KeyboardSimulator) {
        self.gestureDetector = gestureDetector
        self.keyboardSimulator = keyboardSimulator
        super.init()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        saveWindowPosition()
        if !isAppTerminating {
            settings.virtualKeyboardEnabled = false
        }
    }

    /// Show the floating keyboard window
    func show() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFront(nil)
    }

    /// Hide the floating keyboard window
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
        guard frame.width > 0 && frame.height > 0 else {
            return nil
        }
        let isOnScreen = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
        return isOnScreen ? frame : nil
    }

    private func createPanel() {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel]
        let defaultContentRect = NSRect(x: 120, y: 120, width: 520, height: 220)

        let panel = NSPanel(
            contentRect: defaultContentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.title = "Keyboard"
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 380, height: 180)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self

        if let savedFrame = loadWindowPosition() {
            panel.setFrame(savedFrame, display: false)
        }

        let contentView = FloatingKeyboardContentView(
            gestureDetector: gestureDetector,
            keyboardSimulator: keyboardSimulator,
            settings: settings
        )
        panel.contentView = NSHostingView(rootView: contentView)

        self.panel = panel
    }
}

private struct VirtualKeyFrame: Identifiable {
    let id: String
    let key: VirtualKey
    let frame: CGRect
}

/// SwiftUI content view for the floating virtual keyboard window
struct FloatingKeyboardContentView: View {
    @ObservedObject var gestureDetector: GestureDetector
    @ObservedObject var keyboardSimulator: KeyboardSimulator
    @ObservedObject var settings: AppSettings

    private let layout = VirtualKeyboardLayout.defaultLayout

    @State private var activeKeyID: String?
    @State private var hoverStartTime: Date?
    @State private var didTriggerCurrentKey = false
    @State private var smoothedPoint: CGPoint?
    @State private var pressedKeyID: String?
    @State private var viewSize: CGSize = .zero

    private let horizontalPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 12
    private let rowSpacing: CGFloat = 8
    private let keySpacing: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let frames = layoutFrames(in: geometry.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                ForEach(frames) { item in
                    let isActive = item.key.id == activeKeyID
                    let isPressed = item.key.id == pressedKeyID
                    let label = displayLabel(for: item.key)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPressed ? Color.blue.opacity(0.6) : (isActive ? Color.blue.opacity(0.4) : Color.white.opacity(0.18)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(isActive ? 0.4 : 0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .overlay(
                            Text(label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .frame(width: item.frame.width, height: item.frame.height)
                        .position(x: item.frame.midX, y: item.frame.midY)
                        .scaleEffect(isPressed ? 1.06 : 1.0)
                        .animation(.easeOut(duration: 0.12), value: isPressed)
                }

                if let cursor = smoothedPoint {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .position(cursor)
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                }
            }
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                viewSize = newSize
            }
            .onChange(of: gestureDetector.indexTipPoint) { _, newPoint in
                handlePointChange(newPoint)
            }
            .onChange(of: gestureDetector.indexTipConfidence) { _, _ in
                handlePointChange(gestureDetector.indexTipPoint)
            }
        }
    }

    private func displayLabel(for key: VirtualKey) -> String {
        if key.id == "voice" {
            return keyboardSimulator.isFnKeyHeld ? "Voice Stop" : "Voice Open"
        }
        return key.label
    }

    private func layoutFrames(in size: CGSize) -> [VirtualKeyFrame] {
        guard size.width > 0, size.height > 0 else { return [] }
        let rows = layout.rows
        let rowCount = rows.count
        guard rowCount > 0 else { return [] }

        let totalHeight = size.height - (verticalPadding * 2) - (rowSpacing * CGFloat(rowCount - 1))
        let rowHeight = max(32, totalHeight / CGFloat(rowCount))

        var frames: [VirtualKeyFrame] = []
        var yOffset = verticalPadding

        for row in rows {
            let totalWidth = size.width - (horizontalPadding * 2)
            let totalFactors = row.reduce(CGFloat(0)) { $0 + $1.widthFactor }
            let spacingTotal = keySpacing * CGFloat(max(row.count - 1, 0))
            let availableWidth = max(0, totalWidth - spacingTotal)

            var xOffset = horizontalPadding
            for key in row {
                let keyWidth = totalFactors > 0 ? availableWidth * (key.widthFactor / totalFactors) : 0
                let frame = CGRect(x: xOffset, y: yOffset, width: keyWidth, height: rowHeight)
                frames.append(VirtualKeyFrame(id: key.id, key: key, frame: frame))
                xOffset += keyWidth + keySpacing
            }

            yOffset += rowHeight + rowSpacing
        }

        return frames
    }

    private func handlePointChange(_ normalizedPoint: CGPoint?) {
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        let minConfidence = Float(settings.gestureSensitivity)
        guard let normalizedPoint, gestureDetector.indexTipConfidence >= minConfidence else {
            clearTracking()
            return
        }

        let mapped = mapPoint(normalizedPoint, in: viewSize)
        let clamped = CGPoint(
            x: min(max(0, mapped.x), viewSize.width),
            y: min(max(0, mapped.y), viewSize.height)
        )

        if let previous = smoothedPoint {
            smoothedPoint = CGPoint(
                x: previous.x + (clamped.x - previous.x) * 0.25,
                y: previous.y + (clamped.y - previous.y) * 0.25
            )
        } else {
            smoothedPoint = clamped
        }

        guard let cursor = smoothedPoint else { return }
        let frames = layoutFrames(in: viewSize)
        let hovered = frames.first { $0.frame.contains(cursor) }

        if let hovered {
            if activeKeyID != hovered.key.id {
                activeKeyID = hovered.key.id
                hoverStartTime = Date()
                didTriggerCurrentKey = false
            } else if !didTriggerCurrentKey, let hoverStart = hoverStartTime {
                if Date().timeIntervalSince(hoverStart) >= settings.virtualKeyboardDwellDuration {
                    triggerKey(hovered.key)
                }
            }
        } else {
            activeKeyID = nil
            hoverStartTime = nil
            didTriggerCurrentKey = false
        }
    }

    private func mapPoint(_ normalizedPoint: CGPoint, in size: CGSize) -> CGPoint {
        let mirroredX = 1.0 - normalizedPoint.x
        let flippedY = 1.0 - normalizedPoint.y
        return CGPoint(x: mirroredX * size.width, y: flippedY * size.height)
    }

    private func clearTracking() {
        activeKeyID = nil
        hoverStartTime = nil
        didTriggerCurrentKey = false
        smoothedPoint = nil
    }

    private func triggerKey(_ key: VirtualKey) {
        didTriggerCurrentKey = true
        pressedKeyID = key.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if pressedKeyID == key.id {
                pressedKeyID = nil
            }
        }

        switch key.action {
        case .keyPress(let code, let modifiers):
            if let modifiers {
                keyboardSimulator.simulateKeyWithModifiers(keyCode: code, modifiers: modifiers)
            } else {
                keyboardSimulator.simulateKeyPress(keyCode: code)
            }
        case .voiceToggle:
            keyboardSimulator.toggleFnKey()
        }
    }
}

#Preview {
    FloatingKeyboardContentView(
        gestureDetector: GestureDetector(),
        keyboardSimulator: KeyboardSimulator(),
        settings: AppSettings.shared
    )
    .frame(width: 520, height: 220)
    .padding()
}
