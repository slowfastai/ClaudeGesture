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

            // Action Detection Toggle
            Toggle(isOn: $settings.actionDetectionEnabled) {
                Text("Action Detection")
            }
            .toggleStyle(.switch)

            // Action Window
            VStack(alignment: .leading, spacing: 4) {
                Text("Action Window")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Slider(value: $settings.actionWindowSeconds, in: 0.3...1.2, step: 0.1)
                    Text("\(String(format: "%.1f", settings.actionWindowSeconds))s")
                        .font(.caption)
                        .frame(width: 40)
                }
            }

            // Action Cooldown
            VStack(alignment: .leading, spacing: 4) {
                Text("Action Cooldown")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Slider(value: $settings.actionCooldown, in: 0.3...2.0, step: 0.1)
                    Text("\(String(format: "%.1f", settings.actionCooldown))s")
                        .font(.caption)
                        .frame(width: 40)
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
