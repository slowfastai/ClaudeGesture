import SwiftUI

/// Main menubar popover view
struct MenuBarView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var gestureDetector: GestureDetector
    @ObservedObject var keyboardSimulator: KeyboardSimulator
    @ObservedObject var voiceInputManager: VoiceInputManager

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                Text("ClaudeGesture")
                    .font(.headline)
                Spacer()
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Enable/Disable Toggle
            Toggle(isOn: $settings.isEnabled) {
                HStack {
                    Image(systemName: settings.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(settings.isEnabled ? .green : .secondary)
                    Text(settings.isEnabled ? "Enabled" : "Disabled")
                }
            }
            .toggleStyle(.switch)
            .onChange(of: settings.isEnabled) { _, newValue in
                if newValue {
                    cameraManager.start()
                } else {
                    cameraManager.stop()
                }
            }

            // Status Section
            if settings.isEnabled {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        // Camera Status
                        StatusRow(
                            icon: cameraManager.isRunning ? "camera.fill" : "camera",
                            title: "Camera",
                            status: cameraManager.isRunning ? "Active" : "Inactive",
                            color: cameraManager.isRunning ? .green : .secondary
                        )

                        // Current Gesture
                        StatusRow(
                            icon: "hand.point.up.fill",
                            title: "Gesture",
                            status: "\(gestureDetector.currentGesture.emoji) \(gestureDetector.currentGesture.rawValue)",
                            color: gestureDetector.currentGesture != .none ? .blue : .secondary
                        )

                        // Voice Recording Status
                        if voiceInputManager.isRecording {
                            StatusRow(
                                icon: "mic.fill",
                                title: "Voice",
                                status: "Recording...",
                                color: .red
                            )
                        } else if voiceInputManager.isTranscribing {
                            StatusRow(
                                icon: "waveform",
                                title: "Voice",
                                status: "Transcribing...",
                                color: .orange
                            )
                        }

                        // Last Action
                        if !keyboardSimulator.lastKeyPressed.isEmpty {
                            StatusRow(
                                icon: "keyboard",
                                title: "Last Action",
                                status: keyboardSimulator.lastKeyPressed,
                                color: .purple
                            )
                        }
                    }
                }
            }

            // Permissions Warnings
            if !cameraManager.permissionGranted {
                WarningRow(
                    icon: "camera.fill",
                    message: "Camera access required",
                    action: "Grant Access",
                    onAction: { cameraManager.checkPermissions() }
                )
            }

            if !keyboardSimulator.accessibilityGranted {
                WarningRow(
                    icon: "keyboard",
                    message: "Accessibility access required",
                    action: "Open Settings",
                    onAction: { keyboardSimulator.requestAccessibilityPermissions() }
                )
            }

            // Error Messages
            if let error = cameraManager.errorMessage {
                ErrorRow(message: error)
            }
            if let error = voiceInputManager.errorMessage {
                ErrorRow(message: error)
            }

            Divider()

            // Gesture Reference
            if !showSettings {
                GestureReferenceView()
            }

            // Settings Panel
            if showSettings {
                SettingsView(settings: settings)
            }

            Divider()

            // Footer
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let icon: String
    let title: String
    let status: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(status)
                .foregroundColor(color)
        }
        .font(.caption)
    }
}

struct WarningRow: View {
    let icon: String
    let message: String
    let action: String
    let onAction: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
            Spacer()
            Button(action, action: onAction)
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ErrorRow: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

struct GestureReferenceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gestures")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 4) {
                ForEach(Gesture.allCases.filter { $0 != .none }, id: \.self) { gesture in
                    HStack(spacing: 4) {
                        Text(gesture.emoji)
                            .font(.caption)
                        Text(gesture.actionDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    MenuBarView(
        cameraManager: CameraManager(),
        gestureDetector: GestureDetector(),
        keyboardSimulator: KeyboardSimulator(),
        voiceInputManager: VoiceInputManager()
    )
}
