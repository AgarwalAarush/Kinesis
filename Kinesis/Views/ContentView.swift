import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: KinesisStore
    @SceneStorage("selectedSection") private var selectedSectionRaw = AppSection.overview.rawValue

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: selectedSectionBinding)
                .environmentObject(store)
        } detail: {
            DetailView(section: selectedSection)
                .environmentObject(store)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.toggleTracking()
                } label: {
                    Label(store.trackingEnabled ? "Stop" : "Start", systemImage: store.trackingEnabled ? "stop.fill" : "play.fill")
                }
                .disabled(store.emergencyPaused)

                Button {
                    store.toggleEmergencyPause()
                } label: {
                    Label(store.emergencyPaused ? "Resume Input" : "Emergency Pause", systemImage: store.emergencyPaused ? "play.fill" : "hand.raised.fill")
                }
                .keyboardShortcut(.escape, modifiers: [.command])
                .tint(store.emergencyPaused ? .blue : .orange)
            }
        }
    }

    private var selectedSection: AppSection {
        AppSection(rawValue: selectedSectionRaw) ?? .overview
    }

    private var selectedSectionBinding: Binding<AppSection> {
        Binding(
            get: { selectedSection },
            set: { selectedSectionRaw = $0.rawValue }
        )
    }
}
