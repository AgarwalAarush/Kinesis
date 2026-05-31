import SwiftUI

struct MenuBarControls: View {
    @EnvironmentObject private var store: KinesisStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(store.trackingEnabled ? "Stop Tracking" : "Start Tracking") {
            store.toggleTracking()
        }

        Button(store.emergencyPaused ? "Resume Input" : "Emergency Pause") {
            store.toggleEmergencyPause()
        }
        .keyboardShortcut(.escape, modifiers: [.command])

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
