import Foundation
import SwiftUI

/// User preferences and settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // Keys for UserDefaults
    private enum Keys {
        static let isEnabled = "isEnabled"
        static let gestureSensitivity = "gestureSensitivity"
        static let gestureHoldDuration = "gestureHoldDuration"
        static let gestureCooldown = "gestureCooldown"
        static let deepgramApiKey = "deepgramApiKey"
        static let showCameraPreview = "showCameraPreview"
    }

    /// Whether gesture recognition is enabled
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
        }
    }

    /// Gesture detection sensitivity (0.0 to 1.0)
    @Published var gestureSensitivity: Double {
        didSet {
            defaults.set(gestureSensitivity, forKey: Keys.gestureSensitivity)
        }
    }

    /// How long a gesture must be held before triggering (in seconds)
    @Published var gestureHoldDuration: Double {
        didSet {
            defaults.set(gestureHoldDuration, forKey: Keys.gestureHoldDuration)
        }
    }

    /// Cooldown between gesture triggers (in seconds)
    @Published var gestureCooldown: Double {
        didSet {
            defaults.set(gestureCooldown, forKey: Keys.gestureCooldown)
        }
    }

    /// Deepgram API key for voice transcription
    @Published var deepgramApiKey: String {
        didSet {
            defaults.set(deepgramApiKey, forKey: Keys.deepgramApiKey)
        }
    }

    /// Whether to show camera preview in the popover
    @Published var showCameraPreview: Bool {
        didSet {
            defaults.set(showCameraPreview, forKey: Keys.showCameraPreview)
        }
    }

    private init() {
        // Load saved values or use defaults
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        self.gestureSensitivity = defaults.object(forKey: Keys.gestureSensitivity) as? Double ?? 0.7
        self.gestureHoldDuration = defaults.object(forKey: Keys.gestureHoldDuration) as? Double ?? 0.3
        self.gestureCooldown = defaults.object(forKey: Keys.gestureCooldown) as? Double ?? 0.5
        self.deepgramApiKey = defaults.string(forKey: Keys.deepgramApiKey) ?? ""
        self.showCameraPreview = defaults.object(forKey: Keys.showCameraPreview) as? Bool ?? true
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        isEnabled = false
        gestureSensitivity = 0.7
        gestureHoldDuration = 0.3
        gestureCooldown = 0.5
        deepgramApiKey = ""
        showCameraPreview = true
    }
}
