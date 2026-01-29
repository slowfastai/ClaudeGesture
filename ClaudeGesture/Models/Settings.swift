import Foundation
import SwiftUI

/// Camera control mode
enum CameraControlMode: String, CaseIterable {
    case hookControlled = "hookControlled"
    case manual = "manual"

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
        static let actionDetectionEnabled = "actionDetectionEnabled"
        static let actionWindowSeconds = "actionWindowSeconds"
        static let actionCooldown = "actionCooldown"
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

    /// Whether action detection is enabled
    @Published var actionDetectionEnabled: Bool {
        didSet {
            defaults.set(actionDetectionEnabled, forKey: Keys.actionDetectionEnabled)
        }
    }

    /// Time window for action detection (in seconds)
    @Published var actionWindowSeconds: Double {
        didSet {
            defaults.set(actionWindowSeconds, forKey: Keys.actionWindowSeconds)
        }
    }

    /// Cooldown between action triggers (in seconds)
    @Published var actionCooldown: Double {
        didSet {
            defaults.set(actionCooldown, forKey: Keys.actionCooldown)
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
        self.actionDetectionEnabled = defaults.object(forKey: Keys.actionDetectionEnabled) as? Bool ?? true
        self.actionWindowSeconds = defaults.object(forKey: Keys.actionWindowSeconds) as? Double ?? 0.6
        self.actionCooldown = defaults.object(forKey: Keys.actionCooldown) as? Double ?? 0.7
        if let modeString = defaults.string(forKey: Keys.cameraControlMode),
           let mode = CameraControlMode(rawValue: modeString) {
            self.cameraControlMode = mode
        } else {
            self.cameraControlMode = .hookControlled
        }

        // Handle cameraPreviewMode with migration from legacy settings
        if let previewModeString = defaults.string(forKey: Keys.cameraPreviewMode),
           let previewMode = CameraPreviewMode(rawValue: previewModeString) {
            // New setting exists, use it
            self.cameraPreviewMode = previewMode
        } else {
            // Migrate from legacy settings, preserving existing user preferences
            // showCameraPreview was the master switch in the old system
            let legacyShowPreview = defaults.object(forKey: Keys.showCameraPreview) as? Bool
            let legacyFloatingEnabled = defaults.object(forKey: Keys.floatingPreviewEnabled) as? Bool ?? false

            if legacyShowPreview == false {
                // User explicitly turned off preview - master switch takes priority
                self.cameraPreviewMode = .off
            } else if legacyFloatingEnabled {
                // User wanted floating preview and didn't turn it off
                self.cameraPreviewMode = .floating
            } else if legacyShowPreview == true {
                // User had preview on but not floating
                self.cameraPreviewMode = .popover
            } else {
                // New user (no legacy keys exist) - default to off
                self.cameraPreviewMode = .off
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
        actionDetectionEnabled = true
        actionWindowSeconds = 0.6
        actionCooldown = 0.7
        cameraControlMode = .hookControlled
        cameraPreviewMode = .off
    }
}
