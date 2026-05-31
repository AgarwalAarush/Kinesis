import AppKit
import Combine
import Foundation

@MainActor
final class KinesisStore: ObservableObject {
    @Published var settings = ControlSettings.defaults
    @Published var trackingEnabled = false
    @Published var emergencyPaused = false
    @Published var helperStatus: HelperStatus = .stopped
    @Published var permissions: PermissionSnapshot = .unknown
    @Published var latestIntent = GestureIntent.idle
    @Published var latestDecision = RouteDecision(action: .ignored, reason: "Waiting for gestures.")
    @Published var recentIntents: [GestureIntent] = []
    @Published var staleInput = false
    @Published var controlArmedAt: Date?

    private let helper = CVHelperProcess()
    private let router = GestureRouter()
    private let bridge: MacControlProviding
    private let hotKeys = HotKeyService()
    private var didActivate = false
    private var staleTimer: Timer?
    private var lastIntentReceivedAt: Date?
    private let armingDuration: TimeInterval = 2.0
    private let staleInputTimeout: TimeInterval = 0.75

    init(bridge: MacControlProviding? = nil) {
        self.bridge = bridge ?? MacControlBridge()
        helper.onIntent = { [weak self] intent in
            self?.handle(intent)
        }
        helper.onStatusChange = { [weak self] status in
            self?.helperStatus = status
            if status != .running {
                self?.bridge.releaseAll()
            }
        }
    }

    var menuBarSystemImage: String {
        if emergencyPaused { return "hand.raised.fill" }
        if isArming { return "timer" }
        if settings.dryRunEnabled { return "eye.fill" }
        if trackingEnabled { return "cursorarrow.motionlines" }
        return "hand.point.up.left"
    }

    var isArming: Bool {
        guard let controlArmedAt else { return false }
        return Date() < controlArmedAt
    }

    var isMouseDown: Bool {
        bridge.isMouseDown
    }

    func activate() {
        guard !didActivate else { return }
        didActivate = true
        refreshPermissions()
        startStaleInputWatchdog()
        hotKeys.start { [weak self] in
            self?.emergencyPause()
        }
    }

    func toggleTracking() {
        trackingEnabled ? stopTracking() : startTracking()
    }

    func startTracking() {
        refreshPermissions()
        guard settings.dryRunEnabled || liveControlPermissionsReady else {
            trackingEnabled = false
            emergencyPaused = false
            bridge.releaseAll()
            latestDecision = RouteDecision(action: .ignored, reason: "Live control needs Accessibility and Input Monitoring permissions. Turn on Dry Run to rehearse without output.")
            return
        }

        emergencyPaused = false
        trackingEnabled = true
        staleInput = false
        lastIntentReceivedAt = Date()
        controlArmedAt = Date().addingTimeInterval(armingDuration)
        helper.start(settings: settings)
    }

    func stopTracking() {
        trackingEnabled = false
        controlArmedAt = nil
        staleInput = false
        bridge.releaseAll()
        helper.stop()
    }

    func toggleEmergencyPause() {
        emergencyPaused ? resumeInput() : emergencyPause()
    }

    func emergencyPause() {
        emergencyPaused = true
        trackingEnabled = false
        controlArmedAt = nil
        bridge.releaseAll()
        if helper.isRunning {
            helper.stop()
        }
        latestDecision = RouteDecision(action: .released, reason: "Emergency pause triggered.")
    }

    func resumeInput() {
        emergencyPaused = false
        latestDecision = RouteDecision(action: .ignored, reason: "Input resumed. Start tracking to control the cursor.")
    }

    func resetSession() {
        recentIntents.removeAll()
        latestIntent = .idle
        staleInput = false
        controlArmedAt = nil
        latestDecision = RouteDecision(action: .ignored, reason: "Session reset.")
        bridge.releaseAll()
    }

    func refreshPermissions(promptForAccessibility: Bool = false) {
        permissions = PermissionService.snapshot(promptForAccessibility: promptForAccessibility)
    }

    func requestInputMonitoring() {
        PermissionService.requestInputMonitoring()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        PermissionService.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        PermissionService.openInputMonitoringSettings()
    }

    private func handle(_ intent: GestureIntent) {
        lastIntentReceivedAt = Date()
        staleInput = false
        latestIntent = intent
        recentIntents.insert(intent, at: 0)
        if recentIntents.count > 40 {
            recentIntents.removeLast(recentIntents.count - 40)
        }
        if isArming {
            bridge.releaseAll()
            let seconds = max(0, Int(ceil((controlArmedAt?.timeIntervalSinceNow ?? 0))))
            latestDecision = RouteDecision(action: .released, reason: "Arming input for \(seconds)s. Gestures are visible but not controlling the Mac.")
            return
        }
        controlArmedAt = nil

        guard settings.dryRunEnabled || liveControlPermissionsReady else {
            bridge.releaseAll()
            latestDecision = RouteDecision(action: .released, reason: "Live control blocked until Accessibility and Input Monitoring permissions are granted.")
            return
        }

        latestDecision = router.route(
            intent: intent,
            settings: settings,
            trackingEnabled: trackingEnabled,
            emergencyPaused: emergencyPaused,
            output: bridge
        )
    }

    private func startStaleInputWatchdog() {
        staleTimer?.invalidate()
        staleTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForStaleInput()
            }
        }
    }

    private func checkForStaleInput() {
        guard trackingEnabled, !emergencyPaused, helperStatus == .running else { return }
        guard let lastIntentReceivedAt else { return }
        guard Date().timeIntervalSince(lastIntentReceivedAt) > staleInputTimeout else { return }

        bridge.releaseAll()
        staleInput = true
        controlArmedAt = nil
        latestIntent = GestureIntent(
            timestamp: Date().timeIntervalSince1970,
            tracking: .lost,
            gesture: .none,
            confidence: 0,
            cursorDelta: .zero,
            scrollDelta: .zero,
            click: .none,
            diagnostics: latestIntent.diagnostics
        )
        latestDecision = RouteDecision(action: .released, reason: "Input paused because the camera helper stopped sending fresh hand data.")
    }

    private var liveControlPermissionsReady: Bool {
        permissions.accessibilityTrusted && permissions.inputMonitoringTrusted
    }
}
