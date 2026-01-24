import SwiftUI

/// Main application entry point
@main
struct ClaudeGestureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menubar-only app - no window needed
        // Using WindowGroup with empty content that's immediately hidden
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowResizability(.contentSize)
    }

    init() {
        // Hide the dock icon for menubar-only app
        NSApp.setActivationPolicy(.accessory)
    }
}
