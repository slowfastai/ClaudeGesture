import Foundation
import Carbon.HIToolbox
import ApplicationServices

/// Simulates keyboard input using CGEvent API
class KeyboardSimulator: ObservableObject {
    @Published var accessibilityGranted = false
    @Published var lastKeyPressed: String = ""

    init() {
        checkAccessibilityPermissions()
    }

    /// Check if accessibility permissions are granted
    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permissions (opens System Settings)
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // Re-check after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.accessibilityGranted = AXIsProcessTrusted()
        }
    }

    /// Simulate a key press for the given gesture
    func simulateKey(for gesture: Gesture) {
        guard let keyCode = gesture.keyCode else { return }

        if let modifiers = gesture.modifiers {
            simulateKeyWithModifiers(keyCode: keyCode, modifiers: modifiers)
        } else {
            simulateKeyPress(keyCode: keyCode)
        }
        lastKeyPressed = gesture.actionDescription
    }

    /// Simulate pressing a key with modifier keys (e.g., Shift+Tab)
    func simulateKeyWithModifiers(keyCode: UInt16, modifiers: CGEventFlags) {
        guard accessibilityGranted else {
            print("Accessibility permissions not granted")
            requestAccessibilityPermissions()
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("Failed to create key events with modifiers")
            return
        }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        print("Simulated key press: \(keyCode) with modifiers: \(modifiers)")
    }

    /// Simulate pressing and releasing a key
    func simulateKeyPress(keyCode: UInt16) {
        guard accessibilityGranted else {
            print("Accessibility permissions not granted")
            requestAccessibilityPermissions()
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)

        // Key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            print("Failed to create key down event")
            return
        }

        // Key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("Failed to create key up event")
            return
        }

        // Post the events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        print("Simulated key press: \(keyCode)")
    }

    /// Type a string of text
    func typeText(_ text: String) {
        guard accessibilityGranted else {
            print("Accessibility permissions not granted")
            requestAccessibilityPermissions()
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)

        for character in text {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                continue
            }

            var unicodeChar = [UniChar](character.utf16)
            event.keyboardSetUnicodeString(stringLength: unicodeChar.count, unicodeString: &unicodeChar)
            event.post(tap: .cghidEventTap)

            // Key up
            if let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                upEvent.keyboardSetUnicodeString(stringLength: unicodeChar.count, unicodeString: &unicodeChar)
                upEvent.post(tap: .cghidEventTap)
            }

            // Small delay between characters for reliability
            usleep(10000) // 10ms
        }

        lastKeyPressed = "Typed: \(text.prefix(20))\(text.count > 20 ? "..." : "")"
    }
}

// MARK: - Key Code Constants
extension KeyboardSimulator {
    struct KeyCodes {
        static let key1: UInt16 = 18
        static let key2: UInt16 = 19
        static let key3: UInt16 = 20
        static let key4: UInt16 = 21
        static let key5: UInt16 = 23
        static let tab: UInt16 = 48
        static let escape: UInt16 = 53
        static let space: UInt16 = 49
        static let returnKey: UInt16 = 36
    }
}
