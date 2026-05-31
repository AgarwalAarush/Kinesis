import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeaderPanel()
                ControlPanel()
                SettingsPanel()
                PermissionPanel()
                GestureLogView()
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .navigationTitle("Air Mouse")
    }
}

private struct HeaderPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("v0 Air Mouse")
                .font(.largeTitle.weight(.semibold))
            Text(store.latestDecision.reason)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 10) {
                StatusPill(title: "Gesture", value: store.latestIntent.gesture.rawValue)
                StatusPill(title: "Confidence", value: store.latestIntent.confidence.formatted(.number.precision(.fractionLength(2))))
                StatusPill(title: "FPS", value: store.latestIntent.diagnostics.fps.formatted(.number.precision(.fractionLength(1))))
            }
        }
    }
}

private struct ControlPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GroupBox("Controls") {
            HStack {
                Button {
                    store.toggleTracking()
                } label: {
                    Label(store.trackingEnabled ? "Stop Tracking" : "Start Tracking", systemImage: store.trackingEnabled ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.emergencyPause()
                } label: {
                    Label("Emergency Pause", systemImage: "hand.raised.fill")
                }
                .disabled(store.emergencyPaused)

                Button {
                    store.resetSession()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
    }
}

private struct SettingsPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GroupBox("Gesture Settings") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Cursor movement", isOn: $store.settings.cursorEnabled)
                Toggle("Pinch click and drag", isOn: $store.settings.clickDragEnabled)
                Toggle("Two-finger scroll", isOn: $store.settings.scrollEnabled)

                SettingSlider(title: "Tracking speed", value: $store.settings.trackingSpeed, range: 2...18)
                SettingSlider(title: "Smoothing", value: $store.settings.smoothing, range: 0...0.9)
                SettingSlider(title: "Scroll sensitivity", value: $store.settings.scrollSensitivity, range: 0.2...3)
                SettingSlider(title: "Pinch threshold", value: $store.settings.pinchThreshold, range: 0.12...0.55)
                SettingSlider(title: "Confidence gate", value: $store.settings.confidenceThreshold, range: 0.3...0.95)
            }
            .padding(.vertical, 6)
        }
    }
}

private struct PermissionPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GroupBox("Permissions") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                PermissionRow(
                    title: "Accessibility",
                    granted: store.permissions.accessibilityTrusted,
                    actionTitle: "Open Settings",
                    action: store.openAccessibilitySettings
                )
                PermissionRow(
                    title: "Input Monitoring",
                    granted: store.permissions.inputMonitoringTrusted,
                    actionTitle: "Request",
                    action: store.requestInputMonitoring
                )
            }
            .padding(.vertical, 6)

            HStack {
                Button("Refresh Permissions") {
                    store.refreshPermissions(promptForAccessibility: true)
                }
                Button("Input Monitoring Settings") {
                    store.openInputMonitoringSettings()
                }
            }
        }
    }
}

private struct GestureLogView: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GroupBox("Recent Gestures") {
            if store.recentIntents.isEmpty {
                ContentUnavailableView("No gestures yet", systemImage: "hand.point.up.left", description: Text("Start tracking to stream v0 intent events from the camera helper."))
                    .frame(minHeight: 140)
            } else {
                Table(store.recentIntents) {
                    TableColumn("Gesture") { intent in
                        Text(intent.gesture.rawValue)
                    }
                    TableColumn("Tracking") { intent in
                        Text(intent.tracking.rawValue)
                    }
                    TableColumn("Click") { intent in
                        Text(intent.click.rawValue)
                    }
                    TableColumn("Confidence") { intent in
                        Text(intent.confidence.formatted(.number.precision(.fractionLength(2))))
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }
}

private struct PermissionRow: View {
    var title: String
    var granted: Bool
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        GridRow {
            Label(title, systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(granted ? "Granted" : "Needed")
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
        }
    }
}

private struct SettingSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12) {
            GridRow {
                Text(title)
                    .frame(width: 150, alignment: .leading)
                Slider(value: $value, in: range)
                    .frame(minWidth: 260)
                Text(value.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
    }
}

private struct StatusPill: View {
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
