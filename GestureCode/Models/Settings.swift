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
        static let cameraControlMode = "cameraControlMode"
        static let cameraPreviewMode = "cameraPreviewMode"
        static let detectionBackend = "detectionBackend"
        static let swipeDistanceThreshold = "swipeDistanceThreshold"
        static let swipeVerticalTolerance = "swipeVerticalTolerance"
        static let swipeTimeWindow = "swipeTimeWindow"
        static let pinchThreshold = "pinchThreshold"
        static let pinchReleaseThreshold = "pinchReleaseThreshold"
        static let actionCooldown = "actionCooldown"
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

    /// Gesture detection backend
    @Published var detectionBackend: DetectionBackend {
        didSet {
            defaults.set(detectionBackend.rawValue, forKey: Keys.detectionBackend)
        }
    }

    /// Swipe distance threshold (normalized)
    @Published var swipeDistanceThreshold: Double {
        didSet {
            defaults.set(swipeDistanceThreshold, forKey: Keys.swipeDistanceThreshold)
        }
    }

    /// Maximum allowed vertical drift during swipe
    @Published var swipeVerticalTolerance: Double {
        didSet {
            defaults.set(swipeVerticalTolerance, forKey: Keys.swipeVerticalTolerance)
        }
    }

    /// Swipe time window (seconds)
    @Published var swipeTimeWindow: Double {
        didSet {
            defaults.set(swipeTimeWindow, forKey: Keys.swipeTimeWindow)
        }
    }

    /// Pinch detection distance threshold (normalized)
    @Published var pinchThreshold: Double {
        didSet {
            defaults.set(pinchThreshold, forKey: Keys.pinchThreshold)
        }
    }

    /// Pinch release distance threshold (normalized)
    @Published var pinchReleaseThreshold: Double {
        didSet {
            defaults.set(pinchReleaseThreshold, forKey: Keys.pinchReleaseThreshold)
        }
    }

    /// Cooldown between action triggers (seconds)
    @Published var actionCooldown: Double {
        didSet {
            defaults.set(actionCooldown, forKey: Keys.actionCooldown)
        }
    }

    private init() {
        // Load saved values or use defaults
        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        self.gestureSensitivity = defaults.object(forKey: Keys.gestureSensitivity) as? Double ?? 0.7
        self.gestureHoldDuration = defaults.object(forKey: Keys.gestureHoldDuration) as? Double ?? 0.3
        self.gestureCooldown = defaults.object(forKey: Keys.gestureCooldown) as? Double ?? 0.5
        if let backendString = defaults.string(forKey: Keys.detectionBackend),
           let backend = DetectionBackend(rawValue: backendString) {
            self.detectionBackend = backend
        } else {
            self.detectionBackend = .vision
        }
        self.swipeDistanceThreshold = defaults.object(forKey: Keys.swipeDistanceThreshold) as? Double ?? 0.22
        self.swipeVerticalTolerance = defaults.object(forKey: Keys.swipeVerticalTolerance) as? Double ?? 0.10
        self.swipeTimeWindow = defaults.object(forKey: Keys.swipeTimeWindow) as? Double ?? 0.25
        self.pinchThreshold = defaults.object(forKey: Keys.pinchThreshold) as? Double ?? 0.06
        self.pinchReleaseThreshold = defaults.object(forKey: Keys.pinchReleaseThreshold) as? Double ?? 0.09
        self.actionCooldown = defaults.object(forKey: Keys.actionCooldown) as? Double ?? 0.4
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
        cameraControlMode = .hookControlled
        cameraPreviewMode = .off
        detectionBackend = .vision
        swipeDistanceThreshold = 0.22
        swipeVerticalTolerance = 0.10
        swipeTimeWindow = 0.25
        pinchThreshold = 0.06
        pinchReleaseThreshold = 0.09
        actionCooldown = 0.4
    }
}
