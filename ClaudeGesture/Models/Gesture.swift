import Foundation

/// Represents the different gestures that can be recognized
enum Gesture: String, CaseIterable {
    case oneFingerUp = "One Finger"
    case peaceSign = "Peace Sign"
    case threeFingers = "Three Fingers"
    case openPalm = "Open Palm"
    case closedFist = "Closed Fist"
    case thumbsUp = "Thumbs Up"
    case none = "None"

    /// The key code or action associated with this gesture
    var keyCode: UInt16? {
        switch self {
        case .oneFingerUp: return 18      // Key "1"
        case .peaceSign: return 19        // Key "2"
        case .threeFingers: return 20     // Key "3"
        case .openPalm: return 48         // Tab key
        case .closedFist: return 53       // Escape key
        case .thumbsUp: return nil        // Special: triggers voice input
        case .none: return nil
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
        case .openPalm: return "👋"
        case .closedFist: return "✊"
        case .thumbsUp: return "👍"
        case .none: return "❓"
        }
    }

    /// Description of what the gesture does
    var actionDescription: String {
        switch self {
        case .oneFingerUp: return "Type '1'"
        case .peaceSign: return "Type '2'"
        case .threeFingers: return "Type '3'"
        case .openPalm: return "Press Tab"
        case .closedFist: return "Press Escape"
        case .thumbsUp: return "Toggle Voice Input"
        case .none: return "No action"
        }
    }
}
