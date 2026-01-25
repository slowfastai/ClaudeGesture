import Foundation
import CoreGraphics

/// Represents the different gestures that can be recognized
enum Gesture: String, CaseIterable {
    case oneFingerUp = "One Finger"
    case peaceSign = "Peace Sign"
    case threeFingers = "Three Fingers"
    case fourFingers = "Four Fingers"
    case fiveFingers = "Five Fingers"
    case closedFist = "Closed Fist"
    case thumbsUp = "Thumbs Up"
    case thumbsDown = "Thumbs Down"
    case pinkyUp = "Pinky Up"
    case none = "None"

    /// The key code or action associated with this gesture
    var keyCode: UInt16? {
        switch self {
        case .oneFingerUp: return 18      // Key "1"
        case .peaceSign: return 19        // Key "2"
        case .threeFingers: return 20     // Key "3"
        case .fourFingers: return 21      // Key "4"
        case .fiveFingers: return 23      // Key "5"
        case .closedFist: return 48       // Tab key (with Shift modifier)
        case .thumbsUp: return nil        // Special: triggers voice input
        case .thumbsDown: return 53       // Escape key
        case .pinkyUp: return 36          // Enter/Return key
        case .none: return nil
        }
    }

    /// Modifier keys to apply with the key code
    var modifiers: CGEventFlags? {
        switch self {
        case .closedFist: return .maskShift
        default: return nil
        }
    }

    /// Whether this gesture triggers voice input mode
    var triggersVoiceInput: Bool {
        return self == .thumbsUp
    }

    /// Display emoji for the gesture
    var emoji: String {
        switch self {
        case .oneFingerUp: return "☝️"
        case .peaceSign: return "✌️"
        case .threeFingers: return "🤟"
        case .fourFingers: return "🖐️"
        case .fiveFingers: return "✋"
        case .closedFist: return "✊"
        case .thumbsUp: return "👍"
        case .thumbsDown: return "👎"
        case .pinkyUp: return "🤙"
        case .none: return "❓"
        }
    }

    /// Description of what the gesture does
    var actionDescription: String {
        switch self {
        case .oneFingerUp: return "Type '1'"
        case .peaceSign: return "Type '2'"
        case .threeFingers: return "Type '3'"
        case .fourFingers: return "Type '4'"
        case .fiveFingers: return "Type '5'"
        case .closedFist: return "Press Shift+Tab"
        case .thumbsUp: return "Toggle Voice Input"
        case .thumbsDown: return "Press Escape"
        case .pinkyUp: return "Press Enter"
        case .none: return "No action"
        }
    }
}
