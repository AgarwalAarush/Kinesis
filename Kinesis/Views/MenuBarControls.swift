import SwiftUI

struct MenuBarControls: View {
    @EnvironmentObject private var store: KinesisStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(store.trackingEnabled ? "Stop Tracking" : "Start Tracking") {
            store.toggleTracking()
        }
        .disabled(store.emergencyPaused)

        Button(store.emergencyPaused ? "Resume Input" : "Emergency Pause") {
            store.toggleEmergencyPause()
        }
        .keyboardShortcut(.escape, modifiers: [.command])

        Toggle("Dry Run Mode", isOn: $store.settings.dryRunEnabled)

        Divider()

        Button("Open Kinesis") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Refresh Permissions") {
            store.refreshPermissions()
        }

        Divider()

        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
