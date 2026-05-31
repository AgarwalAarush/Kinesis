import SwiftUI

@main
struct KinesisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = KinesisStore()

    var body: some Scene {
        WindowGroup("Kinesis", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 920, minHeight: 640)
                .onAppear {
                    store.activate()
                }
        }
        .commands {
            CommandMenu("Tracking") {
                Button(store.trackingEnabled ? "Stop Tracking" : "Start Tracking") {
                    store.toggleTracking()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button(store.emergencyPaused ? "Resume Input" : "Emergency Pause") {
                    store.toggleEmergencyPause()
                }
                .keyboardShortcut(.escape, modifiers: [.command])

                Divider()

                Button("Reset Session") {
                    store.resetSession()
                }
            }
        }

        MenuBarExtra("Kinesis", systemImage: store.menuBarSystemImage) {
            MenuBarControls()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
