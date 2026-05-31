import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: KinesisStore
    @Binding var selection: AppSection

    var body: some View {
        List(selection: $selection) {
            Section("Air Mouse") {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }

            Section("Status") {
                StatusRow(title: "Tracking", value: store.trackingEnabled ? "On" : "Off", systemImage: store.trackingEnabled ? "cursorarrow.motionlines" : "pause.fill")
                StatusRow(title: "Mode", value: store.settings.dryRunEnabled ? "Dry Run" : "Live", systemImage: store.settings.dryRunEnabled ? "eye.fill" : "bolt.fill")
                StatusRow(title: "Helper", value: store.helperStatus.title, systemImage: helperIcon)
                StatusRow(title: "Safety", value: store.emergencyPaused ? "Paused" : "Ready", systemImage: store.emergencyPaused ? "hand.raised.fill" : "checkmark.shield.fill")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Kinesis")
    }

    private var helperIcon: String {
        switch store.helperStatus {
        case .running:
            "camera.fill"
        case .starting:
            "hourglass"
        case .failed:
            "exclamationmark.triangle.fill"
        case .stopped:
            "camera"
        }
    }
}

private struct StatusRow: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .tag(Optional<AppSection>.none)
    }
}
