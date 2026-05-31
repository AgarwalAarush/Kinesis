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

    private let helper = CVHelperProcess()
    private let router = GestureRouter()
    private let bridge: MacControlProviding
    private let hotKeys = HotKeyService()
    private var didActivate = false

    init(bridge: MacControlProviding = MacControlBridge()) {
        self.bridge = bridge
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
        if trackingEnabled { return "cursorarrow.motionlines" }
        return "hand.point.up.left"
    }

    func activate() {
        guard !didActivate else { return }
        didActivate = true
        refreshPermissions()
        hotKeys.start { [weak self] in
            self?.emergencyPause()
        }
    }

    func toggleTracking() {
        trackingEnabled ? stopTracking() : startTracking()
    }

    func startTracking() {
        emergencyPaused = false
        trackingEnabled = true
        refreshPermissions()
        helper.start(settings: settings)
    }

    func stopTracking() {
        trackingEnabled = false
        bridge.releaseAll()
        helper.stop()
    }

    func toggleEmergencyPause() {
        emergencyPaused ? resumeInput() : emergencyPause()
    }

    func emergencyPause() {
        emergencyPaused = true
        trackingEnabled = false
        bridge.releaseAll()
        latestDecision = RouteDecision(action: .released, reason: "Emergency pause triggered.")
    }

    func resumeInput() {
        emergencyPaused = false
        latestDecision = RouteDecision(action: .ignored, reason: "Input resumed. Start tracking to control the cursor.")
    }

    func resetSession() {
        recentIntents.removeAll()
        latestIntent = .idle
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
        latestIntent = intent
        recentIntents.insert(intent, at: 0)
        if recentIntents.count > 40 {
            recentIntents.removeLast(recentIntents.count - 40)
        }
        latestDecision = router.route(
            intent: intent,
            settings: settings,
            trackingEnabled: trackingEnabled,
            emergencyPaused: emergencyPaused,
            output: bridge
        )
    }
}
