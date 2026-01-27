import Foundation
import SwiftUI

/// Camera control mode
enum CameraControlMode: String, CaseIterable {
    case manual = "manual"
    case hookControlled = "hookControlled"

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .hookControlled: return "Hook-Controlled"
        }
    }

    var description: String {
        switch self {
        case .manual: return "Toggle controls camera directly"
        case .hookControlled: return "Claude Code hooks control camera"
        }
    }
}

/// Camera preview mode
enum CameraPreviewMode: String, CaseIterable {
    case off = "off"
    case popover = "popover"
    case floating = "floating"

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .popover: return "Popover"
        case .floating: return "Floating"
        }
    }
}

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
        static let cameraControlMode = "cameraControlMode"
        static let cameraPreviewMode = "cameraPreviewMode"
        // Legacy keys (for migration)
        static let showCameraPreview = "showCameraPreview"
        static let floatingPreviewEnabled = "floatingPreviewEnabled"
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

    /// Camera control mode (manual or hook-controlled)
    @Published var cameraControlMode: CameraControlMode {
        didSet {
            defaults.set(cameraControlMode.rawValue, forKey: Keys.cameraControlMode)
        }
    }

    /// Camera preview mode (off, popover, or floating)
    @Published var cameraPreviewMode: CameraPreviewMode {
        didSet {
            defaults.set(cameraPreviewMode.rawValue, forKey: Keys.cameraPreviewMode)
        }
    }

    private init() {
        // Load saved values or use defaults
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        self.gestureSensitivity = defaults.object(forKey: Keys.gestureSensitivity) as? Double ?? 0.7
        self.gestureHoldDuration = defaults.object(forKey: Keys.gestureHoldDuration) as? Double ?? 0.3
        self.gestureCooldown = defaults.object(forKey: Keys.gestureCooldown) as? Double ?? 0.5
        self.deepgramApiKey = defaults.string(forKey: Keys.deepgramApiKey) ?? ""
        if let modeString = defaults.string(forKey: Keys.cameraControlMode),
           let mode = CameraControlMode(rawValue: modeString) {
            self.cameraControlMode = mode
        } else {
            self.cameraControlMode = .manual
        }

        // Handle cameraPreviewMode with migration from legacy settings
        if let previewModeString = defaults.string(forKey: Keys.cameraPreviewMode),
           let previewMode = CameraPreviewMode(rawValue: previewModeString) {
            // New setting exists, use it
            self.cameraPreviewMode = previewMode
        } else {
            // Migrate from legacy settings
            let legacyShowPreview = defaults.object(forKey: Keys.showCameraPreview) as? Bool ?? false
            let legacyFloatingEnabled = defaults.object(forKey: Keys.floatingPreviewEnabled) as? Bool ?? false

            if !legacyShowPreview {
                self.cameraPreviewMode = .off
            } else if legacyFloatingEnabled {
                self.cameraPreviewMode = .floating
            } else {
                self.cameraPreviewMode = .popover
            }

            // Save the migrated value and clean up legacy keys
            defaults.set(cameraPreviewMode.rawValue, forKey: Keys.cameraPreviewMode)
            defaults.removeObject(forKey: Keys.showCameraPreview)
            defaults.removeObject(forKey: Keys.floatingPreviewEnabled)
        }
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        isEnabled = false
        gestureSensitivity = 0.7
        gestureHoldDuration = 0.3
        gestureCooldown = 0.5
        deepgramApiKey = ""
        cameraControlMode = .manual
        cameraPreviewMode = .off
    }
}
