import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(store)
        } detail: {
            DetailView()
                .environmentObject(store)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.toggleTracking()
                } label: {
                    Label(store.trackingEnabled ? "Stop" : "Start", systemImage: store.trackingEnabled ? "stop.fill" : "play.fill")
                }

                Button {
                    store.emergencyPause()
                } label: {
                    Label("Emergency Pause", systemImage: "hand.raised.fill")
                }
                .keyboardShortcut(.escape, modifiers: [.command])
                .disabled(store.emergencyPaused)
            }
        }
    }
}
