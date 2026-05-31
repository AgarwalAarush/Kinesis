import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var store: KinesisStore
    var section: AppSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroStatusPanel()
                sectionContent
            }
            .padding(24)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .navigationTitle(section.title)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .overview:
            HStack(alignment: .top, spacing: 18) {
                ControlPanel()
                    .frame(maxWidth: 360)
                LiveIntentPanel()
            }
            GestureLogView()
        case .tuning:
            SettingsPanel()
        case .permissions:
            PermissionPanel()
                .frame(maxWidth: 520)
        case .diagnostics:
            LiveIntentPanel()
            GestureLogView()
        }
    }
}

private struct HeroStatusPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GlassPanel(prominence: store.emergencyPaused ? .warning : .primary) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        KinesisStatusBadge(text: phaseTitle, systemImage: phaseIcon, state: phaseState)
                        KinesisStatusBadge(text: store.helperStatus.title, systemImage: helperIcon, state: helperState)
                    }

                    Text("Air Mouse")
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    Text(store.latestDecision.reason)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: 560, alignment: .leading)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 10) {
                    ConfidenceRing(value: store.latestIntent.confidence)
                    Text("confidence gate \(store.settings.confidenceThreshold.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var phaseTitle: String {
        if store.emergencyPaused { return "Emergency pause" }
        if store.isArming { return "Arming" }
        if store.staleInput { return "Input stale" }
        if store.settings.dryRunEnabled { return "Dry Run" }
        return store.trackingEnabled ? "Tracking active" : "Standing by"
    }

    private var phaseIcon: String {
        if store.emergencyPaused { return "hand.raised.fill" }
        if store.isArming { return "timer" }
        if store.staleInput { return "camera.badge.ellipsis" }
        if store.settings.dryRunEnabled { return "eye.fill" }
        return store.trackingEnabled ? "cursorarrow.motionlines" : "pause.fill"
    }

    private var phaseState: KinesisStatusBadge.State {
        if store.emergencyPaused { return .warning }
        if store.isArming { return .active }
        if store.staleInput { return .warning }
        if store.settings.dryRunEnabled { return .active }
        return store.trackingEnabled ? .active : .paused
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

    private var helperState: KinesisStatusBadge.State {
        switch store.helperStatus {
        case .running:
            .ready
        case .starting:
            .active
        case .failed:
            .warning
        case .stopped:
            .paused
        }
    }
}

private struct ControlPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GlassPanel("Controls", systemImage: "slider.horizontal.3", prominence: store.emergencyPaused ? .warning : .standard) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    store.toggleTracking()
                } label: {
                    Label(store.trackingEnabled ? "Stop Tracking" : "Start Tracking", systemImage: store.trackingEnabled ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack(spacing: 10) {
                    Button {
                        store.emergencyPause()
                    } label: {
                        Label("Emergency Pause", systemImage: "hand.raised.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(store.emergencyPaused)

                    Button {
                        store.resetSession()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    SafetyLine(title: "Cmd + Esc", detail: "global emergency pause", systemImage: "keyboard")
                    SafetyLine(title: "2s arming", detail: "start shows gestures before live output", systemImage: "timer")
                    SafetyLine(title: "Stale input", detail: "camera silence releases all output", systemImage: "camera.badge.ellipsis")
                    SafetyLine(title: "Fist / open palm", detail: "clutch gesture releases drag", systemImage: "hand.raised")
                    SafetyLine(title: "Confidence gate", detail: "low confidence releases output", systemImage: "checkmark.shield")
                }
            }
        }
    }
}

private struct LiveIntentPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GlassPanel("Live Intent", systemImage: "waveform.path.ecg") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 14) {
                MetricRow(label: "Gesture", value: store.latestIntent.gesture.rawValue, systemImage: "hand.point.up.left")
                MetricRow(label: "Tracking", value: store.latestIntent.tracking.rawValue, systemImage: "dot.radiowaves.left.and.right")
                MetricRow(label: "Click", value: store.latestIntent.click.rawValue, systemImage: "cursorarrow.click")
                MetricRow(label: "Cursor delta", value: formattedVector(store.latestIntent.cursorDelta), systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                MetricRow(label: "Scroll delta", value: formattedVector(store.latestIntent.scrollDelta), systemImage: "scroll")
                MetricRow(label: "Hand", value: store.latestIntent.diagnostics.handedness.rawValue, systemImage: "hand.draw")
                MetricRow(label: "FPS", value: store.latestIntent.diagnostics.fps.formatted(.number.precision(.fractionLength(1))), systemImage: "speedometer")
            }
        }
    }

    private func formattedVector(_ vector: GestureVector) -> String {
        "\(vector.dx.formatted(.number.precision(.fractionLength(1)))), \(vector.dy.formatted(.number.precision(.fractionLength(1))))"
    }
}

private struct SettingsPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GlassPanel("Gesture Settings", systemImage: "dial.medium") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    FeatureToggle(title: "Dry Run", systemImage: "eye", isOn: $store.settings.dryRunEnabled)
                    FeatureToggle(title: "Cursor", systemImage: "cursorarrow.motionlines", isOn: $store.settings.cursorEnabled)
                    FeatureToggle(title: "Click / Drag", systemImage: "hand.tap", isOn: $store.settings.clickDragEnabled)
                    FeatureToggle(title: "Scroll", systemImage: "scroll", isOn: $store.settings.scrollEnabled)
                }

                Divider()

                SettingSlider(title: "Tracking speed", systemImage: "hare", value: $store.settings.trackingSpeed, range: 2...18)
                SettingSlider(title: "Smoothing", systemImage: "water.waves", value: $store.settings.smoothing, range: 0...0.9)
                SettingSlider(title: "Scroll sensitivity", systemImage: "arrow.up.and.down", value: $store.settings.scrollSensitivity, range: 0.2...3)
                SettingSlider(title: "Pinch threshold", systemImage: "hand.pinch", value: $store.settings.pinchThreshold, range: 0.12...0.55)
                SettingSlider(title: "Confidence gate", systemImage: "checkmark.seal", value: $store.settings.confidenceThreshold, range: 0.3...0.95)
                SettingSlider(title: "Cursor dead zone", systemImage: "smallcircle.filled.circle", value: $store.settings.cursorDeadZone, range: 0...1)
                SettingSlider(title: "Scroll dead zone", systemImage: "smallcircle.filled.circle.fill", value: $store.settings.scrollDeadZone, range: 0...2)
            }
        }
    }
}

private struct PermissionPanel: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GlassPanel("Permissions", systemImage: "lock.shield") {
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Required for cursor, click, and scroll output.",
                    granted: store.permissions.accessibilityTrusted,
                    actionTitle: "Open Settings",
                    action: store.openAccessibilitySettings
                )
                PermissionRow(
                    title: "Input Monitoring",
                    detail: "Required for the global Cmd + Esc safety shortcut.",
                    granted: store.permissions.inputMonitoringTrusted,
                    actionTitle: "Request",
                    action: store.requestInputMonitoring
                )

                Divider()

                HStack {
                    Button {
                        store.refreshPermissions(promptForAccessibility: true)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Button {
                        store.openInputMonitoringSettings()
                    } label: {
                        Label("Input Settings", systemImage: "gearshape")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct GestureLogView: View {
    @EnvironmentObject private var store: KinesisStore

    var body: some View {
        GlassPanel("Recent Gestures", systemImage: "list.bullet.rectangle") {
            if store.recentIntents.isEmpty {
                ContentUnavailableView(
                    "No gestures yet",
                    systemImage: "hand.point.up.left",
                    description: Text("Start tracking to stream v0 intent events from the camera helper.")
                )
                .frame(minHeight: 150)
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
                            .monospacedDigit()
                    }
                    TableColumn("FPS") { intent in
                        Text(intent.diagnostics.fps.formatted(.number.precision(.fractionLength(1))))
                            .monospacedDigit()
                    }
                }
                .frame(minHeight: 220)
            }
        }
    }
}

private struct ConfidenceRing: View {
    var value: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.16), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(value >= 0.62 ? .blue : .orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(value.formatted(.percent.precision(.fractionLength(0))))
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .frame(width: 92, height: 92)
        .accessibilityLabel("Gesture confidence")
        .accessibilityValue(value.formatted(.percent.precision(.fractionLength(0))))
    }
}

private struct SafetyLine: View {
    var title: String
    var detail: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MetricRow: View {
    var label: String
    var value: String
    var systemImage: String

    var body: some View {
        GridRow {
            Label(label, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
                .lineLimit(1)
        }
    }
}

private struct FeatureToggle: View {
    var title: String
    var systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
    }
}

private struct PermissionRow: View {
    var title: String
    var detail: String
    var granted: Bool
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(granted ? .green : .orange)
                    .fontWeight(.medium)
                Spacer()
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: KinesisDesign.controlRadius, style: .continuous))
    }
}

private struct SettingSlider: View {
    var title: String
    var systemImage: String
    @Binding var value: Double
    var range: ClosedRange<Double>

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12) {
            GridRow {
                Label(title, systemImage: systemImage)
                    .frame(width: 160, alignment: .leading)
                    .foregroundStyle(.primary)
                Slider(value: $value, in: range)
                    .frame(minWidth: 250)
                Text(value.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 54, alignment: .trailing)
            }
        }
    }
}
