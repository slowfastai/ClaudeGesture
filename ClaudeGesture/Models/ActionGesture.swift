import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// Represents action-based gestures detected from motion paths
enum ActionGesture: String, CaseIterable {
    case airTap = "Air Tap"
    case backHandWave = "Backhand Wave"
    case pinchDragLeft = "Pinch Drag Left"
    case circle = "Circle"
    case none = "None"

    var displayName: String {
        return rawValue
    }

    /// The key code or action associated with this action gesture
    var keyCode: UInt16? {
        switch self {
        case .airTap: return 36 // Enter/Return
        case .backHandWave: return 48 // Tab with Shift modifier
        case .pinchDragLeft: return 53 // Escape
        case .circle: return UInt16(kVK_PageDown)
        case .none: return nil
        }
    }

    /// Modifier keys to apply with the key code
    var modifiers: CGEventFlags? {
        switch self {
        case .backHandWave: return .maskShift
        default: return nil
        }
    }

    /// Display emoji for the action
    var emoji: String {
        switch self {
        case .airTap: return "☝️"
        case .backHandWave: return "🤚"
        case .pinchDragLeft: return "🤏"
        case .circle: return "⭕️"
        case .none: return "❓"
        }
    }

    /// Description of what the action does
    var actionDescription: String {
        switch self {
        case .airTap: return "Press Enter"
        case .backHandWave: return "Press Shift+Tab"
        case .pinchDragLeft: return "Press Escape"
        case .circle: return "Press Page Down"
        case .none: return "No action"
        }
    }
}
