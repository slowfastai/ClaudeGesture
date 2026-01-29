import SwiftUI

/// Settings panel for configuring the app
struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            // Gesture Sensitivity
            VStack(alignment: .leading, spacing: 4) {
                Text("Gesture Sensitivity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Slider(value: $settings.gestureSensitivity, in: 0.3...1.0, step: 0.1)
                    Text("\(Int(settings.gestureSensitivity * 100))%")
                        .font(.caption)
                        .frame(width: 40)
                }
            }

            // Hold Duration
            VStack(alignment: .leading, spacing: 4) {
                Text("Hold Duration")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Slider(value: $settings.gestureHoldDuration, in: 0.1...1.0, step: 0.1)
                    Text("\(String(format: "%.1f", settings.gestureHoldDuration))s")
                        .font(.caption)
                        .frame(width: 40)
                }
            }

            // Cooldown
            VStack(alignment: .leading, spacing: 4) {
                Text("Gesture Cooldown")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Slider(value: $settings.gestureCooldown, in: 0.2...2.0, step: 0.1)
                    Text("\(String(format: "%.1f", settings.gestureCooldown))s")
                        .font(.caption)
                        .frame(width: 40)
                }
            }

            Divider()

            // Detection Backend
            VStack(alignment: .leading, spacing: 4) {
                Text("Detection Backend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("Detection Backend", selection: $settings.detectionBackend) {
                    ForEach(DetectionBackend.allCases, id: \.self) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            // Action Tuning
            VStack(alignment: .leading, spacing: 8) {
                Text("Action Tuning")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Swipe Distance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $settings.swipeDistanceThreshold, in: 0.05...0.5, step: 0.01)
                        Text(String(format: "%.2f", settings.swipeDistanceThreshold))
                            .font(.caption)
                            .frame(width: 44)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Swipe Vertical Tolerance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $settings.swipeVerticalTolerance, in: 0.02...0.4, step: 0.01)
                        Text(String(format: "%.2f", settings.swipeVerticalTolerance))
                            .font(.caption)
                            .frame(width: 44)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Swipe Time Window")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $settings.swipeTimeWindow, in: 0.1...0.5, step: 0.05)
                        Text(String(format: "%.2f", settings.swipeTimeWindow))
                            .font(.caption)
                            .frame(width: 44)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pinch Threshold")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $settings.pinchThreshold, in: 0.02...0.15, step: 0.01)
                        Text(String(format: "%.2f", settings.pinchThreshold))
                            .font(.caption)
                            .frame(width: 44)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pinch Release Threshold")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $settings.pinchReleaseThreshold, in: 0.03...0.2, step: 0.01)
                        Text(String(format: "%.2f", settings.pinchReleaseThreshold))
                            .font(.caption)
                            .frame(width: 44)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Action Cooldown")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $settings.actionCooldown, in: 0.1...1.5, step: 0.1)
                        Text(String(format: "%.1f", settings.actionCooldown))
                            .font(.caption)
                            .frame(width: 44)
                    }
                }
            }

            Divider()

            // Reset Button
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SettingsView(settings: AppSettings.shared)
        .frame(width: 280)
        .padding()
}
