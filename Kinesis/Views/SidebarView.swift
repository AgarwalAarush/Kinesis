import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        List {
            Section("Session") {
                StatusRow(title: "Tracking", value: store.trackingEnabled ? "On" : "Off", systemImage: store.trackingEnabled ? "cursorarrow.motionlines" : "pause.fill")
                StatusRow(title: "Helper", value: store.helperStatus.title, systemImage: helperIcon)
                StatusRow(title: "Safety", value: store.emergencyPaused ? "Paused" : "Ready", systemImage: store.emergencyPaused ? "hand.raised.fill" : "checkmark.shield.fill")
            }

            Section("Permissions") {
                StatusRow(title: "Accessibility", value: store.permissions.accessibilityTrusted ? "Granted" : "Needed", systemImage: store.permissions.accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                StatusRow(title: "Input Monitoring", value: store.permissions.inputMonitoringTrusted ? "Granted" : "Needed", systemImage: store.permissions.inputMonitoringTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Kinesis")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    store.toggleTracking()
                } label: {
                    Label(store.trackingEnabled ? "Stop Tracking" : "Start Tracking", systemImage: store.trackingEnabled ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.toggleEmergencyPause()
                } label: {
                    Label(store.emergencyPaused ? "Resume Input" : "Emergency Pause", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
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
    }
}
