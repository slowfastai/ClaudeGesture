import Foundation

enum HandAction: String, CaseIterable {
    case swipeLeft = "Swipe Left"
    case swipeRight = "Swipe Right"
    case pinch = "Pinch"

    var actionDescription: String {
        switch self {
        case .swipeLeft:
            return "Swipe Left"
        case .swipeRight:
            return "Swipe Right"
        case .pinch:
            return "Pinch (Click)"
        }
    }

    var emoji: String {
        switch self {
        case .swipeLeft:
            return "⬅️"
        case .swipeRight:
            return "➡️"
        case .pinch:
            return "🤏"
        }
    }
}
